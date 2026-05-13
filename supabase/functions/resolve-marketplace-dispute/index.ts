/**
 * RESOLVE MARKETPLACE DISPUTE (admin-only)
 * ========================================
 * Tre möjliga beslut:
 *   - 'refund_buyer'     → full refund till köparen, status='refunded',
 *                          listingen återpubliceras.
 *   - 'release_seller'   → ingen refund, transfer till säljaren,
 *                          status='released'.
 *   - 'partial_refund'   → refund av `refundOreOptional` öre till köparen,
 *                          transfer av (charge - refund) till säljaren,
 *                          status='released'.
 *
 * Authorisation:
 *   - Bearer JWT i Authorization-header.
 *   - Caller måste finnas i `ADMIN_USER_IDS` (kommaseparerad UUID-lista
 *     i secrets) ELLER passera `is_admin()` JWT-claim. Vi check:ar
 *     ADMIN_USER_IDS först eftersom det är den explicita listan.
 *
 * Body:
 *   {
 *     orderId: string,
 *     decision: 'refund_buyer' | 'release_seller' | 'partial_refund',
 *     refundOre?: number,   // krävs om decision='partial_refund'
 *     note?: string         // fri text, synlig för köpare/säljare
 *   }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@14.21.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type Decision = 'refund_buyer' | 'release_seller' | 'partial_refund';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
      apiVersion: '2023-10-16',
    });

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing Authorization header');

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: { user }, error: userErr } = await supabaseClient.auth.getUser();
    if (userErr || !user) throw new Error('Unauthorized');

    const adminIds = (Deno.env.get('ADMIN_USER_IDS') ?? '')
      .split(',').map((s) => s.trim()).filter(Boolean);
    if (!adminIds.includes(user.id)) {
      // Sekundär check via JWT-baserad is_admin()-RPC ifall sekreten
      // skulle vara out-of-sync.
      const { data: ok } = await supabaseClient.rpc('is_admin');
      if (ok !== true) throw new Error('Admin access required');
    }

    const { orderId, decision, refundOre, note } = await req.json() as {
      orderId?: string;
      decision?: Decision;
      refundOre?: number;
      note?: string;
    };

    if (!orderId) throw new Error('orderId is required');
    if (!decision) throw new Error('decision is required');
    if (!['refund_buyer', 'release_seller', 'partial_refund'].includes(decision)) {
      throw new Error(`Invalid decision: ${decision}`);
    }
    if (decision === 'partial_refund') {
      if (!Number.isFinite(refundOre) || (refundOre as number) <= 0) {
        throw new Error('partial_refund kräver refundOre > 0');
      }
    }

    const { data: order, error: orderErr } = await supabaseAdmin
      .from('marketplace_orders')
      .select(`
        id, listing_id, buyer_id, seller_id, status, is_held,
        amount_buyer_total, amount_seller_payout, currency,
        stripe_charge_id, stripe_payment_intent_id, stripe_transfer_id,
        dispute_opened_at, dispute_resolved_at
      `)
      .eq('id', orderId)
      .single();
    if (orderErr || !order) throw new Error('Order not found');
    if (order.status !== 'disputed') {
      throw new Error(`Order is not disputed (status: ${order.status})`);
    }
    if (order.dispute_resolved_at) {
      throw new Error('Dispute redan avgjord');
    }
    if (!order.stripe_charge_id) {
      throw new Error('Saknar stripe_charge_id — kan inte refunda/transfer:a');
    }

    const adminNote = (note ?? '').toString().slice(0, 1000);
    const nowIso = new Date().toISOString();

    if (decision === 'refund_buyer') {
      await stripe.refunds.create({
        charge: order.stripe_charge_id,
        amount: order.amount_buyer_total,
        reason: 'requested_by_customer',
        metadata: {
          source: 'marketplace',
          order_id: order.id,
          trigger: 'admin_dispute_refund_buyer',
          admin_id: user.id,
        },
      });

      await supabaseAdmin
        .from('marketplace_orders')
        .update({
          status: 'refunded',
          is_held: false,
          dispute_resolved_at: nowIso,
          dispute_resolution: 'refund_buyer',
          dispute_resolved_by: user.id,
          dispute_admin_note: adminNote,
          dispute_refund_amount_ore: order.amount_buyer_total,
        })
        .eq('id', order.id);

      // Listingen återpubliceras inte — köparen fick varan eller
      // varan är förlorad enligt köparen. Säljaren kan skapa ny annons.

      await supabaseAdmin.from('notifications').insert([
        {
          user_id: order.buyer_id,
          type: 'marketplace_dispute_refunded',
          actor_id: order.seller_id,
          message:
            'Vi har avgjort tvisten till din fördel. Hela beloppet återbetalas inom 5 bankdagar.',
        },
        {
          user_id: order.seller_id,
          type: 'marketplace_dispute_refunded',
          actor_id: order.buyer_id,
          message:
            'Tvisten är avgjord till köparens fördel — beloppet har återbetalats. Kontakta supporten om du har frågor.',
        },
      ]).catch(() => {});

      return ok({ orderId: order.id, decision, refundOre: order.amount_buyer_total });
    }

    if (decision === 'release_seller') {
      const seller = await getSellerForTransfer(supabaseAdmin, order.seller_id);
      const transfer = await stripe.transfers.create({
        amount: order.amount_seller_payout,
        currency: order.currency || 'sek',
        destination: seller.stripe_account_id,
        source_transaction: order.stripe_charge_id,
        metadata: {
          source: 'marketplace',
          order_id: order.id,
          trigger: 'admin_dispute_release_seller',
          admin_id: user.id,
        },
      });

      await supabaseAdmin
        .from('marketplace_orders')
        .update({
          stripe_transfer_id: transfer.id,
          status: 'released',
          is_held: false,
          released_at: nowIso,
          buyer_approved_at: order.dispute_opened_at, // markera fönstret som passerat
          dispute_resolved_at: nowIso,
          dispute_resolution: 'release_seller',
          dispute_resolved_by: user.id,
          dispute_admin_note: adminNote,
          dispute_refund_amount_ore: 0,
        })
        .eq('id', order.id);

      await supabaseAdmin.from('notifications').insert([
        {
          user_id: order.seller_id,
          type: 'marketplace_dispute_released',
          actor_id: order.buyer_id,
          message:
            'Tvisten är avgjord till din fördel — pengarna har skickats till ditt Stripe-konto.',
        },
        {
          user_id: order.buyer_id,
          type: 'marketplace_dispute_released',
          actor_id: order.seller_id,
          message:
            'Vi har avgjort tvisten till säljarens fördel. Kontakta supporten om du har frågor.',
        },
      ]).catch(() => {});

      return ok({ orderId: order.id, decision, transferId: transfer.id });
    }

    // partial_refund
    const partialRefundOre = Math.min(
      Math.floor(refundOre as number),
      order.amount_buyer_total
    );
    const remainingForSellerOre = Math.max(
      0,
      order.amount_seller_payout - partialRefundOre
    );

    await stripe.refunds.create({
      charge: order.stripe_charge_id,
      amount: partialRefundOre,
      reason: 'requested_by_customer',
      metadata: {
        source: 'marketplace',
        order_id: order.id,
        trigger: 'admin_dispute_partial_refund',
        admin_id: user.id,
      },
    });

    let transferId: string | null = null;
    if (remainingForSellerOre > 0) {
      const seller = await getSellerForTransfer(supabaseAdmin, order.seller_id);
      const transfer = await stripe.transfers.create({
        amount: remainingForSellerOre,
        currency: order.currency || 'sek',
        destination: seller.stripe_account_id,
        source_transaction: order.stripe_charge_id,
        metadata: {
          source: 'marketplace',
          order_id: order.id,
          trigger: 'admin_dispute_partial_refund',
          admin_id: user.id,
        },
      });
      transferId = transfer.id;
    }

    await supabaseAdmin
      .from('marketplace_orders')
      .update({
        stripe_transfer_id: transferId,
        status: 'released',
        is_held: false,
        released_at: nowIso,
        buyer_approved_at: order.dispute_opened_at,
        dispute_resolved_at: nowIso,
        dispute_resolution: 'partial_refund',
        dispute_resolved_by: user.id,
        dispute_admin_note: adminNote,
        dispute_refund_amount_ore: partialRefundOre,
      })
      .eq('id', order.id);

    await supabaseAdmin.from('notifications').insert([
      {
        user_id: order.buyer_id,
        type: 'marketplace_dispute_partial_refunded',
        actor_id: order.seller_id,
        message:
          `Tvisten är avgjord — ${oreToSEK(partialRefundOre)} kr återbetalas till dig.`,
      },
      {
        user_id: order.seller_id,
        type: 'marketplace_dispute_partial_refunded',
        actor_id: order.buyer_id,
        message:
          remainingForSellerOre > 0
            ? `Tvisten är avgjord — ${oreToSEK(remainingForSellerOre)} kr har skickats till ditt Stripe-konto.`
            : 'Tvisten är avgjord — hela försäljningsbeloppet har återbetalats till köparen.',
      },
    ]).catch(() => {});

    return ok({
      orderId: order.id,
      decision,
      refundOre: partialRefundOre,
      transferId,
    });
  } catch (error) {
    console.error('resolve-marketplace-dispute error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function getSellerForTransfer(
  supabaseAdmin: ReturnType<typeof createClient>,
  sellerId: string
): Promise<{ stripe_account_id: string }> {
  const { data: seller } = await supabaseAdmin
    .from('profiles')
    .select('stripe_account_id, stripe_charges_enabled')
    .eq('id', sellerId)
    .single();
  if (!seller?.stripe_account_id || !seller.stripe_charges_enabled) {
    throw new Error('Säljaren saknar Stripe Connect — kan inte transfer:a. Använd refund_buyer eller vänta tills säljaren onboardats.');
  }
  return { stripe_account_id: seller.stripe_account_id as string };
}

function oreToSEK(ore: number): string {
  return (ore / 100).toFixed(2).replace('.00', '');
}

function ok(payload: Record<string, unknown>): Response {
  return new Response(
    JSON.stringify({ success: true, ...payload }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

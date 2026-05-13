/**
 * APPROVE MARKETPLACE ORDER
 * =========================
 * Buyer-triggered "Godkänn varan" — släpper de hållna pengarna till
 * säljaren via en Stripe Connect transfer.
 *
 * Flöde:
 *   1. Verifiera att anroparen är ordens köpare.
 *   2. Krav: order.status = 'succeeded', is_held = true, ingen tvist
 *      öppen.
 *   3. Säljaren måste ha onboardad Stripe-konto (charges_enabled).
 *      - Om INTE: markera ordern som approved av köparen men låt
 *        `is_held` stå kvar; transfern triggas senare av
 *        `process-pending-seller-payouts` när säljaren onboardats.
 *   4. Skapa stripe.transfers.create från source_transaction =
 *      stripe_charge_id, destination = seller.stripe_account_id.
 *   5. Sätt buyer_approved_at, status='released', released_at, transfer_id.
 *   6. Notifiera båda parter.
 *
 * Usage:
 * POST /approve-marketplace-order
 * Body: { orderId: string }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@14.21.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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

    const { orderId } = await req.json();
    if (!orderId) throw new Error('orderId is required');

    const { data: order, error: orderErr } = await supabaseAdmin
      .from('marketplace_orders')
      .select('*')
      .eq('id', orderId)
      .single();
    if (orderErr || !order) throw new Error('Order not found');

    if (order.buyer_id !== user.id) {
      throw new Error('Only the buyer can approve this order');
    }
    if (order.status === 'released') {
      return ok({ success: true, alreadyReleased: true, orderId });
    }
    if (order.status !== 'succeeded') {
      throw new Error(`Order is not in a releaseable state (status=${order.status})`);
    }
    if (order.dispute_opened_at) {
      throw new Error('Order has an open dispute — cannot release');
    }

    const nowIso = new Date().toISOString();

    // Markera approval på ordern oavsett om vi lyckas transfer:a — om
    // säljaren inte har Stripe ännu sköts payouten av
    // `process-pending-seller-payouts` vid onboarding.
    await supabaseAdmin
      .from('marketplace_orders')
      .update({ buyer_approved_at: nowIso })
      .eq('id', orderId);

    const { data: seller } = await supabaseAdmin
      .from('profiles')
      .select('id, stripe_account_id, stripe_charges_enabled')
      .eq('id', order.seller_id)
      .single();

    const sellerReady = Boolean(
      seller?.stripe_account_id && seller?.stripe_charges_enabled
    );

    if (!sellerReady) {
      // Säljaren saknar Stripe — vi har redan markerat approved.
      // Pengar släpps automatiskt vid onboarding.
      await supabaseAdmin.from('notifications').insert([
        {
          user_id: order.seller_id,
          type: 'marketplace_approved_pending_payout',
          actor_id: order.buyer_id,
          message:
            'Köparen godkände varan! Slutför Stripe-onboardingen för att få utbetalningen.',
        },
        {
          user_id: order.buyer_id,
          type: 'marketplace_buyer_approved',
          message: 'Tack för att du godkände varan! Säljaren får sina pengar inom kort.',
        },
      ]).catch(() => {});

      return ok({ success: true, orderId, releasePending: true });
    }

    if (!order.stripe_charge_id) {
      throw new Error('Order has no Stripe charge id — cannot transfer');
    }

    // Skapa transfern (platform -> seller's Connect account). Vid fel
    // markerar vi `payout_failed_at` så `process-pending-seller-payouts`
    // kan retrya och admin ser den i payout-failures-listan.
    let transferId: string;
    try {
      const transfer = await stripe.transfers.create({
        amount: order.amount_seller_payout,
        currency: order.currency || 'sek',
        destination: seller!.stripe_account_id,
        source_transaction: order.stripe_charge_id,
        metadata: {
          source: 'marketplace',
          order_id: orderId,
          seller_id: order.seller_id,
          trigger: 'buyer_approval',
        },
      });
      transferId = transfer.id;
    } catch (transferErr) {
      const reason = (transferErr as Error).message ?? 'unknown';
      console.error(`Transfer failed for order ${orderId}:`, reason);
      await supabaseAdmin
        .from('marketplace_orders')
        .update({
          payout_failed_at: nowIso,
          payout_failure_reason: reason.slice(0, 500),
        })
        .eq('id', orderId);
      await notifyPayoutFailure(supabaseAdmin, {
        orderId,
        sellerId: order.seller_id,
        buyerId: order.buyer_id,
        reason,
      });
      // Köparens approval är registrerad; admin tittar manuellt.
      return ok({ success: true, orderId, releasePending: true });
    }

    await supabaseAdmin
      .from('marketplace_orders')
      .update({
        stripe_transfer_id: transferId,
        is_held: false,
        status: 'released',
        released_at: nowIso,
        payout_failed_at: null,
        payout_failure_reason: null,
      })
      .eq('id', orderId);

    await supabaseAdmin.from('notifications').insert([
      {
        user_id: order.seller_id,
        type: 'marketplace_payout_released',
        actor_id: order.buyer_id,
        message: 'Köparen godkände varan — pengarna har skickats till ditt Stripe-konto.',
      },
      {
        user_id: order.buyer_id,
        type: 'marketplace_buyer_approved',
        message: 'Tack! Säljaren har fått sina pengar.',
      },
    ]).catch(() => {});

    return ok({
      success: true,
      orderId,
      transferId,
      released: true,
    });
  } catch (error) {
    console.error('approve-marketplace-order error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

function ok(payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function notifyPayoutFailure(
  supabaseAdmin: ReturnType<typeof createClient>,
  args: { orderId: string; sellerId: string; buyerId: string; reason: string }
): Promise<void> {
  const adminIds = (Deno.env.get('ADMIN_USER_IDS') ?? '')
    .split(',').map((s) => s.trim()).filter(Boolean);
  const rows: Array<Record<string, unknown>> = adminIds.map((adminId) => ({
    user_id: adminId,
    type: 'marketplace_payout_failed_admin',
    actor_id: args.sellerId,
    message: `Stripe-transfer misslyckades på order ${args.orderId.slice(0,8)}: ${args.reason.slice(0,140)}`,
  }));
  rows.push({
    user_id: args.sellerId,
    type: 'marketplace_approved_pending_payout',
    actor_id: args.buyerId,
    message:
      'Köparen godkände varan, men Stripe-utbetalningen misslyckades. Vi försöker igen automatiskt — kontrollera ditt Stripe-konto.',
  });
  await supabaseAdmin.from('notifications').insert(rows).catch(() => {});
}

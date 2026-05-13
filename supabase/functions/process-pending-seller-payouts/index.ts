/**
 * PROCESS PENDING SELLER PAYOUTS
 * ==============================
 * När en säljare slutför Stripe Connect-onboarding (eller en transfer
 * tidigare failade) kan det finnas marketplace-ordrar där köparen
 * redan godkänt men pengarna inte rullats ut.
 *
 * Vi flyttar BARA ordrar där:
 *   - status = 'succeeded'
 *   - is_held = true
 *   - buyer_approved_at IS NOT NULL  (köparen har godkänt — eller
 *     auto-release har stämplat det)
 *   - stripe_transfer_id IS NULL
 *   - payout_failed_at IS NULL  *eller*  payout_failed_at < now() - 1h
 *     (exponential backoff för failade transfers)
 *
 * Ordrar i status 'pending', 'disputed' eller 'cancelled' rörs ALDRIG
 * här. Buyer-protection-flödet är källan till sanningen för release.
 *
 * Två modes:
 *   - Per säljare: POST { sellerId: string }
 *     Anropas från `account.updated`-webhooken vid lyckad onboarding.
 *   - Cron-retry: POST {}  (eller utan body)
 *     Anropas via `marketplace-payout-retry-tick` varje timme och
 *     hämtar alla unika sellers med `payout_failed_at IS NOT NULL`.
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

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    let body: { sellerId?: string } = {};
    try { body = await req.json(); } catch (_) { /* tom body OK */ }
    const explicitSellerId = body.sellerId;

    // Lista över sellers att processa.
    let sellerIds: string[] = [];
    if (explicitSellerId) {
      sellerIds = [explicitSellerId];
    } else {
      // Cron-mode: alla sellers med fastnade payouts.
      const { data: stuck } = await supabaseAdmin
        .from('marketplace_orders')
        .select('seller_id')
        .not('payout_failed_at', 'is', null)
        .is('released_at', null)
        .limit(500);
      sellerIds = Array.from(new Set((stuck ?? []).map((r: any) => r.seller_id)));
    }

    if (sellerIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, processed: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const results: Array<{ orderId: string; transferId?: string; error?: string; skipped?: string }> = [];
    const oneHourAgoIso = new Date(Date.now() - 60 * 60 * 1000).toISOString();

    for (const sellerId of sellerIds) {
      const { data: seller } = await supabaseAdmin
        .from('profiles')
        .select('id, stripe_account_id, stripe_charges_enabled, stripe_payouts_enabled')
        .eq('id', sellerId)
        .single();

      if (!seller?.stripe_account_id || !seller.stripe_charges_enabled) {
        if (explicitSellerId) {
          throw new Error('Seller onboarding is not complete');
        }
        // I cron-mode hoppar vi tyst förbi sellers utan Connect.
        continue;
      }

      const { data: orders } = await supabaseAdmin
        .from('marketplace_orders')
        .select('id, stripe_charge_id, amount_seller_payout, currency, buyer_id, payout_failed_at')
        .eq('seller_id', sellerId)
        .eq('is_held', true)
        .eq('status', 'succeeded')
        .not('buyer_approved_at', 'is', null)
        .is('stripe_transfer_id', null);

      if (!orders || orders.length === 0) continue;

      for (const order of orders) {
        if (!order.stripe_charge_id) {
          results.push({ orderId: order.id, error: 'Missing stripe_charge_id' });
          continue;
        }
        // Backoff: hoppa över ordrar som failade nyligen (< 1 h sedan).
        if (order.payout_failed_at && order.payout_failed_at > oneHourAgoIso) {
          results.push({ orderId: order.id, skipped: 'recent_failure_backoff' });
          continue;
        }

        try {
          const transfer = await stripe.transfers.create({
            amount: order.amount_seller_payout,
            currency: order.currency || 'sek',
            destination: seller.stripe_account_id,
            source_transaction: order.stripe_charge_id,
            metadata: {
              source: 'marketplace',
              order_id: order.id,
              seller_id: sellerId,
            },
          });

          await supabaseAdmin
            .from('marketplace_orders')
            .update({
              stripe_transfer_id: transfer.id,
              is_held: false,
              released_at: new Date().toISOString(),
              status: 'released',
              payout_failed_at: null,
              payout_failure_reason: null,
            })
            .eq('id', order.id);

          try {
            await supabaseAdmin.from('notifications').insert({
              user_id: sellerId,
              type: 'marketplace_payout_released',
              actor_id: order.buyer_id,
              message: 'Pengarna är nu på väg till ditt Stripe-konto.',
            });
          } catch (e) {
            console.warn('Failed to insert payout-released notification:', (e as Error).message);
          }

          results.push({ orderId: order.id, transferId: transfer.id });
        } catch (err) {
          const reason = (err as Error).message ?? 'unknown';
          console.error(`Failed to transfer for order ${order.id}:`, reason);
          await supabaseAdmin
            .from('marketplace_orders')
            .update({
              payout_failed_at: new Date().toISOString(),
              payout_failure_reason: reason.slice(0, 500),
            })
            .eq('id', order.id);
          results.push({ orderId: order.id, error: reason });
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        processed: results.filter(r => r.transferId).length,
        failed: results.filter(r => r.error).length,
        skipped: results.filter(r => r.skipped).length,
        results,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('process-pending-seller-payouts error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});

/**
 * PROCESS MARKETPLACE DEADLINES
 * =============================
 * Cron-driven (varje timme) hanterare som rensar ut tre typer av
 * deadlines:
 *
 *   1. Ship-by-påminnelse (24 h kvar): säljaren har inte lämnat in
 *      ännu och `ship_by_deadline - NOW() < 24 h`. Vi skickar EN notis
 *      till säljaren och stämplar `ship_by_reminded_at` så den inte
 *      upprepas.
 *
 *   2. Ship-by-deadline expiry: säljaren har inte lämnat in paketet
 *      inom utlovad tid. Vi cancellerar PaymentIntent eller refundar
 *      charge, sätter status='cancelled' och återpublicerar annonsen.
 *
 *   3. Buyer-approval-deadline expiry: 48 h har gått sedan delivered
 *      utan godkännande eller tvist. Vi släpper pengarna via
 *      `stripe.transfers.create` och meddelar både köpare och säljare.
 *
 * Auth: kräver service-role bearer i Authorization-header (samma
 * mönster som `poll-shipmondo-tracking`).
 *
 * Usage:
 * POST /process-marketplace-deadlines
 * Body: { limit?: number }   // default 200
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
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const provided = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');

    let body: Record<string, unknown> = {};
    try {
      body = await req.json();
    } catch {
      // empty body ok
    }
    let limit = 200;
    const requested = Number(body?.limit);
    if (Number.isFinite(requested) && requested > 0) {
      limit = Math.min(500, Math.round(requested));
    }
    const bypassIsTest = body?.bypass_is_test === true;
    const allowBypass = (Deno.env.get('ALLOW_TEST_DEADLINES_BYPASS') ?? '').toLowerCase() === 'true';
    let includeTestOrders = false;

    if (!serviceRoleKey) {
      return new Response(
        JSON.stringify({ success: false, error: 'Missing service role key config' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (provided === serviceRoleKey) {
      includeTestOrders = bypassIsTest && allowBypass;
    } else if (bypassIsTest && allowBypass) {
      const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } }
      );
      const { data: authData, error: authErr } = await supabaseClient.auth.getUser();
      if (authErr || !authData?.user) {
        return new Response(
          JSON.stringify({ success: false, error: 'Unauthorized' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      const adminEmails: Set<string> = new Set([
        'admin@updown.app',
        'wiggohelgesson@gmail.com',
        'info@wiggio.se',
        'info@bylito.se',
      ]);
      const adminIds: Set<string> = new Set(
        (Deno.env.get('ADMIN_USER_IDS') ?? '')
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean)
      );
      const email = (authData.user.email ?? '').toLowerCase();
      const isAdmin = adminEmails.has(email) || adminIds.has(authData.user.id);
      if (!isAdmin) {
        return new Response(
          JSON.stringify({ success: false, error: 'Admin only' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      includeTestOrders = true;
    } else {
      return new Response(
        JSON.stringify({ success: false, error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
      apiVersion: '2023-10-16',
    });
    const supabaseAdmin = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceRoleKey);
    const nowIso = new Date().toISOString();

    let autoCancelled = 0;
    let autoReleased = 0;
    let shipReminders = 0;
    let shipReminders48h = 0;
    let errors = 0;

    // ----------------------------------------------------------------
    // -1. Ship-by-påminnelse: mellan 24 och 48 h kvar till deadline.
    //     Idempotent via `ship_by_reminder_48h_at`.
    // ----------------------------------------------------------------
    const lowerBoundIso = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    const upperBoundIso = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString();
    let midWindowQuery = supabaseAdmin
      .from('marketplace_orders')
      .select('id, seller_id, listing_id, ship_by_deadline')
      .eq('status', 'succeeded')
      .is('shipped_at', null)
      .is('auto_cancelled_at', null)
      .is('ship_by_reminder_48h_at', null)
      .not('ship_by_deadline', 'is', null)
      .gt('ship_by_deadline', lowerBoundIso)
      .lte('ship_by_deadline', upperBoundIso)
      .limit(limit);
    if (!includeTestOrders) {
      midWindowQuery = midWindowQuery.eq('is_test', false);
    }
    const { data: midWindowOrders } = await midWindowQuery;

    for (const order of midWindowOrders ?? []) {
      try {
        await supabaseAdmin
          .from('marketplace_orders')
          .update({ ship_by_reminder_48h_at: nowIso })
          .eq('id', order.id);

        const n48: Record<string, unknown> = {
          user_id: order.seller_id,
          type: 'marketplace_ship_reminder',
          message:
            '2 dagar kvar att lämna in paketet — annars avbokas köpet automatiskt.',
        };
        if (order.listing_id) n48.related_id = order.listing_id;
        await supabaseAdmin.from('notifications').insert(n48);

        shipReminders48h++;
      } catch (e) {
        errors++;
        console.warn(`48h ship reminder failed for order ${order.id}:`, (e as Error).message);
      }
    }

    // ----------------------------------------------------------------
    // 0. Ship-by-påminnelse: under 24 h kvar och säljaren har inte skickat.
    //    En notis per order, idempotent via `ship_by_reminded_at`.
    // ----------------------------------------------------------------
    const reminderThresholdIso = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    let soonQuery = supabaseAdmin
      .from('marketplace_orders')
      .select('id, seller_id, ship_by_deadline')
      .eq('status', 'succeeded')
      .is('shipped_at', null)
      .is('auto_cancelled_at', null)
      .is('ship_by_reminded_at', null)
      .not('ship_by_deadline', 'is', null)
      .gt('ship_by_deadline', nowIso)
      .lt('ship_by_deadline', reminderThresholdIso)
      .limit(limit);
    if (!includeTestOrders) {
      soonQuery = soonQuery.eq('is_test', false);
    }
    const { data: soonOrders } = await soonQuery;

    for (const order of soonOrders ?? []) {
      try {
        await supabaseAdmin
          .from('marketplace_orders')
          .update({ ship_by_reminded_at: nowIso })
          .eq('id', order.id);

        await supabaseAdmin.from('notifications').insert({
          user_id: order.seller_id,
          type: 'marketplace_ship_reminder',
          message:
            '1 dygn kvar att lämna in paketet — annars avbokas köpet automatiskt.',
        });

        shipReminders++;
      } catch (e) {
        errors++;
        console.warn(`Ship reminder failed for order ${order.id}:`, (e as Error).message);
      }
    }

    // ----------------------------------------------------------------
    // 1. Ship-by-deadline expiry → auto-cancel + refund
    // ----------------------------------------------------------------
    let lateQuery = supabaseAdmin
      .from('marketplace_orders')
      .select('id, listing_id, buyer_id, seller_id, stripe_payment_intent_id, stripe_charge_id, status, ship_by_deadline')
      .eq('status', 'succeeded')
      .is('shipped_at', null)
      .is('auto_cancelled_at', null)
      .lt('ship_by_deadline', nowIso)
      .limit(limit);
    if (!includeTestOrders) {
      lateQuery = lateQuery.eq('is_test', false);
    }
    const { data: lateOrders } = await lateQuery;

    for (const order of lateOrders ?? []) {
      try {
        if (order.stripe_charge_id) {
          await stripe.refunds.create({
            charge: order.stripe_charge_id,
            reason: 'requested_by_customer',
            metadata: {
              source: 'marketplace',
              order_id: order.id,
              trigger: 'ship_by_deadline_expired',
            },
          });
        } else if (order.stripe_payment_intent_id) {
          await stripe.paymentIntents.cancel(order.stripe_payment_intent_id).catch(() => {});
        }

        await supabaseAdmin
          .from('marketplace_orders')
          .update({
            status: 'cancelled',
            auto_cancelled_at: nowIso,
            is_held: false,
          })
          .eq('id', order.id);

        // Återpublicera annonsen i flödet.
        await supabaseAdmin
          .from('consignment_submissions')
          .update({ sold_at: null, sold_order_id: null })
          .eq('id', order.listing_id);

        await supabaseAdmin.from('notifications').insert([
          {
            user_id: order.buyer_id,
            type: 'marketplace_auto_refund',
            actor_id: order.seller_id,
            message:
              'Säljaren skickade inte i tid — du har fått pengarna återbetalade.',
          },
          {
            user_id: order.seller_id,
            type: 'marketplace_auto_cancelled',
            actor_id: order.buyer_id,
            message:
              'Din försäljning cancellerades eftersom paketet inte lämnades in i tid. Annonsen är publicerad igen.',
          },
        ]).catch(() => {});

        autoCancelled++;
      } catch (e) {
        errors++;
        console.warn(`Auto-cancel failed for order ${order.id}:`, (e as Error).message);
      }
    }

    // ----------------------------------------------------------------
    // 2. Buyer-approval-deadline expiry → auto-release
    // ----------------------------------------------------------------
    let ripeQuery = supabaseAdmin
      .from('marketplace_orders')
      .select(`
        id, buyer_id, seller_id, stripe_charge_id,
        amount_seller_payout, currency, is_held
      `)
      .eq('status', 'succeeded')
      .eq('is_held', true)
      .is('buyer_approved_at', null)
      .is('dispute_opened_at', null)
      .not('buyer_approval_deadline', 'is', null)
      .lt('buyer_approval_deadline', nowIso)
      .limit(limit);
    if (!includeTestOrders) {
      ripeQuery = ripeQuery.eq('is_test', false);
    }
    const { data: ripeOrders } = await ripeQuery;

    for (const order of ripeOrders ?? []) {
      try {
        const { data: seller } = await supabaseAdmin
          .from('profiles')
          .select('stripe_account_id, stripe_charges_enabled')
          .eq('id', order.seller_id)
          .single();

        const sellerReady = Boolean(
          seller?.stripe_account_id && seller?.stripe_charges_enabled
        );

        // Markera approval-fönstret som auto-passerat oavsett om vi
        // hinner transfer:a nu.
        await supabaseAdmin
          .from('marketplace_orders')
          .update({ buyer_approved_at: nowIso })
          .eq('id', order.id);

        // Notifiera köparen att fönstret stängdes (oavsett om
        // transfer hinner ske nu eller väntar på säljarens onboarding).
        await supabaseAdmin.from('notifications').insert({
          user_id: order.buyer_id,
          type: 'marketplace_payout_auto_released',
          actor_id: order.seller_id,
          message:
            'Tack! 48 h har gått utan reklamation och pengarna har frigjorts till säljaren.',
        }).catch(() => {});

        if (!sellerReady || !order.stripe_charge_id) {
          // Vänta tills säljaren onboardats (eller charge-id finns).
          // `process-pending-seller-payouts` plockar upp denna sen.
          await supabaseAdmin.from('notifications').insert({
            user_id: order.seller_id,
            type: 'marketplace_approved_pending_payout',
            actor_id: order.buyer_id,
            message:
              'Köparen har godkänt — slutför Stripe-onboardingen för att ta emot utbetalningen.',
          }).catch(() => {});
          continue;
        }

        let transferId: string;
        try {
          const transfer = await stripe.transfers.create({
            amount: order.amount_seller_payout,
            currency: order.currency || 'sek',
            destination: seller!.stripe_account_id,
            source_transaction: order.stripe_charge_id,
            metadata: {
              source: 'marketplace',
              order_id: order.id,
              seller_id: order.seller_id,
              trigger: 'auto_release_after_48h',
            },
          });
          transferId = transfer.id;
        } catch (transferErr) {
          const reason = (transferErr as Error).message ?? 'unknown';
          console.error(`Auto-release transfer failed for order ${order.id}:`, reason);
          await supabaseAdmin
            .from('marketplace_orders')
            .update({
              payout_failed_at: nowIso,
              payout_failure_reason: reason.slice(0, 500),
            })
            .eq('id', order.id);
          await notifyAutoPayoutFailure(supabaseAdmin, {
            orderId: order.id,
            sellerId: order.seller_id,
            buyerId: order.buyer_id,
            reason,
          });
          continue;
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
          .eq('id', order.id);

        await supabaseAdmin.from('notifications').insert({
          user_id: order.seller_id,
          type: 'marketplace_payout_released',
          actor_id: order.buyer_id,
          message:
            '48 h har gått utan reklamation — pengarna har skickats till ditt Stripe-konto.',
        }).catch(() => {});

        autoReleased++;
      } catch (e) {
        errors++;
        console.warn(`Auto-release failed for order ${order.id}:`, (e as Error).message);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        shipReminders,
        shipReminders48h,
        autoCancelled,
        autoReleased,
        errors,
        includeTestOrders,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('process-marketplace-deadlines error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function notifyAutoPayoutFailure(
  supabaseAdmin: ReturnType<typeof createClient>,
  args: { orderId: string; sellerId: string; buyerId: string; reason: string }
): Promise<void> {
  const adminIds = (Deno.env.get('ADMIN_USER_IDS') ?? '')
    .split(',').map((s) => s.trim()).filter(Boolean);
  const rows: Array<Record<string, unknown>> = adminIds.map((adminId) => ({
    user_id: adminId,
    type: 'marketplace_payout_failed_admin',
    actor_id: args.sellerId,
    message: `Auto-release-transfer misslyckades på order ${args.orderId.slice(0,8)}: ${args.reason.slice(0,140)}`,
  }));
  rows.push({
    user_id: args.sellerId,
    type: 'marketplace_approved_pending_payout',
    actor_id: args.buyerId,
    message:
      '48h-fönstret är slut, men Stripe-utbetalningen misslyckades. Vi försöker igen automatiskt.',
  });
  await supabaseAdmin.from('notifications').insert(rows).catch(() => {});
}

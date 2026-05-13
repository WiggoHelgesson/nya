/**
 * CANCEL MARKETPLACE ORDER (buyer-initiated, pre-ship)
 * ====================================================
 * Köparen kan avboka sitt eget köp innan paketet lämnats in:
 *
 *   - status='succeeded'
 *   - shipped_at IS NULL
 *   - shipping_status IN ('pending','label_ready','manual')
 *   - dispute_opened_at IS NULL
 *
 * Vi:
 *   - `stripe.refunds.create` på `stripe_charge_id`
 *   - sätter status='cancelled', is_held=false, refunded_at=now()
 *   - återpublicerar listingen (`sold_at=NULL`, `sold_order_id=NULL`)
 *   - notiser till köpare + säljare
 *
 * Auth: Bearer JWT från köparen.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@14.21.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { SHIPMONDO_BASE_URL } from '../_shared/shipmondoMapping.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

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

    const { orderId } = await req.json() as { orderId?: string };
    if (!orderId) throw new Error('orderId is required');

    const { data: order, error: orderErr } = await supabaseAdmin
      .from('marketplace_orders')
      .select(`
        id, listing_id, buyer_id, seller_id, status, is_held, shipped_at,
        shipping_status, amount_buyer_total, stripe_charge_id,
        stripe_payment_intent_id, dispute_opened_at, shipmondo_shipment_id
      `)
      .eq('id', orderId)
      .single();
    if (orderErr || !order) throw new Error('Order not found');

    if (order.buyer_id !== user.id) {
      throw new Error('Bara köparen kan avboka detta köp');
    }
    if (order.dispute_opened_at) {
      throw new Error('Tvist är öppnad — kontakta supporten');
    }
    if (order.shipped_at) {
      throw new Error('Paketet är redan inlämnat — du kan inte avboka, anmäl problem istället');
    }
    if (order.status !== 'succeeded') {
      throw new Error(`Ordern går inte att avboka (status=${order.status})`);
    }
    const refundableShippingStatuses = ['pending', 'label_ready', 'manual'];
    if (
      order.shipping_status &&
      !refundableShippingStatuses.includes(order.shipping_status)
    ) {
      throw new Error(`Ordern går inte att avboka (shipping_status=${order.shipping_status})`);
    }
    if (!order.stripe_charge_id) {
      throw new Error('Saknar stripe_charge_id — kontakta supporten');
    }

    // Best-effort: ta bort Shipmondo-sändning om den finns.
    if (order.shipmondo_shipment_id) {
      try {
        const base = SHIPMONDO_BASE_URL;
        const user = Deno.env.get('SHIPMONDO_API_USER') ?? '';
        const key = Deno.env.get('SHIPMONDO_API_KEY') ?? '';
        if (user && key) {
          const token = btoa(`${user}:${key}`);
          await fetch(
            `${base}/shipments/${encodeURIComponent(String(order.shipmondo_shipment_id))}`,
            {
              method: 'DELETE',
              headers: { Authorization: `Basic ${token}`, Accept: 'application/json' },
            },
          );
        }
      } catch (e) {
        console.warn('Shipmondo cancel failed (non-fatal):', (e as Error).message);
      }
    }

    await stripe.refunds.create({
      charge: order.stripe_charge_id,
      amount: order.amount_buyer_total,
      reason: 'requested_by_customer',
      metadata: {
        source: 'marketplace',
        order_id: order.id,
        trigger: 'buyer_cancel_pre_ship',
      },
    });

    const nowIso = new Date().toISOString();
    await supabaseAdmin
      .from('marketplace_orders')
      .update({
        status: 'cancelled',
        is_held: false,
        refunded_at: nowIso,
      })
      .eq('id', order.id);

    // Återpublicera listingen — säljaren ska kunna sälja igen.
    if (order.listing_id) {
      await supabaseAdmin
        .from('consignment_submissions')
        .update({ sold_at: null, sold_order_id: null })
        .eq('id', order.listing_id);
    }

    await supabaseAdmin.from('notifications').insert([
      {
        user_id: order.buyer_id,
        type: 'marketplace_cancelled',
        actor_id: order.seller_id,
        message: 'Köpet är avbokat. Hela beloppet återbetalas inom 5 bankdagar.',
      },
      {
        user_id: order.seller_id,
        type: 'marketplace_cancelled',
        actor_id: order.buyer_id,
        message: 'Köparen har avbokat innan paketet lämnades in. Annonsen är nu åter publicerad.',
      },
    ]).catch(() => {});

    return new Response(
      JSON.stringify({ success: true, orderId, refunded: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('cancel-marketplace-order error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

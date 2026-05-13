/**
 * ADMIN MARK ORDER SHIPPED
 * ========================
 * Manuell flagga som admin sätter när Sendify-bokningen failade och vi
 * skickat paketet via en annan kanal (PostNord-app, manual label PDF
 * etc). Sätter:
 *   - shipped_at = now()
 *   - shipping_status = 'picked_up'
 *   - shipping_carrier (om tracking_url tyder på det)
 *   - shipping_tracking_number / shipping_tracking_url om angivna
 *   - shipping_label_method = 'manual_admin'
 *
 * Pingar köparen med `marketplace_picked_up` (samma typ som det
 * automatiska Sendify-flödet).
 *
 * Auth: caller måste finnas i `ADMIN_USER_IDS` eller passera `is_admin()`.
 *
 * Body: { orderId, trackingNumber?, trackingUrl? }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
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
      const { data: ok } = await supabaseClient.rpc('is_admin');
      if (ok !== true) throw new Error('Admin access required');
    }

    const { orderId, trackingNumber, trackingUrl } = await req.json() as {
      orderId?: string;
      trackingNumber?: string;
      trackingUrl?: string;
    };
    if (!orderId) throw new Error('orderId is required');

    const { data: order } = await supabaseAdmin
      .from('marketplace_orders')
      .select('id, buyer_id, seller_id, shipped_at, shipping_status, status')
      .eq('id', orderId)
      .single();
    if (!order) throw new Error('Order not found');
    if (order.shipped_at) {
      return ok({ success: true, alreadyShipped: true, orderId });
    }
    if (!['succeeded'].includes(order.status)) {
      throw new Error(`Cannot mark shipped — order status is ${order.status}`);
    }

    const nowIso = new Date().toISOString();
    const updates: Record<string, unknown> = {
      shipped_at: nowIso,
      shipping_status: 'picked_up',
    };
    if (trackingNumber && trackingNumber.length > 0) {
      updates.shipping_tracking_number = trackingNumber.slice(0, 80);
    }
    if (trackingUrl && trackingUrl.length > 0) {
      updates.shipping_tracking_url = trackingUrl.slice(0, 500);
    }

    await supabaseAdmin
      .from('marketplace_orders')
      .update(updates)
      .eq('id', orderId);

    await supabaseAdmin.from('notifications').insert({
      user_id: order.buyer_id,
      type: 'marketplace_picked_up',
      actor_id: order.seller_id,
      message: 'Säljaren har lämnat in paketet — det är på väg!',
    }).catch(() => {});

    return ok({ success: true, orderId });
  } catch (error) {
    console.error('admin-mark-order-shipped error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

function ok(payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

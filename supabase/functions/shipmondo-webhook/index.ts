/**
 * SHIPMONDO WEBHOOK
 * =================
 * Verifies JWT (HS256) in body.data per Shipmondo docs, then updates
 * marketplace_orders.shipping_status by shipmondo_shipment_id.
 *
 * Secret: SHIPMONDO_WEBHOOK_SECRET (same key configured in Shipmondo portal).
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { verify } from 'https://deno.land/x/djwt@v2.9/mod.ts';
import { mapShipmondoShippingStatus } from '../_shared/shipmondoMapping.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, smd-resource-type, smd-resource-id, smd-action, smd-webhook-id, smd-user',
};

async function hmacKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify'],
  );
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response('method not allowed', { status: 405, headers: corsHeaders });
  }

  try {
    const secret = Deno.env.get('SHIPMONDO_WEBHOOK_SECRET') ?? '';
    if (!secret.trim()) {
      console.warn('shipmondo-webhook: SHIPMONDO_WEBHOOK_SECRET not set');
      return new Response(JSON.stringify({ ok: false, error: 'not configured' }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json() as { data?: string };
    const jwtStr = typeof body?.data === 'string' ? body.data : '';
    if (!jwtStr) {
      return new Response(JSON.stringify({ ok: false, error: 'missing data' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const key = await hmacKey(secret);
    let payload: Record<string, unknown>;
    try {
      payload = await verify(jwtStr, key) as Record<string, unknown>;
    } catch (e) {
      console.warn('shipmondo-webhook: JWT verify failed', (e as Error).message);
      return new Response(JSON.stringify({ ok: false, error: 'invalid jwt' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const shipment = payload.data as Record<string, unknown> | undefined;
    if (!shipment || typeof shipment.id === 'undefined') {
      return new Response(JSON.stringify({ ok: true, note: 'no shipment id in payload' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const smId = String(shipment.id);
    const statusRaw = (
      shipment.shipment_status ??
      shipment.status ??
      ''
    ).toString();

    const mapped = mapShipmondoShippingStatus(statusRaw);
    if (!mapped) {
      return new Response(JSON.stringify({ ok: true, ignored: statusRaw }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const tn = shipment.tracking_number ?? shipment.barcode;
    const tu = shipment.tracking_url ?? shipment.public_tracking_url;

    const { data: orderRows } = await supabaseAdmin
      .from('marketplace_orders')
      .select('id, buyer_id, seller_id, shipping_status, shipped_at, buyer_approval_deadline')
      .eq('shipmondo_shipment_id', smId)
      .limit(1);

    const order = orderRows?.[0];
    if (!order) {
      return new Response(JSON.stringify({ ok: true, note: 'order not found' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (order.shipping_status === mapped) {
      return new Response(JSON.stringify({ ok: true, unchanged: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const updates: Record<string, unknown> = { shipping_status: mapped };
    if (typeof tn === 'string' && tn.trim()) {
      updates.shipping_tracking_number = tn.trim();
    }
    if (typeof tu === 'string' && tu.trim()) {
      updates.shipping_tracking_url = tu.trim();
    }

    const isFirstShipped =
      (mapped === 'picked_up' || mapped === 'in_transit' || mapped === 'delivered') &&
      !order.shipped_at;
    if (isFirstShipped) {
      updates.shipped_at = new Date().toISOString();
    }
    if (mapped === 'delivered') {
      updates.shipping_delivered_at = new Date().toISOString();
      if (!order.buyer_approval_deadline) {
        updates.buyer_approval_deadline = new Date(
          Date.now() + 48 * 60 * 60 * 1000,
        ).toISOString();
      }
    }

    await supabaseAdmin
      .from('marketplace_orders')
      .update(updates)
      .eq('id', order.id);

    return new Response(JSON.stringify({ ok: true, orderId: order.id, status: mapped }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('shipmondo-webhook error:', e);
    return new Response(JSON.stringify({ ok: false }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

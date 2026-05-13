/**
 * POLL SHIPMONDO TRACKING
 * =======================
 * Cron-friendly: GET /shipments/{id} for active orders.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import {
  SHIPMONDO_BASE_URL,
  shipmondoHeaders,
  mapShipmondoShippingStatus,
} from '../_shared/shipmondoMapping.ts';
import { hydrateMarketplaceOrderLabelFromShipmondo } from '../_shared/marketplaceLabelHydrate.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const ACTIVE_STATUSES = ['label_ready', 'picked_up', 'in_transit', 'arrived_servicepoint'];

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const authHeader = req.headers.get('Authorization') ?? '';
    const provided = authHeader.replace(/^Bearer\s+/i, '');
    if (!serviceRoleKey || provided !== serviceRoleKey) {
      return new Response(
        JSON.stringify({ success: false, error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    let limit = 200;
    try {
      const body = await req.json();
      const requested = Number(body?.limit);
      if (Number.isFinite(requested) && requested > 0) {
        limit = Math.min(500, Math.round(requested));
      }
    } catch {
      // empty body
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey,
    );

    const { data: orders, error: fetchError } = await supabaseAdmin
      .from('marketplace_orders')
      .select(`
        id, listing_id, buyer_id, seller_id, is_held, status,
        shipping_status, shipmondo_shipment_id,
        shipping_tracking_number, shipping_tracking_url,
        shipping_label_url, shipping_qr_payload,
        shipped_at, buyer_approval_deadline
      `)
      .in('shipping_status', ACTIVE_STATUSES)
      .not('shipmondo_shipment_id', 'is', null)
      .limit(limit);

    if (fetchError) throw new Error(fetchError.message);

    const items = orders ?? [];
    let updated = 0;
    let delivered = 0;
    let errors = 0;

    for (const order of items) {
      try {
        const smId = order.shipmondo_shipment_id as string;
        if (!smId) continue;

        const rawLabel = order.shipping_label_url as string | null | undefined;
        const labelMissing =
          rawLabel == null || String(rawLabel).trim() === '';
        if (labelMissing) {
          try {
            await hydrateMarketplaceOrderLabelFromShipmondo(supabaseAdmin, {
              id: String(order.id),
              seller_id: String(order.seller_id),
              shipmondo_shipment_id: smId,
              shipping_label_url: order.shipping_label_url,
              shipping_tracking_number: order.shipping_tracking_number,
              shipping_tracking_url: order.shipping_tracking_url,
              shipping_qr_payload: order.shipping_qr_payload,
            }, { pollAttempts: 4, pollDelayMs: 800 });
          } catch (e) {
            console.warn(
              `label hydrate failed for order ${order.id}:`,
              (e as Error).message,
            );
          }
        }

        const tracking = await fetchShipmentStatus(smId);
        if (!tracking) continue;

        const mapped = mapShipmondoShippingStatus(tracking.status);
        if (!mapped) continue;
        if (mapped === order.shipping_status) continue;

        const updates: Record<string, unknown> = { shipping_status: mapped };
        if (tracking.tracking_number && !order.shipping_tracking_number) {
          updates.shipping_tracking_number = tracking.tracking_number;
        }
        if (tracking.tracking_url && !order.shipping_tracking_url) {
          updates.shipping_tracking_url = tracking.tracking_url;
        }

        const isFirstShippedTransition =
          (mapped === 'picked_up' || mapped === 'in_transit' || mapped === 'delivered') &&
          !order.shipped_at;

        if (isFirstShippedTransition) {
          updates.shipped_at = new Date().toISOString();
        }

        if (mapped === 'delivered') {
          updates.shipping_delivered_at = new Date().toISOString();
          if (!order.buyer_approval_deadline) {
            updates.buyer_approval_deadline = new Date(
              Date.now() + 48 * 60 * 60 * 1000,
            ).toISOString();
          }
          delivered++;
        }

        await supabaseAdmin
          .from('marketplace_orders')
          .update(updates)
          .eq('id', order.id);

        if (
          isFirstShippedTransition &&
          (mapped === 'picked_up' || mapped === 'in_transit')
        ) {
          try {
            const isPickedUp = mapped === 'picked_up';
            await supabaseAdmin.from('notifications').insert({
              user_id: order.buyer_id,
              type: isPickedUp ? 'marketplace_picked_up' : 'marketplace_in_transit',
              actor_id: order.seller_id,
              comment_text: isPickedUp
                ? 'Säljaren har lämnat in paketet — det är på väg!'
                : 'Paketet är på väg till dig.',
            });
          } catch (e) {
            console.warn('shipped notification insert failed:', (e as Error).message);
          }
        }

        if (mapped === 'delivered') {
          try {
            await supabaseAdmin.from('notifications').insert([
              {
                user_id: order.buyer_id,
                type: 'marketplace_delivered',
                actor_id: order.seller_id,
                comment_text:
                  'Paketet är levererat! Du har 48 h på dig att godkänna varan eller anmäla problem.',
              },
              {
                user_id: order.seller_id,
                type: 'marketplace_delivered',
                actor_id: order.buyer_id,
                comment_text:
                  'Köparen har fått paketet. Utbetalningen frigörs efter 48 h om allt är okej.',
              },
            ]);
          } catch (e) {
            console.warn('delivered notification insert failed:', (e as Error).message);
          }
        }

        updated++;
      } catch (e) {
        errors++;
        console.warn(`tracking poll failed for order ${order.id}:`, (e as Error).message);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        polled: items.length,
        updated,
        delivered,
        errors,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
    );
  } catch (error) {
    console.error('poll-shipmondo-tracking error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});

interface TrackingResult {
  status: string;
  tracking_number: string | null;
  tracking_url: string | null;
}

async function fetchShipmentStatus(shipmentId: string): Promise<TrackingResult | null> {
  const url = `${SHIPMONDO_BASE_URL}/shipments/${encodeURIComponent(shipmentId)}`;
  const resp = await fetch(url, { method: 'GET', headers: shipmondoHeaders() });
  if (!resp.ok) {
    if (resp.status === 404) return null;
    const errText = await resp.text();
    throw new Error(`Shipmondo shipment ${resp.status}: ${errText}`);
  }
  const json = await resp.json() as Record<string, unknown>;
  const status: string = (
    json?.shipment_status ??
    json?.status ??
    (json?.shipment as Record<string, unknown> | undefined)?.status ??
    ''
  ).toString().toLowerCase();
  const trackingNumber: string | null =
    (json?.tracking_number as string | undefined) ??
    (json?.barcode as string | undefined) ??
    null;
  const trackingUrl: string | null =
    (json?.tracking_url as string | undefined) ??
    (json?.public_tracking_url as string | undefined) ??
    null;
  if (!status) return null;
  return { status, tracking_number: trackingNumber, tracking_url: trackingUrl };
}

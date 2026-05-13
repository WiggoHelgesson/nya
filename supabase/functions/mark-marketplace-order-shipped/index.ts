/**
 * Service role only: legacy manual shipped (when Shipmondo tracking was delayed).
 * Seller JWT calls are rejected — status comes from poll-shipmondo-tracking.
 */
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { resolveListingConversation } from '../_shared/marketplaceListingConversation.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const BLOCKED_STATUSES = new Set(['picked_up', 'in_transit', 'arrived_servicepoint', 'delivered']);

const DISABLED_MSG =
  'Manuell fraktmarkering är avstängd. Orderstatus uppdateras automatiskt när paketet lämnats in enligt Shipmondo.';

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing Authorization header');

    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const bearerToken = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (bearerToken !== serviceRoleKey) {
      return new Response(JSON.stringify({ success: false, error: DISABLED_MSG }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey,
    );

    const { orderId } = await req.json();
    if (!orderId) throw new Error('orderId is required');

    const { data: order, error: ordErr } = await supabaseAdmin
      .from('marketplace_orders')
      .select(
        'id, seller_id, buyer_id, listing_id, listing_title, status, shipped_at, shipping_status, shipping_carrier, shipping_tracking_number, shipping_tracking_url',
      )
      .eq('id', orderId)
      .single();
    if (ordErr || !order) throw new Error('Order not found');
    if (!['succeeded'].includes(order.status)) {
      throw new Error(`Cannot mark shipped — order status is ${order.status}`);
    }
    if (order.shipped_at) {
      return ok({ success: true, alreadyShipped: true, orderId });
    }

    const ss = (order.shipping_status as string | null | undefined) ?? '';
    if (BLOCKED_STATUSES.has(ss)) {
      return ok({
        success: true,
        alreadyTracked: true,
        orderId,
        message: 'Fraktstatus uppdateras automatiskt — ingen manuell åtgärd behövs.',
      });
    }

    const nowIso = new Date().toISOString();
    await supabaseAdmin
      .from('marketplace_orders')
      .update({
        shipped_at: nowIso,
        shipping_status: 'picked_up',
      })
      .eq('id', orderId);

    const listingId = order.listing_id as string | null;
    const buyerId = order.buyer_id as string;
    const sellerId = order.seller_id as string;
    const listingTitle =
      typeof order.listing_title === 'string' ? order.listing_title : 'Din order';

    if (listingId) {
      const conv = await resolveListingConversation(supabaseAdmin, buyerId, sellerId, listingId);
      if (conv) {
        const buyerPayload = {
          kind: 'shipping_in_transit',
          order_id: orderId,
          listing_id: listingId,
          listing_title: listingTitle,
          carrier: order.shipping_carrier ?? null,
          tracking_number: order.shipping_tracking_number ?? null,
          tracking_url: order.shipping_tracking_url ?? null,
        };
        await supabaseAdmin.from('direct_messages').insert({
          conversation_id: conv,
          sender_id: sellerId,
          message: JSON.stringify(buyerPayload),
          message_type: 'shipping_in_transit',
        });
      }
    }

    await supabaseAdmin.from('notifications').insert({
      user_id: buyerId,
      type: 'marketplace_in_transit',
      actor_id: sellerId,
      related_id: listingId,
      comment_text: 'Säljaren har lämnat in paketet — det är på väg!',
    }).catch(() => {});

    return ok({ success: true, orderId });
  } catch (error) {
    console.error('mark-marketplace-order-shipped:', error);
    return new Response(JSON.stringify({ success: false, error: (error as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

function ok(payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

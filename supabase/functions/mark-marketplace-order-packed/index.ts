/**
 * Service role only: legacy seller "packed" signal (DM + buyer ping).
 * App UI no longer calls this for sellers — manual packing is disabled for JWT users.
 */
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { resolveListingConversation } from '../_shared/marketplaceListingConversation.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const DISABLED_MSG =
  'Manuell packningsmarkering är avstängd. Orderstatus uppdateras automatiskt via Shipmondo när paketet lämnats in hos ombud.';

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
      .select('id, seller_id, buyer_id, listing_id, listing_title, status, seller_packed_at')
      .eq('id', orderId)
      .single();
    if (ordErr || !order) throw new Error('Order not found');
    if (!['succeeded'].includes(order.status)) {
      throw new Error(`Cannot pack — order status is ${order.status}`);
    }
    if (order.seller_packed_at) {
      return ok({ success: true, alreadyPacked: true, orderId });
    }

    const nowIso = new Date().toISOString();
    await supabaseAdmin
      .from('marketplace_orders')
      .update({ seller_packed_at: nowIso })
      .eq('id', orderId);

    const listingId = order.listing_id as string | null;
    const buyerId = order.buyer_id as string;
    const sellerId = order.seller_id as string;

    if (listingId) {
      const conv = await resolveListingConversation(supabaseAdmin, buyerId, sellerId, listingId);
      if (conv) {
        const payload = {
          kind: 'seller_packed',
          order_id: order.id,
          listing_id: listingId,
          listing_title: order.listing_title ?? null,
        };
        await supabaseAdmin.from('direct_messages').insert({
          conversation_id: conv,
          sender_id: sellerId,
          message: JSON.stringify(payload),
          message_type: 'seller_packed',
        });
      }
    }

    await supabaseAdmin.from('notifications').insert({
      user_id: buyerId,
      type: 'marketplace_direct_message',
      actor_id: sellerId,
      related_id: listingId,
      comment_text: 'Säljaren har packat din order och skickar snart.',
    }).catch(() => {});

    return ok({ success: true, orderId });
  } catch (error) {
    console.error('mark-marketplace-order-packed:', error);
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

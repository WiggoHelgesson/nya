/**
 * DISPUTE MARKETPLACE ORDER
 * =========================
 * Buyer-triggered "Anmäl problem" — fryser ordern och stoppar
 * auto-release. Manuell hantering av admin krävs.
 *
 * Vi gör INTE en Stripe-refund automatiskt — det är upp till admin
 * att avgöra (full refund, partial, eller release ändå om säljaren
 * har skickat enligt annonsen).
 *
 * Usage:
 * POST /dispute-marketplace-order
 * Body: { orderId: string, reason: string }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
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

    const { orderId, reason } = await req.json();
    if (!orderId) throw new Error('orderId is required');
    if (!reason || typeof reason !== 'string' || reason.trim().length < 5) {
      throw new Error('Anmälan kräver en kort beskrivning av problemet');
    }

    const { data: order, error: orderErr } = await supabaseAdmin
      .from('marketplace_orders')
      .select('id, buyer_id, seller_id, status, dispute_opened_at, buyer_approved_at')
      .eq('id', orderId)
      .single();
    if (orderErr || !order) throw new Error('Order not found');

    if (order.buyer_id !== user.id) {
      throw new Error('Only the buyer can open a dispute');
    }
    if (order.dispute_opened_at) {
      return new Response(
        JSON.stringify({ success: true, alreadyOpen: true, orderId }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    if (order.status === 'released' || order.buyer_approved_at) {
      throw new Error('Du kan inte anmäla en order som redan är godkänd och utbetald');
    }

    const trimmedReason = reason.trim().slice(0, 1000);
    const nowIso = new Date().toISOString();

    await supabaseAdmin
      .from('marketplace_orders')
      .update({
        dispute_opened_at: nowIso,
        dispute_reason: trimmedReason,
        status: 'disputed',
      })
      .eq('id', orderId);

    const partyNotifications: Array<Record<string, unknown>> = [
      {
        user_id: order.seller_id,
        type: 'marketplace_dispute_opened',
        actor_id: order.buyer_id,
        message: 'Köparen har anmält ett problem med ordern. Vi hör av oss.',
      },
      {
        user_id: order.buyer_id,
        type: 'marketplace_dispute_received',
        actor_id: order.seller_id,
        message: 'Vi har tagit emot din anmälan. Supporten kontaktar dig inom kort.',
      },
    ];

    // Admin-notiser: vi skickar EN rad per admin (user_id = admin) så
    // push-triggern faktiskt levererar. ADMIN_USER_IDS är en
    // kommaseparerad lista i secrets.
    const adminIdsRaw = Deno.env.get('ADMIN_USER_IDS') ?? '';
    const adminIds = adminIdsRaw
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

    const adminNotifications = adminIds.map((adminId) => ({
      user_id: adminId,
      type: 'admin_marketplace_dispute',
      actor_id: order.buyer_id,
      message: `Ny tvist på order ${orderId}: ${trimmedReason.slice(0, 120)}`,
    }));

    await supabaseAdmin
      .from('notifications')
      .insert([...partyNotifications, ...adminNotifications])
      .catch(() => {});

    return new Response(
      JSON.stringify({ success: true, orderId }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('dispute-marketplace-order error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

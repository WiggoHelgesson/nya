/**
 * DECLINE MARKETPLACE OFFER (Prisförslag)
 * =======================================
 * Called by the seller to decline a buyer's price offer. Cancels the
 * PaymentIntent (no money moves – the card authorisation is released)
 * and marks the offer as declined.
 *
 * Usage:
 * POST /decline-marketplace-offer
 * Body: { offerId: string }
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

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) throw new Error('Unauthorized');

    const { offerId } = await req.json();
    if (!offerId) throw new Error('offerId is required');

    const { data: offer, error: offerError } = await supabaseAdmin
      .from('listing_offers')
      .select('*')
      .eq('id', offerId)
      .single();

    if (offerError || !offer) throw new Error('Offer not found');
    if (offer.seller_id !== user.id) throw new Error('Only the seller can decline this offer');
    if (offer.status !== 'pending') {
      throw new Error(`Offer is not pending (status: ${offer.status})`);
    }

    if (offer.stripe_payment_intent_id) {
      try {
        await stripe.paymentIntents.cancel(offer.stripe_payment_intent_id);
      } catch (e) {
        // If the PI was already cancelled or transitioned we still mark
        // the offer as declined – the authoritative truth is Stripe's
        // PaymentIntent status which the webhook will sync.
        console.warn('Failed to cancel PI; marking declined anyway:', (e as Error).message);
      }
    }

    await supabaseAdmin
      .from('listing_offers')
      .update({
        status: 'declined',
        responded_at: new Date().toISOString(),
      })
      .eq('id', offer.id);

    // Best-effort buyer notification.
    try {
      await supabaseAdmin.from('notifications').insert({
        user_id: offer.buyer_id,
        type: 'marketplace_offer_declined',
        actor_id: offer.seller_id,
        message: `Ditt prisförslag (${offer.offered_price_sek} kr) avböjdes.`,
      });
    } catch (e) {
      console.error('Failed to insert buyer notification:', e);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error) {
    console.error('decline-marketplace-offer error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});

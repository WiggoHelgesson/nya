/**
 * ACCEPT MARKETPLACE OFFER (Prisförslag)
 * ======================================
 * Called by the seller to accept a buyer's price offer.
 *
 * What this DOES:
 *   - Marks `listing_offers.status = 'accepted'` and sets `responded_at`.
 *   - Auto-cancels every other pending offer on the same listing (also
 *     cancels their Stripe PaymentIntents so the authorisations release).
 *   - Finds/creates a `direct_conversations` row for the (buyer, seller,
 *     listing) triplet and inserts a system message with
 *     `message_type='offer_accepted'` that the chat UI renders as a
 *     "Slutför köp"-card.
 *   - Sends a best-effort notification to the buyer.
 *
 * What this DOES NOT do:
 *   - It does NOT capture the PaymentIntent.
 *   - It does NOT create a `marketplace_orders` row.
 *   - It does NOT mark the listing as sold.
 *
 * Those steps happen in `finalize-marketplace-offer` after the buyer
 * submits their shipping address inside the chat.
 *
 * Usage:
 * POST /accept-marketplace-offer
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
    if (offer.seller_id !== user.id) throw new Error('Only the seller can accept this offer');
    if (offer.status !== 'pending') {
      throw new Error(`Offer is not pending (status: ${offer.status})`);
    }
    if (!offer.stripe_payment_intent_id) {
      throw new Error('Offer has no PaymentIntent');
    }

    // Verify listing is still available
    const { data: listing } = await supabaseAdmin
      .from('consignment_submissions')
      .select('id, sold_at, user_id, title')
      .eq('id', offer.listing_id)
      .single();

    if (!listing) throw new Error('Listing not found');
    if (listing.sold_at) throw new Error('Listing already sold');
    if (listing.user_id !== user.id) throw new Error('Only the seller can accept this offer');

    // 1. Mark offer accepted (capture happens later in finalize).
    await supabaseAdmin
      .from('listing_offers')
      .update({
        status: 'accepted',
        responded_at: new Date().toISOString(),
      })
      .eq('id', offer.id);

    // 2. Auto-cancel other pending offers on the same listing.
    const { data: otherOffers } = await supabaseAdmin
      .from('listing_offers')
      .select('id, stripe_payment_intent_id')
      .eq('listing_id', offer.listing_id)
      .eq('status', 'pending')
      .neq('id', offer.id);

    if (otherOffers && otherOffers.length > 0) {
      await Promise.all(otherOffers.map(async (o) => {
        if (o.stripe_payment_intent_id) {
          try {
            await stripe.paymentIntents.cancel(o.stripe_payment_intent_id);
          } catch (e) {
            console.warn('Failed to cancel PI', o.stripe_payment_intent_id, (e as Error).message);
          }
        }
        await supabaseAdmin
          .from('listing_offers')
          .update({ status: 'cancelled', responded_at: new Date().toISOString() })
          .eq('id', o.id);
      }));
    }

    // 3. Find or create the direct_conversations row for this
    // (buyer, seller, listing) triplet and insert a system "offer_accepted"
    // message that the chat UI renders as a "Slutför köp"-card.
    const conversationId = await resolveListingConversation(
      supabaseAdmin,
      offer.buyer_id,
      offer.seller_id,
      offer.listing_id
    );

    if (conversationId) {
      const payload = {
        kind: 'offer_accepted',
        offer_id: offer.id,
        listing_id: offer.listing_id,
        listing_title: listing.title ?? null,
        offered_price_sek: offer.offered_price_sek,
        amount_buyer_total_ore: offer.amount_buyer_total_ore,
        seller_id: offer.seller_id,
        buyer_id: offer.buyer_id,
      };
      try {
        await supabaseAdmin
          .from('direct_messages')
          .insert({
            conversation_id: conversationId,
            sender_id: offer.seller_id,
            message: JSON.stringify(payload),
            message_type: 'offer_accepted',
          });
      } catch (e) {
        console.error('Failed to insert offer_accepted DM:', e);
      }
    }

    // 4. Best-effort buyer notification.
    try {
      await supabaseAdmin.from('notifications').insert({
        user_id: offer.buyer_id,
        type: 'marketplace_offer_accepted',
        actor_id: offer.seller_id,
        message: `Ditt prisförslag (${offer.offered_price_sek} kr) accepterades! Öppna chatten för att fylla i leveransadress och slutföra köpet.`,
      });
    } catch (e) {
      console.error('Failed to insert buyer notification:', e);
    }

    return new Response(
      JSON.stringify({
        success: true,
        offerId: offer.id,
        conversationId: conversationId ?? null,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error) {
    console.error('accept-marketplace-offer error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});

/**
 * Find (via the `find_direct_conversation` SQL function) or create a
 * direct_conversations row tied to the listing + add both participants.
 * Returns null on failure so the caller can still succeed (the offer is
 * accepted either way).
 */
async function resolveListingConversation(
  supabaseAdmin: ReturnType<typeof createClient>,
  buyerId: string,
  sellerId: string,
  listingId: string
): Promise<string | null> {
  try {
    const { data: existingId } = await supabaseAdmin.rpc('find_direct_conversation', {
      p_user1: buyerId,
      p_user2: sellerId,
      p_listing: listingId,
    });

    if (existingId && typeof existingId === 'string' && existingId.length > 0) {
      return existingId;
    }

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('direct_conversations')
      .insert({
        created_by: sellerId,
        listing_id: listingId,
      })
      .select('id')
      .single();

    if (insertError || !inserted) {
      console.error('Failed to create conversation:', insertError);
      return null;
    }

    await supabaseAdmin
      .from('direct_conversation_participants')
      .insert([
        { conversation_id: inserted.id, user_id: buyerId },
        { conversation_id: inserted.id, user_id: sellerId },
      ]);

    return inserted.id as string;
  } catch (e) {
    console.error('resolveListingConversation error:', e);
    return null;
  }
}

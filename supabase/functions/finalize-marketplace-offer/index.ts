/**
 * FINALIZE MARKETPLACE OFFER (Prisförslag)
 * ========================================
 * Called by the BUYER after the seller has accepted their price offer.
 * The buyer submits their shipping address here (collected in-chat via
 * the "Slutför köp"-card on an `offer_accepted` direct message).
 *
 * This function:
 *   - Validates the caller is the buyer on the offer.
 *   - Requires `offer.status='accepted'` and a listing that isn't sold.
 *   - Attaches shipping + optional Connect transfer_data / application_fee
 *     to the Stripe PaymentIntent, then captures it.
 *   - Inserts the `marketplace_orders` row (with the shipping address).
 *   - Marks the listing as sold, flips the offer to `captured`.
 *   - Posts `purchase_completed` system message into the direct conversation
 *     (same payload shape as Köp nu `stripe-webhook` after shipping is booked).
 *
 * Usage:
 * POST /finalize-marketplace-offer
 * Body: {
 *   offerId: string,
 *   shipping: {
 *     name: string,
 *     address: string,   // single-line "street, details"
 *     postal: string,
 *     city: string,
 *     country?: string
 *   }
 * }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@14.21.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import {
  fetchBuyerDisplayName,
  resolveListingConversation,
} from '../_shared/marketplaceListingConversation.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function listingSnapshotFromRow(listing: Record<string, unknown> | null): {
  listing_title: string | null;
  listing_brand: string | null;
  listing_image_url: string | null;
} {
  if (!listing) {
    return { listing_title: null, listing_brand: null, listing_image_url: null };
  }
  const raw = listing.image_urls;
  const arr = Array.isArray(raw) ? raw : [];
  const first = arr.find((u) => typeof u === 'string' && (u as string).length > 0) as
    | string
    | undefined;
  const title = typeof listing.title === 'string' ? listing.title : null;
  const brand = typeof listing.user_brand === 'string' ? listing.user_brand : null;
  return {
    listing_title: title,
    listing_brand: brand,
    listing_image_url: first ?? null,
  };
}

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

    const { offerId, shipping } = await req.json();
    if (!offerId) throw new Error('offerId is required');
    if (!shipping?.name || !shipping?.address || !shipping?.postal || !shipping?.city) {
      throw new Error('Complete shipping address is required');
    }

    const { data: offer, error: offerError } = await supabaseAdmin
      .from('listing_offers')
      .select('*')
      .eq('id', offerId)
      .single();

    if (offerError || !offer) throw new Error('Offer not found');
    if (offer.buyer_id !== user.id) throw new Error('Only the buyer can finalise this offer');
    if (offer.status !== 'accepted') {
      throw new Error(`Offer is not accepted (status: ${offer.status})`);
    }
    if (!offer.stripe_payment_intent_id) {
      throw new Error('Offer has no PaymentIntent');
    }

    // Verify listing is still unsold.
    const { data: listing } = await supabaseAdmin
      .from('consignment_submissions')
      .select('id, sold_at, user_id, title, user_brand, image_urls')
      .eq('id', offer.listing_id)
      .single();

    if (!listing) throw new Error('Listing not found');
    if (listing.sold_at) throw new Error('Listing already sold');

    const listingSnap = listingSnapshotFromRow(listing as Record<string, unknown>);

    const buyerName = await fetchBuyerDisplayName(supabaseAdmin, offer.buyer_id as string);

    // Seller Stripe status — only used for downstream payout flow.
    // We DO NOT attach transfer_data here; the offer flow now uses the
    // same platform-charge + escrow model as Köp nu so the buyer is
    // protected by the 3-day ship deadline + 48h approval window.
    const { data: sellerProfile } = await supabaseAdmin
      .from('profiles')
      .select('id, stripe_account_id, stripe_charges_enabled')
      .eq('id', offer.seller_id)
      .single();

    void sellerProfile; // referenced below only for logging context

    // Insert marketplace_orders row BEFORE capturing so the webhook can
    // locate it by stripe_payment_intent_id on payment_intent.succeeded.
    // All marketplace orders are now `is_held=true` until the buyer
    // approves (or 48h pass after delivered) — see
    // approve-marketplace-order / process-marketplace-deadlines.
    const { data: orderRow, error: orderInsertError } = await supabaseAdmin
      .from('marketplace_orders')
      .insert({
        listing_id: offer.listing_id,
        buyer_id: offer.buyer_id,
        seller_id: offer.seller_id,
        stripe_payment_intent_id: offer.stripe_payment_intent_id,
        stripe_customer_id: offer.stripe_customer_id,
        amount_item: offer.amount_item_ore,
        amount_platform_fee: offer.amount_platform_fee_ore,
        amount_shipping: offer.amount_shipping_ore,
        amount_buyer_total: offer.amount_buyer_total_ore,
        amount_seller_payout: offer.amount_seller_payout_ore,
        currency: offer.currency ?? 'sek',
        status: 'pending',
        is_held: true,
        buyer_email: offer.buyer_email,
        buyer_shipping_name: shipping.name,
        buyer_shipping_address: shipping.address,
        buyer_shipping_postal: shipping.postal,
        buyer_shipping_city: shipping.city,
        shipping_carrier: offer.shipping_carrier ?? null,
        shipping_service_code: offer.shipping_service_code ?? null,
        shipping_product_name: offer.shipping_product_name ?? null,
        shipping_booking_token: offer.shipping_booking_token ?? null,
        shipping_booking_token_expires_at: offer.shipping_booking_token_expires_at ?? null,
        shipping_service_point_token: offer.shipping_service_point_token ?? null,
        shipping_service_point_name: offer.shipping_service_point_name ?? null,
        shipping_service_point_address: offer.shipping_service_point_address ?? null,
        shipping_status: 'pending',
        listing_title: listingSnap.listing_title,
        listing_brand: listingSnap.listing_brand,
        listing_image_url: listingSnap.listing_image_url,
        buyer_username: buyerName,
      })
      .select('id')
      .single();

    if (orderInsertError || !orderRow) {
      throw new Error(`Failed to create order: ${orderInsertError?.message ?? 'unknown'}`);
    }

    // Attach shipping address to the PI, then capture. Notera: ingen
    // `transfer_data` / `application_fee_amount` / `on_behalf_of` här
    // längre — alla marketplace-betalningar är platform-charge och
    // pengar flyttas till säljaren via `stripe.transfers.create` först
    // när köparen godkänt (eller 48 h efter delivered).
    const piUpdate: Stripe.PaymentIntentUpdateParams = {
      // Stripe skickar mail-kvitto efter capture om receipt_email satt.
      receipt_email: (offer.buyer_email as string | null | undefined) || user.email || undefined,
      shipping: {
        name: shipping.name,
        address: {
          line1: shipping.address,
          postal_code: shipping.postal,
          city: shipping.city,
          country: 'SE',
        },
      },
      metadata: {
        ...(offer.stripe_customer_id
          ? { stripe_customer_id: offer.stripe_customer_id }
          : {}),
        buyer_shipping_name: shipping.name,
        buyer_shipping_address: shipping.address,
        buyer_shipping_postal: shipping.postal,
        buyer_shipping_city: shipping.city,
        order_id: orderRow.id,
        source: 'marketplace',
        is_held: 'true',
      },
    };

    try {
      await stripe.paymentIntents.update(offer.stripe_payment_intent_id, piUpdate);
    } catch (e) {
      console.warn(
        'Could not update PI with shipping metadata before capture:',
        (e as Error).message
      );
    }

    const captured = await stripe.paymentIntents.capture(offer.stripe_payment_intent_id);

    // Trigger Sendify shipment booking. We do this synchronously so the
    // buyer/seller see the QR + tracking card in the chat immediately,
    // but we never let a failure here roll back the captured payment —
    // book-marketplace-shipping itself flips shipping_status='manual'
    // on failure so the admin can take over.
    try {
      const bookResp = await fetch(
        `${Deno.env.get('SUPABASE_URL')}/functions/v1/book-marketplace-shipping`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''}`,
            'apikey': Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
          },
          body: JSON.stringify({ orderId: orderRow.id }),
        }
      );
      if (!bookResp.ok) {
        const text = await bookResp.text();
        console.warn('book-marketplace-shipping non-OK:', bookResp.status, text);
      }
    } catch (e) {
      console.warn('book-marketplace-shipping invoke failed:', (e as Error).message);
    }

    // Mark listing sold.
    await supabaseAdmin
      .from('consignment_submissions')
      .update({
        sold_at: new Date().toISOString(),
        sold_order_id: orderRow.id,
      })
      .eq('id', offer.listing_id);

    // Flip offer → captured and persist buyer shipping.
    await supabaseAdmin
      .from('listing_offers')
      .update({
        status: 'captured',
        captured_at: new Date().toISOString(),
        buyer_shipping_name: shipping.name,
        buyer_shipping_address: shipping.address,
        buyer_shipping_postal: shipping.postal,
        buyer_shipping_city: shipping.city,
      })
      .eq('id', offer.id);

    const { data: orderAfter } = await supabaseAdmin
      .from('marketplace_orders')
      .select(
        'id, listing_id, seller_id, buyer_id, listing_title, amount_item, buyer_username, ship_by_deadline'
      )
      .eq('id', orderRow.id)
      .single();

    try {
      if (
        orderAfter &&
        orderAfter.listing_id &&
        orderAfter.buyer_id &&
        orderAfter.seller_id
      ) {
        const conv = await resolveListingConversation(
          supabaseAdmin,
          orderAfter.buyer_id as string,
          orderAfter.seller_id as string,
          orderAfter.listing_id as string
        );
        if (conv) {
          let buyerDisp =
            typeof orderAfter.buyer_username === 'string' && orderAfter.buyer_username.trim().length > 0
              ? orderAfter.buyer_username.trim()
              : await fetchBuyerDisplayName(supabaseAdmin, orderAfter.buyer_id as string);
          const payload = {
            kind: 'purchase_completed',
            order_id: orderAfter.id,
            listing_id: orderAfter.listing_id,
            listing_title: orderAfter.listing_title ?? listingSnap.listing_title ?? null,
            buyer_id: orderAfter.buyer_id,
            buyer_username: buyerDisp,
            seller_id: orderAfter.seller_id,
            amount_item_ore: orderAfter.amount_item,
            ship_by_deadline: orderAfter.ship_by_deadline ?? null,
          };
          const { error: dmErr } = await supabaseAdmin.from('direct_messages').insert({
            conversation_id: conv,
            sender_id: orderAfter.buyer_id,
            message: JSON.stringify(payload),
            message_type: 'purchase_completed',
          });
          if (dmErr) {
            console.error('direct_messages insert failed (finalize purchase_completed):', dmErr);
          }
        } else {
          console.warn('finalize-marketplace-offer: no conversation for purchase_completed', orderAfter.id);
        }
      }
    } catch (e) {
      console.error('Failed to insert purchase_completed DM:', e);
    }

    const productLabel =
      typeof listingSnap.listing_title === 'string' && listingSnap.listing_title.trim().length > 0
        ? listingSnap.listing_title.trim()
        : 'din produkt';
    const itemKr = Math.round(Number(offer.amount_item_ore ?? 0) / 100);
    const totalKr = Math.round(Number(offer.amount_buyer_total_ore ?? 0) / 100);
    const sellerBody = `${buyerName} köpte din ${productLabel} för ${itemKr} kr`;
    const buyerBody =
      `Ditt köp av ${productLabel} är genomfört — totalt ${totalKr} kr. Säljaren packar och skickar inom 3 dagar.`;

    const { error: notifErr } = await supabaseAdmin.from('notifications').insert([
      {
        user_id: offer.seller_id,
        type: 'marketplace_sale',
        actor_id: offer.buyer_id,
        related_id: offer.listing_id,
        comment_text: sellerBody,
      },
      {
        user_id: offer.buyer_id,
        type: 'marketplace_purchase',
        actor_id: offer.seller_id,
        related_id: offer.listing_id,
        comment_text: buyerBody,
      },
    ]);
    if (notifErr) {
      console.error('notifications insert failed (finalize marketplace_sale/purchase):', notifErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        orderId: orderRow.id,
        paymentIntentId: captured.id,
        status: captured.status,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error) {
    console.error('finalize-marketplace-offer error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});

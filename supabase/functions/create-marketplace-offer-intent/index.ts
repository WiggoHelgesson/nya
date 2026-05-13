/**
 * CREATE MARKETPLACE OFFER INTENT (Prisförslag)
 * =============================================
 * Creates a PaymentIntent with `capture_method: 'manual'` for a buyer
 * submitting a price offer on a community listing. The buyer's card is
 * authorised but no money moves until the seller accepts via
 * `accept-marketplace-offer` (which captures) or declines via
 * `decline-marketplace-offer` (which cancels the PI).
 *
 * Fee model: identical to `create-marketplace-payment-intent` but based on
 * the buyer's `offeredPriceSEK` instead of the listing's own price.
 *
 * Shipping address is NOT collected here. The buyer fills it in later, in
 * the chat, after the seller has accepted the offer (see
 * `finalize-marketplace-offer`).
 *
 * The buyer DOES pick a carrier + service + price up front (rates fetched
 * via `get-marketplace-shipping-rates`). The chosen rate is locked on the
 * `listing_offers` row so the price the buyer sees is exactly what we
 * charge.
 *
 * Usage:
 * POST /create-marketplace-offer-intent
 * Body: {
 *   listingId: string,
 *   offeredPriceSEK: number,        // must be > 0 and <= listing.price_sek
 *   message?: string,
 *   buyerEmail: string,
 *   shippingCarrier?: string,       // e.g. "postnord"
 *   shippingServiceCode?: string,   // e.g. "postnord_mypack_collect"
 *   shippingAmountOre?: number      // chosen rate price in öre
 * }
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@14.21.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const PLATFORM_FEE_PERCENT = 5;
const BUYER_PROTECTION_FLAT_ORE = 750; // 7.50 kr
const SHIPPING_FEE_ORE_FALLBACK = 4900; // 49 kr — only used if the client
                                        // didn't pass a Sendify-quoted rate.

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

    const {
      listingId,
      offeredPriceSEK,
      message,
      buyerEmail,
      shippingCarrier,
      shippingServiceCode,
      shippingProductName,
      shippingAmountOre,
      shippingBookingToken,
      shippingServicePointToken,
      shippingServicePointName,
      shippingServicePointAddress,
    } = await req.json();
    if (!listingId) throw new Error('listingId is required');
    if (!offeredPriceSEK || Number(offeredPriceSEK) <= 0) {
      throw new Error('offeredPriceSEK must be positive');
    }

    // Fetch listing + resolve seller (same schema-tolerant fallback as
    // create-marketplace-payment-intent).
    let listing: any = null;
    let listingError: any = null;
    {
      const res = await supabaseAdmin
        .from('consignment_submissions')
        .select('id, user_id, ai_payload, admin_status, price_sek, sold_at, title')
        .eq('id', listingId)
        .single();
      listing = res.data;
      listingError = res.error;
    }
    if (listingError) {
      const res = await supabaseAdmin
        .from('consignment_submissions')
        .select('id, user_id, ai_payload, admin_status, price_sek, title')
        .eq('id', listingId)
        .single();
      listing = res.data;
      listingError = res.error;
    }

    if (listingError || !listing) throw new Error('Listing not found');
    if (listing.admin_status !== 'accepted') throw new Error('Listing is not available for offers');
    if (listing.sold_at) throw new Error('Listing is already sold');
    if (listing.user_id === user.id) throw new Error('You cannot offer on your own listing');

    const listingPriceSEK = Number(
      listing.price_sek ??
        listing.ai_payload?.priceSEK ??
        listing.ai_payload?.price_sek ??
        0
    );
    if (!listingPriceSEK || listingPriceSEK <= 0) {
      throw new Error('Listing has no price');
    }

    const priceSEK = Math.round(Number(offeredPriceSEK));
    if (priceSEK > listingPriceSEK) {
      throw new Error('Offer cannot exceed the listing price');
    }
    if (priceSEK < 50) {
      throw new Error('Offer must be at least 50 kr');
    }

    const itemOre = Math.round(priceSEK * 100);
    const platformFeeOre = Math.round(itemOre * (PLATFORM_FEE_PERCENT / 100)) + BUYER_PROTECTION_FLAT_ORE;
    const shippingFeeOre = (() => {
      const candidate = Number(shippingAmountOre);
      if (Number.isFinite(candidate) && candidate > 0 && candidate < 100000) {
        return Math.round(candidate);
      }
      return SHIPPING_FEE_ORE_FALLBACK;
    })();
    const buyerTotalOre = itemOre + platformFeeOre + shippingFeeOre;
    const sellerPayoutOre = itemOre;
    const carrier = typeof shippingCarrier === 'string' && shippingCarrier.length > 0
      ? shippingCarrier.slice(0, 64)
      : null;
    const serviceCode = typeof shippingServiceCode === 'string' && shippingServiceCode.length > 0
      ? shippingServiceCode.slice(0, 128)
      : null;
    const productName = typeof shippingProductName === 'string' && shippingProductName.length > 0
      ? shippingProductName.slice(0, 128)
      : null;
    const bookingToken = typeof shippingBookingToken === 'string' && shippingBookingToken.length > 0
      ? shippingBookingToken.slice(0, 1024)
      : null;
    const bookingTokenExpiresAt = bookingToken
      ? new Date(Date.now() + 25 * 60 * 1000).toISOString()
      : null;
    const servicePointToken = typeof shippingServicePointToken === 'string' && shippingServicePointToken.length > 0
      ? shippingServicePointToken.slice(0, 256)
      : null;
    const servicePointName = typeof shippingServicePointName === 'string' && shippingServicePointName.length > 0
      ? shippingServicePointName.slice(0, 128)
      : null;
    const servicePointAddress = typeof shippingServicePointAddress === 'string' && shippingServicePointAddress.length > 0
      ? shippingServicePointAddress.slice(0, 256)
      : null;

    // Reuse or create Stripe customer for the buyer
    let customerId: string;
    const { data: existingCustomer } = await supabaseAdmin
      .from('stripe_customers')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .single();

    if (existingCustomer?.stripe_customer_id) {
      customerId = existingCustomer.stripe_customer_id;
    } else {
      const customer = await stripe.customers.create({
        email: buyerEmail || user.email,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;
      await supabaseAdmin
        .from('stripe_customers')
        .insert({ user_id: user.id, stripe_customer_id: customerId });
    }

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: '2023-10-16' }
    );

    // Insert the offer row FIRST so we have a stable id to put in metadata.
    const { data: offerRow, error: offerInsertError } = await supabaseAdmin
      .from('listing_offers')
      .insert({
        listing_id: listing.id,
        buyer_id: user.id,
        seller_id: listing.user_id,
        offered_price_sek: priceSEK,
        message: typeof message === 'string' && message.length > 0 ? message.slice(0, 1000) : null,
        amount_item_ore: itemOre,
        amount_platform_fee_ore: platformFeeOre,
        amount_shipping_ore: shippingFeeOre,
        amount_buyer_total_ore: buyerTotalOre,
        amount_seller_payout_ore: sellerPayoutOre,
        currency: 'sek',
        status: 'pending',
        stripe_customer_id: customerId,
        buyer_email: buyerEmail || user.email,
        shipping_carrier: carrier,
        shipping_service_code: serviceCode,
        shipping_product_name: productName,
        shipping_booking_token: bookingToken,
        shipping_booking_token_expires_at: bookingTokenExpiresAt,
        shipping_service_point_token: servicePointToken,
        shipping_service_point_name: servicePointName,
        shipping_service_point_address: servicePointAddress,
      })
      .select('id')
      .single();

    if (offerInsertError || !offerRow) {
      throw new Error(`Failed to create offer: ${offerInsertError?.message ?? 'unknown'}`);
    }

    const metadata: Record<string, string> = {
      source: 'marketplace',
      kind: 'listing_offer',
      offer_id: offerRow.id,
      listing_id: listing.id,
      buyer_id: user.id,
      seller_id: listing.user_id,
      offered_price_sek: String(priceSEK),
      platform_fee_percent: String(PLATFORM_FEE_PERCENT),
    };

    // capture_method=manual: authorise the card but don't capture. If the
    // seller accepts we capture (optionally re-routing through Connect on
    // capture). If declined we cancel. No money moves in the meantime.
    // We deliberately DO NOT set transfer_data/on_behalf_of here because
    // destination charges with manual capture need the Connect account to
    // exist at auth time and get locked in; capturing can still change the
    // transfer amount, but on_behalf_of is immutable. Keeping the auth on
    // the platform and doing a transfer on capture is simpler and mirrors
    // the fallback "held" path for sellers who haven't onboarded yet.
    const params: Stripe.PaymentIntentCreateParams = {
      amount: buyerTotalOre,
      currency: 'sek',
      customer: customerId,
      capture_method: 'manual',
      metadata,
      automatic_payment_methods: { enabled: true },
      payment_method_options: {
        klarna: { preferred_locale: 'sv-SE' },
      },
      // No shipping at create time – the buyer hasn't provided an address
      // yet. `finalize-marketplace-offer` attaches the shipping object and
      // captures the PI once the buyer fills in their address after the
      // seller accepts.
    };

    const paymentIntent = await stripe.paymentIntents.create(params);

    await supabaseAdmin
      .from('listing_offers')
      .update({ stripe_payment_intent_id: paymentIntent.id })
      .eq('id', offerRow.id);

    // Best-effort notification to the seller.
    try {
      const listingTitle = listing.title ?? 'din annons';
      await supabaseAdmin.from('notifications').insert({
        user_id: listing.user_id,
        type: 'marketplace_offer',
        actor_id: user.id,
        message: `Nytt prisförslag på ${listingTitle}: ${priceSEK} kr`,
      });
    } catch (e) {
      console.error('Failed to insert offer notification:', e);
    }

    return new Response(
      JSON.stringify({
        success: true,
        offerId: offerRow.id,
        paymentIntent: paymentIntent.client_secret,
        ephemeralKey: ephemeralKey.secret,
        customer: customerId,
        publishableKey: Deno.env.get('STRIPE_PUBLISHABLE_KEY') ||
          'pk_live_51SZ8AiDGa589KjR0jMkTAI5BfGNf65qPzajTPVHNVYWsdhmgCPNgFoT13BlQkuMOPfBwBYodLhv3wUPSWpfx0Q2x00WI8tmMXu',
        breakdown: {
          itemOre,
          platformFeeOre,
          shippingFeeOre,
          buyerTotalOre,
          sellerPayoutOre,
          currency: 'sek',
          isHeld: false,
        },
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error) {
    console.error('create-marketplace-offer-intent error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});

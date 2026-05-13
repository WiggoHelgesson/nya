/**
 * CREATE MARKETPLACE PAYMENT INTENT
 * =================================
 * Creates a PaymentIntent for a buyer purchasing a community listing
 * (`consignment_submissions` row). Uses destination charges when the
 * seller has completed Stripe Connect onboarding; otherwise the charge
 * is held on the platform and transferred later via
 * `process-pending-seller-payouts` once the seller onboards.
 *
 * Fee model:
 *   item_ore      = priceSEK * 100
 *   platform_fee  = round(item_ore * 0.05) + 750   (5 % + 7.50 kr)
 *   shipping      = chosen Sendify rate (öre) or 4900 fallback
 *   buyer_total   = item_ore + platform_fee + shipping
 *   seller_payout = item_ore                       (seller keeps 100 %)
 *
 * The buyer picks a carrier + service + price up front in
 * `MarketplaceCheckoutView` (rates fetched via
 * `get-marketplace-shipping-rates`). The chosen rate is locked on the
 * `marketplace_orders` row so the price can't drift between intent
 * creation and capture, and the carrier/service identifiers are also
 * placed in PI metadata for safety.
 *
 * Usage:
 * POST /create-marketplace-payment-intent
 * Body: {
 *   listingId: string,
 *   shipping: { name, address, postal, city },
 *   buyerEmail: string,
 *   buyerPhone?: string,             // E.164 e.g. "+46701234567" (Shipmondo receiver_mobile)
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

/** Persist first image + title/brand on the order row (survives listing delete). */
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

const PLATFORM_FEE_PERCENT = 5;
const BUYER_PROTECTION_FLAT_ORE = 750; // 7.50 kr
const SHIPPING_FEE_ORE_FALLBACK = 4900; // 49 kr fallback if no Sendify rate

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
      apiVersion: '2023-10-16',
    });

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing Authorization header');
    }

    // Authenticated client (buyer)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    // Service-role client (listings, profiles, order inserts)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) throw new Error('Unauthorized');

    const {
      listingId,
      shipping,
      buyerEmail,
      buyerPhone,
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
    if (!shipping?.name || !shipping?.address || !shipping?.postal || !shipping?.city) {
      throw new Error('Complete shipping address is required');
    }

    // Fetch listing + resolve seller.
    // We try the new schema first (price_sek column + sold_at) and fall back
    // gracefully if the marketplace_stripe_connect migration has not been
    // applied yet – that way the function keeps working in both states.
    let listing: any = null;
    let listingError: any = null;
    {
      const res = await supabaseAdmin
        .from('consignment_submissions')
        .select('id, user_id, ai_payload, admin_status, price_sek, sold_at, title, user_brand, image_urls')
        .eq('id', listingId)
        .single();
      listing = res.data;
      listingError = res.error;
    }
    if (listingError) {
      // Likely: column "sold_at" does not exist → retry without it
      const res = await supabaseAdmin
        .from('consignment_submissions')
        .select('id, user_id, ai_payload, admin_status, price_sek, title, user_brand, image_urls')
        .eq('id', listingId)
        .single();
      listing = res.data;
      listingError = res.error;
    }
    if (listingError) {
      // Also no price_sek column → final fallback
      const res = await supabaseAdmin
        .from('consignment_submissions')
        .select('id, user_id, ai_payload, admin_status, title, user_brand, image_urls')
        .eq('id', listingId)
        .single();
      listing = res.data;
      listingError = res.error;
    }

    if (listingError || !listing) throw new Error('Listing not found');
    if (listing.admin_status !== 'accepted') throw new Error('Listing is not available for purchase');
    if (listing.sold_at) throw new Error('Listing is already sold');
    if (listing.user_id === user.id) throw new Error('You cannot buy your own listing');

    // Price: prefer the dedicated price_sek column, fall back to ai_payload
    // (for legacy rows created via the old AI-driven flow).
    const priceSEK = Number(
      listing.price_sek ??
        listing.ai_payload?.priceSEK ??
        listing.ai_payload?.price_sek ??
        0
    );
    const buyerPhoneNorm = typeof buyerPhone === 'string' && buyerPhone.trim().length > 0
      ? buyerPhone.trim().slice(0, 32)
      : null;

    if (!priceSEK || priceSEK <= 0) {
      throw new Error('Listing has no price');
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

    // Fetch seller Stripe status
    const { data: sellerProfile } = await supabaseAdmin
      .from('profiles')
      .select('id, stripe_account_id, stripe_charges_enabled')
      .eq('id', listing.user_id)
      .single();

    const sellerHasStripe = Boolean(
      sellerProfile?.stripe_account_id && sellerProfile?.stripe_charges_enabled
    );

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

    // Buyer protection: vi håller alltid pengarna på plattformen tills
    // köparen godkänt eller approval-deadlinen har passerat.
    // `is_held = true` betyder härmed "platform-charge, ej överförd till
    // säljare ännu". Tidigare betydde det "väntar på säljarens Stripe-
    // onboarding" — det fallet täcks fortfarande, men numera är ALLA
    // ordrar held tills release.
    const initialStatus = 'pending';
    const isHeld = true;
    const listingSnap = listingSnapshotFromRow(listing as Record<string, unknown>);

    // Create marketplace order row (pending) so webhook can update it
    const { data: orderRow, error: orderInsertError } = await supabaseAdmin
      .from('marketplace_orders')
      .insert({
        listing_id: listing.id,
        buyer_id: user.id,
        seller_id: listing.user_id,
        amount_item: itemOre,
        amount_platform_fee: platformFeeOre,
        amount_shipping: shippingFeeOre,
        amount_buyer_total: buyerTotalOre,
        amount_seller_payout: sellerPayoutOre,
        currency: 'sek',
        status: initialStatus,
        is_held: isHeld,
        stripe_customer_id: customerId,
        buyer_shipping_name: shipping.name,
        buyer_shipping_address: shipping.address,
        buyer_shipping_postal: shipping.postal,
        buyer_shipping_city: shipping.city,
        buyer_phone: buyerPhoneNorm,
        buyer_email: buyerEmail || user.email,
        shipping_carrier: carrier,
        shipping_service_code: serviceCode,
        shipping_product_name: productName,
        shipping_booking_token: bookingToken,
        shipping_booking_token_expires_at: bookingTokenExpiresAt,
        shipping_service_point_token: servicePointToken,
        shipping_service_point_name: servicePointName,
        shipping_service_point_address: servicePointAddress,
        shipping_status: 'pending',
        listing_title: listingSnap.listing_title,
        listing_brand: listingSnap.listing_brand,
        listing_image_url: listingSnap.listing_image_url,
      })
      .select('id')
      .single();

    if (orderInsertError || !orderRow) {
      throw new Error(`Failed to create order: ${orderInsertError?.message ?? 'unknown'}`);
    }

    const metadata: Record<string, string> = {
      source: 'marketplace',
      order_id: orderRow.id,
      listing_id: listing.id,
      buyer_id: user.id,
      seller_id: listing.user_id,
      platform_fee_percent: String(PLATFORM_FEE_PERCENT),
      is_held: 'true',
    };
    if (carrier) metadata.shipping_carrier = carrier;
    if (serviceCode) metadata.shipping_service_code = serviceCode;
    if (productName) metadata.shipping_product_name = productName;
    if (servicePointToken) metadata.shipping_service_point_token = servicePointToken.slice(0, 200);
    metadata.shipping_amount_ore = String(shippingFeeOre);

    const params: Stripe.PaymentIntentCreateParams = {
      amount: buyerTotalOre,
      currency: 'sek',
      customer: customerId,
      // Stripe skickar automatiskt mail-kvitto till denna adress när
      // PaymentIntent succeedar. Vi sätter den även om customern har
      // mail satt — Stripe använder receipt_email som override.
      receipt_email: buyerEmail || user.email,
      metadata,
      // Let Stripe pick every PM the account has enabled for SEK / SE based on
      // dashboard config. With a hard-coded `payment_method_types: ['card',
      // 'klarna']` Stripe silently drops Klarna whenever `on_behalf_of` points
      // to a Connect account that doesn't have Klarna enabled, and the
      // PaymentSheet collapses to the card form (no picker shown). Using
      // automatic_payment_methods instead lets the sheet render a proper
      // picker with the PMs that are actually eligible for this intent
      // (Card, Klarna, Link). Apple Pay is a wallet on top of `card` and is
      // enabled by the client via `PaymentSheet.Configuration.applePay`.
      // Swish is intentionally not enabled here.
      automatic_payment_methods: { enabled: true },
      payment_method_options: {
        klarna: { preferred_locale: 'sv-SE' },
      },
      shipping: {
        name: shipping.name,
        address: {
          line1: shipping.address,
          postal_code: shipping.postal,
          city: shipping.city,
          country: 'SE',
        },
      },
    };

    // Notera: ingen `transfer_data` / `on_behalf_of` / `application_fee_amount`
    // sätts här längre. All marketplace-betalning är platform-charge — pengar
    // hamnar på plattformens Stripe-saldo och flyttas ut till säljaren via
    // `stripe.transfers.create` först när köparen godkänt (eller 48 h efter
    // delivered om ingen tvist är öppen). Se `release-marketplace-order` /
    // `process-marketplace-deadlines`.
    void sellerHasStripe; // referenced ovan för side-effect logik

    const paymentIntent = await stripe.paymentIntents.create(params);

    await supabaseAdmin
      .from('marketplace_orders')
      .update({ stripe_payment_intent_id: paymentIntent.id })
      .eq('id', orderRow.id);

    return new Response(
      JSON.stringify({
        success: true,
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
          isHeld: !sellerHasStripe,
        },
        orderId: orderRow.id,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error) {
    console.error('create-marketplace-payment-intent error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});

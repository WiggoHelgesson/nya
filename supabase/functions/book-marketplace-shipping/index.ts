/**
 * BOOK MARKETPLACE SHIPPING (Shipmondo)
 * =====================================
 * POST /shipments on Shipmondo with parties + product_code from the order.
 * `shipping_booking_token` holds the Shipmondo product_code chosen at checkout.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import {
  SHIPMONDO_BASE_URL,
  shipmondoHeaders,
  defaultFromAddress,
  parcelWeightGrams,
  buildShipmentCreateBody,
  extractShipmondoShipmentId,
  pollShipmondoShipmentForLabelAndTracking,
  type Party,
} from '../_shared/shipmondoMapping.ts';
import {
  hydrateMarketplaceOrderLabelFromShipmondo,
  persistPolledLabelToMarketplaceOrder,
} from '../_shared/marketplaceLabelHydrate.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const { orderId } = await req.json();
    if (!orderId) throw new Error('orderId is required');

    const { data: order, error: orderErr } = await supabaseAdmin
      .from('marketplace_orders')
      .select('*')
      .eq('id', orderId)
      .single();
    if (orderErr || !order) throw new Error('Order not found');

    const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const authHeader = req.headers.get('Authorization') ?? '';
    const bearerToken = authHeader.replace(/^Bearer\s+/i, '').trim();
    const isServiceRole =
      bearerToken === serviceRole || authHeader === `Bearer ${serviceRole}`;
    if (!isServiceRole) {
      const supabaseUser = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { global: { headers: { Authorization: authHeader } } },
      );
      const {
        data: { user },
        error: authErr,
      } = await supabaseUser.auth.getUser();
      if (authErr || !user) {
        return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        });
      }
      if (user.id !== order.seller_id) {
        return new Response(JSON.stringify({ success: false, error: 'Forbidden' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 403,
        });
      }
    }

    if (order.shipmondo_shipment_id) {
      const rawLabel = order.shipping_label_url;
      const labelMissing =
        rawLabel == null || String(rawLabel).trim() === '';
      if (labelMissing) {
        await hydrateMarketplaceOrderLabelFromShipmondo(supabaseAdmin, {
          id: String(orderId),
          seller_id: String(order.seller_id),
          shipmondo_shipment_id: String(order.shipmondo_shipment_id),
          shipping_label_url: order.shipping_label_url,
          shipping_tracking_number: order.shipping_tracking_number,
          shipping_tracking_url: order.shipping_tracking_url,
          shipping_qr_payload: order.shipping_qr_payload,
        });
      }
      return new Response(
        JSON.stringify({ success: true, alreadyBooked: true, orderId }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
      );
    }

    if (order.shipping_status === 'label_ready') {
      return new Response(
        JSON.stringify({ success: true, alreadyBooked: true, orderId }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
      );
    }

    const { data: listing } = await supabaseAdmin
      .from('consignment_submissions')
      .select('id, package_size, ai_payload, title')
      .eq('id', order.listing_id)
      .single();

    const packageSize: string =
      listing?.package_size ??
      listing?.ai_payload?.packageSize ??
      'M';
    const listingTitle: string = listing?.title ?? 'Marketplace order';

    const { data: pickup } = await supabaseAdmin
      .from('seller_pickup_addresses')
      .select('full_name, phone, street, postal_code, city, country')
      .eq('user_id', order.seller_id)
      .maybeSingle();

    if (!pickup) {
      await markManual(supabaseAdmin, orderId, 'Seller pickup address missing');
      throw new Error('Seller has not provided a pickup address yet');
    }

    const fallback = defaultFromAddress();
    const productCode: string = String(
      order.shipping_booking_token ?? '',
    ).trim();
    if (!productCode || productCode.startsWith('PLACEHOLDER_')) {
      await markManual(supabaseAdmin, orderId, 'Missing or invalid Shipmondo product_code on order');
      throw new Error('No Shipmondo product_code on order');
    }

    const servicePointToken: string | null = order.shipping_service_point_token ?? null;
    const weightG = parcelWeightGrams(packageSize);

    const sender: Party = {
      type: 'sender',
      name: pickup.full_name ?? fallback.name,
      address1: pickup.street ?? fallback.street,
      postal_code: String(pickup.postal_code ?? '').replace(/\s/g, ''),
      city: pickup.city ?? fallback.city,
      country_code: (pickup.country ?? 'SE').slice(0, 2).toUpperCase(),
      phone: pickup.phone ?? fallback.phone,
      email: fallback.email,
    };

    const receiver: Party = {
      type: 'receiver',
      name: order.buyer_shipping_name ?? 'Köpare',
      address1: order.buyer_shipping_address ?? 'Adress',
      postal_code: String(order.buyer_shipping_postal ?? '').replace(/\s/g, ''),
      city: order.buyer_shipping_city ?? '',
      country_code: 'SE',
      email: order.buyer_email ?? 'buyer@upanddown.se',
      mobile: (typeof order.buyer_phone === 'string' && order.buyer_phone.trim().length > 0)
        ? order.buyer_phone.trim()
        : '+46700000000',
    };

    const serviceCodes = Deno.env.get('SHIPMONDO_DEFAULT_SERVICE_CODES') ?? '';

    const shipBody = buildShipmentCreateBody({
      productCode,
      serviceCodes: serviceCodes || undefined,
      parties: [sender, receiver],
      servicePointId: servicePointToken,
      parcelWeightGrams: weightG,
      reference: `UD-${orderId}`,
      automaticSelectServicePoint: !servicePointToken,
    });

    let bookResp: unknown = null;
    try {
      const resp = await fetch(`${SHIPMONDO_BASE_URL}/shipments`, {
        method: 'POST',
        headers: shipmondoHeaders(),
        body: JSON.stringify(shipBody),
      });
      if (!resp.ok) {
        const errText = await resp.text();
        throw new Error(`Shipmondo POST /shipments ${resp.status}: ${errText}`);
      }
      bookResp = await resp.json();
    } catch (e) {
      console.error('Shipmondo booking failed:', (e as Error).message);
      await markManual(supabaseAdmin, orderId, (e as Error).message);
      throw e;
    }

    const shipmondoShipmentId = extractShipmondoShipmentId(bookResp);
    let polled: {
      labelUrl: string | null;
      trackingUrl: string | null;
      trackingNumber: string | null;
      qrPayload: string | null;
    } = {
      labelUrl: null,
      trackingUrl: null,
      trackingNumber: null,
      qrPayload: null,
    };

    if (shipmondoShipmentId) {
      try {
        polled = await pollShipmondoShipmentForLabelAndTracking(
          shipmondoShipmentId,
          bookResp,
        );
      } catch (e) {
        console.warn('Shipmondo poll failed:', (e as Error).message);
      }
    }

    const persisted = await persistPolledLabelToMarketplaceOrder(
      supabaseAdmin,
      String(orderId),
      String(order.seller_id),
      {
        labelUrl: polled.labelUrl,
        trackingUrl: polled.trackingUrl,
        trackingNumber: polled.trackingNumber,
        qrPayload: polled.qrPayload,
      },
      null,
    );

    const trackingNumber = persisted.trackingNumber;
    const trackingUrl = persisted.trackingUrl;
    const effectiveQrPayload = persisted.qrPayload;
    const storagePath = persisted.labelStoragePath;
    const labelUrl = persisted.labelUrlRemote;

    const shipByDeadline = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString();

    await supabaseAdmin
      .from('marketplace_orders')
      .update({
        shipmondo_shipment_id: shipmondoShipmentId || null,
        shipping_status: 'label_ready',
        shipping_booked_at: new Date().toISOString(),
        ship_by_deadline: shipByDeadline,
      })
      .eq('id', orderId);

    let conversationId: string | null = null;
    try {
      const { data } = await supabaseAdmin
        .rpc('find_direct_conversation', {
          p_user1: order.buyer_id,
          p_user2: order.seller_id,
          p_listing: order.listing_id,
        });
      if (data && typeof data === 'string' && data.length > 0) {
        conversationId = data;
      }
    } catch (e) {
      console.warn('find_direct_conversation failed:', (e as Error).message);
    }

    const carrier = order.shipping_carrier ?? null;
    const productName = order.shipping_product_name ?? null;

    if (conversationId) {
      const sellerPayload = {
        kind: 'shipping_label_ready',
        order_id: orderId,
        listing_id: order.listing_id,
        listing_title: listingTitle,
        carrier: carrier,
        service_code: order.shipping_service_code ?? null,
        product_name: productName,
        tracking_number: trackingNumber,
        tracking_url: trackingUrl,
        label_url: storagePath ?? labelUrl ?? null,
        qr_payload: effectiveQrPayload,
        service_point_name: order.shipping_service_point_name ?? null,
        service_point_address: order.shipping_service_point_address ?? null,
        ship_by_deadline: shipByDeadline,
      };
      const buyerPayload = {
        kind: 'shipping_in_transit',
        order_id: orderId,
        listing_id: order.listing_id,
        listing_title: listingTitle,
        carrier: carrier,
        tracking_number: trackingNumber,
        tracking_url: trackingUrl,
      };
      try {
        await supabaseAdmin
          .from('direct_messages')
          .insert([
            {
              conversation_id: conversationId,
              sender_id: order.seller_id,
              message: JSON.stringify(sellerPayload),
              message_type: 'shipping_label_ready',
            },
            {
              conversation_id: conversationId,
              sender_id: order.seller_id,
              message: JSON.stringify(buyerPayload),
              message_type: 'shipping_in_transit',
            },
          ]);
      } catch (e) {
        console.warn('Failed to insert shipping DMs:', (e as Error).message);
      }
    }

    try {
      await supabaseAdmin.from('notifications').insert([
        {
          user_id: order.seller_id,
          type: 'marketplace_shipping_label',
          comment_text:
            'Fraktsedel klar — tryck för att visa. Lämna in paketet i tid.',
        },
        {
          user_id: order.buyer_id,
          type: 'marketplace_shipping_started',
          comment_text: 'Säljaren har fått en fraktsedel — paketet är på väg.',
        },
      ]);
    } catch (e) {
      console.warn('Failed to insert shipping notifications:', (e as Error).message);
    }

    return new Response(
      JSON.stringify({
        success: true,
        orderId,
        shipmondoShipmentId,
        trackingNumber,
        trackingUrl,
        labelStoragePath: storagePath,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
    );
  } catch (error) {
    console.error('book-marketplace-shipping error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
    );
  }
});

async function markManual(
  supabaseAdmin: ReturnType<typeof createClient>,
  orderId: string,
  reason: string,
): Promise<void> {
  try {
    await supabaseAdmin
      .from('marketplace_orders')
      .update({ shipping_status: 'manual' })
      .eq('id', orderId);
    await supabaseAdmin.from('notifications').insert({
      user_id: null,
      type: 'admin_shipping_manual',
      message: `Order ${orderId} kräver manuell fraktsedel: ${reason}`,
    }).catch(() => {});
  } catch (e) {
    console.error('markManual failed:', (e as Error).message);
  }
}

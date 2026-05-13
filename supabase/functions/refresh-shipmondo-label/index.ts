/**
 * REFRESH SHIPMONDO LABEL — seller or service role
 * Polls Shipmondo GET /shipments/{id}, uploads PDF to shipping-labels if found.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { hydrateMarketplaceOrderLabelFromShipmondo } from "../_shared/marketplaceLabelHydrate.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const body = await req.json().catch(() => ({})) as { orderId?: string };
    const orderId = body.orderId?.trim();
    if (!orderId) throw new Error("orderId is required");

    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";
    const bearerToken = authHeader.replace(/^Bearer\s+/i, "").trim();
    const isServiceRole =
      bearerToken === serviceRole || authHeader === `Bearer ${serviceRole}`;

    const { data: order, error: orderErr } = await supabaseAdmin
      .from("marketplace_orders")
      .select(
        "id, seller_id, shipmondo_shipment_id, shipping_label_url, shipping_tracking_number, shipping_tracking_url, shipping_qr_payload",
      )
      .eq("id", orderId)
      .single();
    if (orderErr || !order) throw new Error("Order not found");

    if (!isServiceRole) {
      const supabaseUser = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        { global: { headers: { Authorization: authHeader } } },
      );
      const {
        data: { user },
        error: authErr,
      } = await supabaseUser.auth.getUser();
      if (authErr || !user) {
        return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      if (user.id !== order.seller_id) {
        return new Response(JSON.stringify({ success: false, error: "Forbidden" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    await hydrateMarketplaceOrderLabelFromShipmondo(supabaseAdmin, {
      id: String(order.id),
      seller_id: String(order.seller_id),
      shipmondo_shipment_id: order.shipmondo_shipment_id,
      shipping_label_url: order.shipping_label_url,
      shipping_tracking_number: order.shipping_tracking_number,
      shipping_tracking_url: order.shipping_tracking_url,
      shipping_qr_payload: order.shipping_qr_payload,
    }, {
      pollAttempts: 8,
      pollDelayMs: 1000,
    });

    const { data: fresh } = await supabaseAdmin
      .from("marketplace_orders")
      .select(
        "shipping_label_url, shipping_tracking_number, shipping_tracking_url, shipping_qr_payload",
      )
      .eq("id", orderId)
      .single();

    const labelPath = fresh?.shipping_label_url ?? null;
    const hasLabel = Boolean(labelPath && String(labelPath).trim().length > 0);

    return new Response(
      JSON.stringify({
        success: true,
        hasLabel,
        shipping_label_url: labelPath,
        tracking_number: fresh?.shipping_tracking_number ?? null,
        tracking_url: fresh?.shipping_tracking_url ?? null,
        qr_payload: fresh?.shipping_qr_payload ?? null,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("refresh-shipmondo-label error:", error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

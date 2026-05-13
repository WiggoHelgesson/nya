/**
 * TEST SHIPMONDO LABEL (admin only)
 * =================================
 * POST /shipments mot Shipmondo utan att skriva i DB.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import {
  SHIPMONDO_BASE_URL,
  shipmondoHeaders,
  defaultFromAddress,
  parcelWeightGrams,
  buildShipmentCreateBody,
  buildMarketplaceRatesForAdminTest,
  extractShipmondoShipmentId,
  pollShipmondoShipmentForLabelAndTracking,
  shipmondoCarrierCodeForServicePoints,
  type Party,
} from "../_shared/shipmondoMapping.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const ADMIN_EMAILS = new Set(
  [
    "admin@updown.app",
    "wiggohelgesson@gmail.com",
    "info@wiggio.se",
    "info@bylito.se",
  ].map((e) => e.toLowerCase()),
);

interface RequestBody {
  packageSize?: string;
  productCode?: string;
  toName?: string;
  toStreet?: string;
  toPostal?: string;
  toCity?: string;
  toEmail?: string;
  carrier?: string | null;
}

async function fetchFirstPickup(
  carrierKey: string,
  postal: string,
): Promise<string | null> {
  const code = shipmondoCarrierCodeForServicePoints(carrierKey);
  const params = new URLSearchParams({
    carrier_code: code,
    country_code: "SE",
    zipcode: postal.replace(/\s/g, ""),
  });
  const url = `${SHIPMONDO_BASE_URL}/pickup_points?${params.toString()}`;
  const resp = await fetch(url, { headers: shipmondoHeaders() });
  if (!resp.ok) return null;
  const json = await resp.json();
  const arr = Array.isArray(json)
    ? json
    : Array.isArray((json as { pickup_points?: unknown[] })?.pickup_points)
    ? (json as { pickup_points: unknown[] }).pickup_points
    : [];
  const first = arr[0] as Record<string, unknown> | undefined;
  if (!first) return null;
  const num = String(first.number ?? first.id ?? "");
  return num.length > 0 ? num : null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const u = Deno.env.get("SHIPMONDO_API_USER") ?? "";
    const k = Deno.env.get("SHIPMONDO_API_KEY") ?? "";
    if (!u.trim() || !k.trim()) {
      return new Response(
        JSON.stringify({ error: "SHIPMONDO_API_USER / SHIPMONDO_API_KEY not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await supabaseUser.auth.getUser();
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const email = (user.email ?? "").toLowerCase().trim();
    if (!ADMIN_EMAILS.has(email)) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let body: RequestBody = {};
    try {
      body = (await req.json()) as RequestBody;
    } catch {
      body = {};
    }

    const sizeRaw = (body.packageSize ?? "M").toUpperCase();
    const packageSize = ["XS", "S", "M", "L", "XL"].includes(sizeRaw)
      ? sizeRaw
      : "M";
    const toName = body.toName?.trim() || "Test Köpare";
    const toStreet = body.toStreet?.trim() || "Testgatan 1";
    const toPostal = body.toPostal?.trim() || "41122";
    const toCity = body.toCity?.trim() || "Göteborg";
    const toEmail = body.toEmail?.trim() || "buyer@test.upanddown.se";

    const carrierFilter = (body.carrier ?? "").toLowerCase().trim();

    const rates = await buildMarketplaceRatesForAdminTest(packageSize);
    let chosen = rates[0];
    if (body.productCode?.trim()) {
      const pc = body.productCode.trim();
      chosen = rates.find((r) => r.bookingToken === pc) ?? chosen;
    }
    if (carrierFilter && carrierFilter !== "auto") {
      const filtered = rates.filter((r) => r.carrier === carrierFilter);
      if (filtered.length > 0) chosen = filtered[0];
      else {
        throw new Error(
          `Ingen produkt för bärare «${carrierFilter}». Lämna carrier tomt eller lägg till avtalsprodukter.`,
        );
      }
    }
    if (!chosen) throw new Error("Inga fraktprodukter från Shipmondo /products");

    const fb = defaultFromAddress();
    const sender: Party = {
      type: "sender",
      name: fb.name,
      address1: fb.street,
      postal_code: fb.postal_code.replace(/\s/g, ""),
      city: fb.city,
      country_code: "SE",
      phone: fb.phone,
      email: fb.email,
    };
    const receiver: Party = {
      type: "receiver",
      name: toName,
      address1: toStreet,
      postal_code: toPostal.replace(/\s/g, ""),
      city: toCity,
      country_code: "SE",
      email: toEmail,
      mobile: "+46700000000",
    };

    let servicePointId: string | null = null;
    if (chosen.requiresServicePoint) {
      servicePointId = await fetchFirstPickup(chosen.carrier, toPostal);
      if (!servicePointId) {
        throw new Error(
          `Hittade inget ombud för ${chosen.carrier} nära ${toPostal}`,
        );
      }
    }

    const serviceCodes = Deno.env.get("SHIPMONDO_DEFAULT_SERVICE_CODES") ?? "";
    const shipBody = buildShipmentCreateBody({
      productCode: chosen.bookingToken,
      serviceCodes: serviceCodes || undefined,
      parties: [sender, receiver],
      servicePointId,
      parcelWeightGrams: parcelWeightGrams(packageSize),
      reference: `app-test-${user.id}-${Date.now()}`,
      automaticSelectServicePoint: !servicePointId && chosen.requiresServicePoint,
    });

    const bookResp = await fetch(`${SHIPMONDO_BASE_URL}/shipments`, {
      method: "POST",
      headers: shipmondoHeaders(),
      body: JSON.stringify(shipBody),
    });
    if (!bookResp.ok) {
      const t = await bookResp.text();
      throw new Error(`Shipmondo POST /shipments ${bookResp.status}: ${t}`);
    }
    const bookJson = await bookResp.json();

    const shipmondoShipmentId = extractShipmondoShipmentId(bookJson);
    let labelUrl: string | null = null;
    let trackingUrl: string | null = null;
    let trackingNumber: string | null = null;
    if (shipmondoShipmentId) {
      const polled = await pollShipmondoShipmentForLabelAndTracking(
        shipmondoShipmentId,
        bookJson,
      );
      labelUrl = polled.labelUrl;
      trackingUrl = polled.trackingUrl;
      trackingNumber = polled.trackingNumber;
    }

    return new Response(
      JSON.stringify({
        success: true,
        shipmondo_shipment_id: shipmondoShipmentId,
        carrier: chosen.carrier,
        product_name: chosen.productName,
        product_code: chosen.bookingToken,
        price_ore: chosen.priceOre,
        tracking_number: trackingNumber,
        tracking_url: trackingUrl,
        label_url: labelUrl,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ success: false, error: msg }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

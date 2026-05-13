/**
 * Download Shipmondo label PDF → shipping-labels bucket + update marketplace_orders.
 */

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { pollShipmondoShipmentForLabelAndTracking } from "./shipmondoMapping.ts";

const LABEL_BUCKET = "shipping-labels";

export interface MarketplaceOrderLabelRow {
  id: string;
  seller_id: string;
  shipmondo_shipment_id: string | null;
  shipping_label_url?: string | null;
  shipping_tracking_number?: string | null;
  shipping_tracking_url?: string | null;
  shipping_qr_payload?: string | null;
}

export interface PolledLabelPayload {
  labelUrl: string | null;
  trackingUrl: string | null;
  trackingNumber: string | null;
  qrPayload: string | null;
}

export interface HydrateLabelResult {
  hasLabel: boolean;
  labelStoragePath: string | null;
  labelUrlRemote: string | null;
  trackingNumber: string | null;
  trackingUrl: string | null;
  qrPayload: string | null;
}

/** Apply poll result: upload PDF if possible, update DB columns. */
export async function persistPolledLabelToMarketplaceOrder(
  supabaseAdmin: SupabaseClient,
  orderId: string,
  sellerId: string,
  polled: PolledLabelPayload,
  existingQr?: string | null,
): Promise<HydrateLabelResult> {
  const effectiveQr =
    (polled.qrPayload && polled.qrPayload.trim().length > 0
      ? polled.qrPayload.trim()
      : null) ??
    (polled.trackingNumber && polled.trackingNumber.trim().length > 0
      ? polled.trackingNumber.trim()
      : null) ??
    (existingQr && existingQr.trim().length > 0 ? existingQr.trim() : null);

  let storagePath: string | null = null;
  if (polled.labelUrl) {
    try {
      const pdfResp = await fetch(polled.labelUrl);
      if (pdfResp.ok) {
        const pdfBytes = new Uint8Array(await pdfResp.arrayBuffer());
        const path = `${sellerId}/${orderId}.pdf`;
        const { error: uploadErr } = await supabaseAdmin.storage
          .from(LABEL_BUCKET)
          .upload(path, pdfBytes, {
            contentType: "application/pdf",
            upsert: true,
          });
        if (!uploadErr) storagePath = path;
      }
    } catch (e) {
      console.warn(
        "persistPolledLabel: PDF download/upload failed:",
        (e as Error).message,
      );
    }
  }

  const updateRow: Record<string, unknown> = {};
  if (storagePath) updateRow.shipping_label_url = storagePath;
  else if (polled.labelUrl) updateRow.shipping_label_url = polled.labelUrl;
  if (polled.trackingNumber) {
    updateRow.shipping_tracking_number = polled.trackingNumber;
  }
  if (polled.trackingUrl) updateRow.shipping_tracking_url = polled.trackingUrl;
  if (effectiveQr) updateRow.shipping_qr_payload = effectiveQr;

  if (Object.keys(updateRow).length > 0) {
    await supabaseAdmin
      .from("marketplace_orders")
      .update(updateRow)
      .eq("id", orderId);
  }

  return {
    hasLabel: Boolean(storagePath || polled.labelUrl),
    labelStoragePath: storagePath,
    labelUrlRemote: polled.labelUrl,
    trackingNumber: polled.trackingNumber,
    trackingUrl: polled.trackingUrl,
    qrPayload: effectiveQr,
  };
}

/**
 * Poll Shipmondo GET /shipments/{id} until label (or give up), then persist.
 */
export async function hydrateMarketplaceOrderLabelFromShipmondo(
  supabaseAdmin: SupabaseClient,
  order: MarketplaceOrderLabelRow,
  opts?: {
    initialBookResponse?: unknown;
    pollAttempts?: number;
    pollDelayMs?: number;
  },
): Promise<HydrateLabelResult> {
  const smId = order.shipmondo_shipment_id?.trim();
  if (!smId) {
    return {
      hasLabel: false,
      labelStoragePath: null,
      labelUrlRemote: null,
      trackingNumber: null,
      trackingUrl: null,
      qrPayload: null,
    };
  }

  const existing = order.shipping_label_url?.trim() ?? "";
  if (existing && !existing.startsWith("http")) {
    return {
      hasLabel: true,
      labelStoragePath: existing,
      labelUrlRemote: null,
      trackingNumber: order.shipping_tracking_number ?? null,
      trackingUrl: order.shipping_tracking_url ?? null,
      qrPayload: order.shipping_qr_payload ?? null,
    };
  }
  if (existing.startsWith("http")) {
    return {
      hasLabel: true,
      labelStoragePath: null,
      labelUrlRemote: existing,
      trackingNumber: order.shipping_tracking_number ?? null,
      trackingUrl: order.shipping_tracking_url ?? null,
      qrPayload: order.shipping_qr_payload ?? null,
    };
  }

  const polled = await pollShipmondoShipmentForLabelAndTracking(
    smId,
    opts?.initialBookResponse ?? null,
    {
      attempts: opts?.pollAttempts ?? 6,
      delayMs: opts?.pollDelayMs ?? 1000,
    },
  );

  return await persistPolledLabelToMarketplaceOrder(
    supabaseAdmin,
    order.id,
    order.seller_id,
    {
      labelUrl: polled.labelUrl,
      trackingUrl: polled.trackingUrl,
      trackingNumber: polled.trackingNumber,
      qrPayload: polled.qrPayload,
    },
    order.shipping_qr_payload,
  );
}

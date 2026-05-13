/**
 * Shared Sendify helpers (package-size mapping, defaults, types).
 *
 * Used by `get-marketplace-shipping-rates`, `list-marketplace-service-points`,
 * `book-marketplace-shipping`, `create-marketplace-payment-intent`,
 * `create-marketplace-offer-intent` and `poll-sendify-tracking`.
 *
 * Sendify API reference (production): https://app.sendify.se/external/v1
 * Auth header: x-api-key: <SENDIFY_API_KEY>
 *
 * Flow we use:
 *   1. POST /shipments              → returns shipment_id
 *   2. POST /shipments/rates        (include_service_point_rates: true)
 *   3. POST /locations/servicepoints (when chosen rate requires service point)
 *   4. POST /shipments/book         (booking_token [+ delivery_service_point_token])
 *   5. GET  /shipments/{id}/tracking
 */

export interface SendifyPackage {
  description: string;
  type: "PACKAGE";
  quantity: number;
  depth_cm: number;
  width_cm: number;
  height_cm: number;
  weight_kg: number;
  stackable: boolean;
}

export interface SendifyAddressInput {
  name: string;
  phone?: string;
  email?: string;
  street: string;
  postal_code: string;
  city: string;
  country: string; // ISO 3166-1 alpha-2 (e.g. "SE")
}

/**
 * Maps the `package_size` we collect from the seller (XS/S/M/L/XL) to a
 * representative parcel for Sendify. We use a slight over-estimate so the
 * rate quote is high enough to cover the actual booking even if the seller
 * mis-judges the size.
 */
export function packageForSize(
  size: string | null | undefined,
  description = "Sportartikel"
): SendifyPackage {
  const code = (size ?? "M").toUpperCase();
  const dim = (() => {
    switch (code) {
      case "XS": return { weight_kg: 1.0,  depth_cm: 30, width_cm: 20, height_cm: 5  };
      case "S":  return { weight_kg: 2.0,  depth_cm: 35, width_cm: 25, height_cm: 10 };
      case "M":  return { weight_kg: 5.0,  depth_cm: 45, width_cm: 35, height_cm: 20 };
      case "L":  return { weight_kg: 10.0, depth_cm: 60, width_cm: 40, height_cm: 40 };
      case "XL": return { weight_kg: 20.0, depth_cm: 80, width_cm: 50, height_cm: 50 };
      default:   return { weight_kg: 5.0,  depth_cm: 45, width_cm: 35, height_cm: 20 };
    }
  })();
  return {
    description,
    type: "PACKAGE",
    quantity: 1,
    stackable: true,
    ...dim,
  };
}

/**
 * Default platform from-address used when we need to quote rates before
 * the seller has saved their pickup address. Override via env
 * `SENDIFY_DEFAULT_FROM_*`. Falls back to Stockholm 11122.
 */
export function defaultFromAddress(): {
  name: string;
  street: string;
  postal_code: string;
  city: string;
  country: string;
  phone: string;
  email: string;
} {
  return {
    name: Deno.env.get("SENDIFY_DEFAULT_FROM_NAME") ?? "Up&Down",
    street: Deno.env.get("SENDIFY_DEFAULT_FROM_STREET") ?? "Storgatan 1",
    postal_code: Deno.env.get("SENDIFY_DEFAULT_FROM_POSTAL") ?? "11122",
    city: Deno.env.get("SENDIFY_DEFAULT_FROM_CITY") ?? "Stockholm",
    country: "SE",
    phone: Deno.env.get("SENDIFY_DEFAULT_FROM_PHONE") ?? "+46700000000",
    email: Deno.env.get("SENDIFY_DEFAULT_FROM_EMAIL") ?? "support@upanddown.se",
  };
}

/** Backwards-compat alias for the postal-only helper used by older callers. */
export function defaultFromPostal(): { postal_code: string; city: string; country: string } {
  const a = defaultFromAddress();
  return { postal_code: a.postal_code, city: a.city, country: a.country };
}

/**
 * Sendify environment + auth.
 * Production base URL is `https://app.sendify.se/external/v1`.
 * Override via `SENDIFY_BASE_URL` (e.g. for the dev sandbox at
 * `https://app.dev.sendify.se/external/v1`).
 */
export const SENDIFY_BASE_URL =
  Deno.env.get("SENDIFY_BASE_URL") ?? "https://app.sendify.se/external/v1";

export function sendifyHeaders(): HeadersInit {
  const key = Deno.env.get("SENDIFY_API_KEY") ?? "";
  return {
    "x-api-key": key,
    "Content-Type": "application/json",
    "Accept": "application/json",
  };
}

/**
 * Convert a Sendify rate price (kr, may be a number or string) to öre.
 */
export function priceToOre(price: number | string | null | undefined): number {
  if (price == null) return 0;
  const n = typeof price === "string" ? parseFloat(price) : price;
  if (!isFinite(n)) return 0;
  return Math.round(n * 100);
}

/**
 * Returns next-business-day pickup time in ISO 8601 with Stockholm offset
 * (e.g. "2026-04-30T10:00:00+02:00"). Sendify requires this when fetching
 * rates so it knows which carriers are bookable.
 */
export function nextPickupTimeISO(): string {
  const now = new Date();
  const next = new Date(now.getTime());
  next.setUTCHours(8, 0, 0, 0); // 10:00 CEST / 09:00 CET
  // Move to next day if already past 06:00 UTC today (i.e. 08:00 CEST).
  if (next.getTime() <= now.getTime()) {
    next.setUTCDate(next.getUTCDate() + 1);
  }
  // Skip weekends.
  while (next.getUTCDay() === 0 || next.getUTCDay() === 6) {
    next.setUTCDate(next.getUTCDate() + 1);
  }
  // Stockholm offset switches between +01:00 (winter) and +02:00 (DST).
  // Approximate: late March – late October ≈ +02:00. Good enough for
  // Sendify's pickup-time hint.
  const month = next.getUTCMonth(); // 0–11
  const dst = month >= 2 && month <= 9; // Mar–Oct
  const offset = dst ? "+02:00" : "+01:00";
  // Format YYYY-MM-DDTHH:MM:SS<offset>
  const y = next.getUTCFullYear();
  const m = String(next.getUTCMonth() + 1).padStart(2, "0");
  const d = String(next.getUTCDate()).padStart(2, "0");
  const hh = dst ? "10" : "09";
  return `${y}-${m}-${d}T${hh}:00:00${offset}`;
}

/**
 * Maps Sendify `carrier_name` (e.g. "DHL Freight", "PostNord", "Budbee",
 * "Instabox", "Bring") to a stable short key we use across DB rows and
 * iOS UI. Unknown values are slugified.
 */
export function mapCarrierKey(carrierName: string | null | undefined): string {
  const raw = (carrierName ?? "").toLowerCase().trim();
  if (!raw) return "unknown";
  if (raw.includes("postnord")) return "postnord";
  if (raw.includes("dhl")) return "dhl";
  if (raw.includes("budbee")) return "budbee";
  if (raw.includes("instabox") || raw.includes("instabee")) return "instabox";
  if (raw.includes("bring")) return "bring";
  if (raw.includes("ups")) return "ups";
  if (raw.includes("dsv")) return "dsv";
  if (raw.includes("schenker")) return "schenker";
  if (raw.includes("fedex")) return "fedex";
  return raw.replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "") || "unknown";
}

/** Slugifies a Sendify product name into a stable service code. */
export function slugProduct(productName: string | null | undefined): string {
  const raw = (productName ?? "").toLowerCase().trim();
  if (!raw) return "default";
  return raw.replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "") || "default";
}

/**
 * Heuristic ETA text from a Sendify product name. Sendify doesn't return
 * delivery time on the rate object, so we map known products. Unknown →
 * "1–3 dagar" (typical SE domestic).
 */
export function etaTextFor(productName: string | null | undefined): string {
  const p = (productName ?? "").toLowerCase();
  if (p.includes("instabox")) return "Samma dag";
  if (p.includes("budbee box")) return "1–2 dagar";
  if (p.includes("budbee home") || p.includes("budbee hem")) return "1–2 dagar";
  if (p.includes("home delivery") || p.includes("hemleverans")) return "1–2 dagar";
  if (p.includes("mypack")) return "1–3 dagar";
  if (p.includes("service point")) return "1–3 dagar";
  if (p.includes("bring")) return "2–4 dagar";
  return "1–3 dagar";
}

/**
 * Service codes for which PostNord/DHL supports QR-only drop-off (no
 * printer needed). These match Sendify's `product` identifiers — keep this
 * in sync with their docs. We use slugified product names.
 */
export const QR_SUPPORTED_SERVICE_CODES = new Set<string>([
  "postnord_mypack_collect",
  "postnord_service_point_return",
  "dhl_service_point",
  "schenker_paket_ombud",
  "db_schenker_paket_ombud",
]);

/** Hemleverans / hem till dörren — ska inte visas i checkout. */
export function isExcludedHomeDeliveryProduct(productName: string | null | undefined): boolean {
  const p = (productName ?? "").toLowerCase();
  if (!p) return false;
  if (p.includes("hemleverans")) return true;
  if (p.includes("home delivery")) return true;
  if (p.includes("budbee home")) return true;
  if (p.includes(" till hem")) return true;
  return false;
}

/**
 * Endast DB Schenker (ombud) + DHL Service Point / ombud — ingen hemleverans, ingen PostNord.
 */
export function isAllowedMarketplaceRate(
  carrierKey: string,
  productName: string | null | undefined
): boolean {
  const c = (carrierKey ?? "").toLowerCase();
  const p = (productName ?? "").toLowerCase();
  if (isExcludedHomeDeliveryProduct(p)) return false;
  if (c === "dhl") {
    return (
      p.includes("service point") ||
      p.includes("servicepoint") ||
      p.includes("ombud")
    );
  }
  if (c === "schenker") {
    return (
      p.includes("ombud") ||
      p.includes("service point") ||
      p.includes("servicepoint") ||
      p.includes("paketombud")
    );
  }
  return false;
}

/** Shallow merge — använd bara top-level-flaggor som Sendify stödjer (t.ex. inlämning utan upphämtning). */
export function mergeSendifyShipmentCreateExtras(
  body: Record<string, unknown>
): Record<string, unknown> {
  const raw = Deno.env.get("SENDIFY_SHIPMENTS_CREATE_EXTRAS_JSON");
  if (!raw?.trim()) return body;
  try {
    const extra = JSON.parse(raw) as Record<string, unknown>;
    return { ...body, ...extra };
  } catch {
    return body;
  }
}

/** POST /shipments/rates — standard + valfria fält från Sendify-support (t.ex. avvikande pickup-beteende). */
export function sendifyRatesRequestPayload(shipmentId: string): Record<string, unknown> {
  const base: Record<string, unknown> = {
    shipment_id: shipmentId,
    requested_pickup_time: nextPickupTimeISO(),
    include_service_point_rates: true,
  };
  const raw = Deno.env.get("SENDIFY_SHIPMENTS_RATES_EXTRAS_JSON");
  if (!raw?.trim()) return base;
  try {
    return { ...base, ...JSON.parse(raw) };
  } catch {
    return base;
  }
}

/** POST /shipments/book — valfritt objekt från Sendify (t.ex. inlämning på terminal / utan upphämtning). */
export function mergeSendifyBookExtras(bookBody: Record<string, unknown>): Record<string, unknown> {
  const raw = Deno.env.get("SENDIFY_SHIPMENTS_BOOK_EXTRAS_JSON");
  if (!raw?.trim()) return bookBody;
  try {
    const extra = JSON.parse(raw) as Record<string, unknown>;
    return { ...bookBody, ...extra };
  } catch {
    return bookBody;
  }
}

function firstHttpUrlString(...candidates: unknown[]): string | null {
  for (const c of candidates) {
    if (typeof c !== "string") continue;
    const t = c.trim();
    if (t.length === 0) continue;
    if (/^https?:\/\//i.test(t)) return t;
  }
  return null;
}

/**
 * Plockar ut PDF-/etikett-URL från Sendify-svar (GET /shipments/{id}, POST /book, m.fl.).
 * Fältnamn varierar mellan produkter/versioner; vi söker brett + i nested `shipment`/`data`.
 */
export function extractSendifyLabelUrl(root: unknown): string | null {
  if (root == null || typeof root !== "object") return null;
  const p = root as Record<string, unknown>;

  const direct = firstHttpUrlString(
    p.label_url,
    p.label_pdf_url,
    p.print_label_url,
    p.pdf_url,
    p.document_url,
    p.shipping_label_url,
    p.shipping_label_pdf_url,
    p.label_link,
  );
  if (direct) return direct;

  const lbl = p.label;
  if (lbl && typeof lbl === "object") {
    const L = lbl as Record<string, unknown>;
    const u = firstHttpUrlString(
      L.url,
      L.pdf_url,
      L.download_url,
      L.file_url,
      L.href,
      L.link,
      typeof L.pdf === "string" ? L.pdf : undefined,
    );
    if (u) return u;
  }

  const docs = p.documents;
  if (Array.isArray(docs)) {
    for (const doc of docs) {
      if (!doc || typeof doc !== "object") continue;
      const d = doc as Record<string, unknown>;
      const u = firstHttpUrlString(d.url, d.pdf_url, d.download_url, d.label_url, d.href, d.file_url);
      if (u) return u;
      const nested = extractSendifyLabelUrl(doc);
      if (nested) return nested;
    }
  } else if (docs && typeof docs === "object") {
    const u = extractSendifyLabelUrl(docs);
    if (u) return u;
  }

  const labels = p.labels;
  if (Array.isArray(labels)) {
    for (const item of labels) {
      const u = extractSendifyLabelUrl(item);
      if (u) return u;
    }
  }

  const printouts = p.printouts ?? p.label_printouts;
  if (Array.isArray(printouts)) {
    for (const item of printouts) {
      const u = extractSendifyLabelUrl(item);
      if (u) return u;
    }
  }

  for (const k of ["shipment", "data", "payload", "result"]) {
    const child = p[k];
    if (child && typeof child === "object") {
      const u = extractSendifyLabelUrl(child);
      if (u) return u;
    }
  }

  return null;
}

export function extractSendifyTrackingUrl(root: unknown): string | null {
  if (root == null || typeof root !== "object") return null;
  const p = root as Record<string, unknown>;
  const u = firstHttpUrlString(p.tracking_url, p.main_tracking_url, p.tracking_link);
  if (u) return u;
  const t = p.tracking;
  if (t && typeof t === "object") {
    const tr = t as Record<string, unknown>;
    const u2 = firstHttpUrlString(tr.url, tr.tracking_url, tr.href, tr.link);
    if (u2) return u2;
  }
  for (const k of ["shipment", "data"]) {
    const child = p[k];
    if (child && typeof child === "object") {
      const u3 = extractSendifyTrackingUrl(child);
      if (u3) return u3;
    }
  }
  return null;
}

/**
 * Efter /shipments/book kan etikett-PDF:en saknas i första GET-svaret (genereras asynkront).
 * Poll:a GET /shipments/{id} några gånger innan vi ger upp.
 */
export async function pollSendifyShipmentForLabelAndTracking(
  shipmentId: string,
  bookResponse: unknown,
  options?: { attempts?: number; delayMs?: number }
): Promise<{
  labelUrl: string | null;
  trackingUrl: string | null;
  /** Sista lyckade GET /shipments/{id}-JSON (för QR m.m.). */
  lastDetail: unknown | null;
}> {
  const attempts = Math.min(8, Math.max(1, options?.attempts ?? 6));
  const delayMs = Math.min(3000, Math.max(200, options?.delayMs ?? 700));

  let labelUrl = extractSendifyLabelUrl(bookResponse);
  let trackingUrl = extractSendifyTrackingUrl(bookResponse);
  let lastDetail: unknown | null = null;

  for (let i = 0; i < attempts; i++) {
    if (i > 0) {
      if (labelUrl) break;
      await new Promise((r) => setTimeout(r, delayMs));
    }
    const resp = await fetch(
      `${SENDIFY_BASE_URL}/shipments/${encodeURIComponent(shipmentId)}`,
      { method: "GET", headers: sendifyHeaders() }
    );
    if (!resp.ok) continue;
    const det = await resp.json();
    lastDetail = det;
    if (!labelUrl) labelUrl = extractSendifyLabelUrl(det);
    if (!trackingUrl) trackingUrl = extractSendifyTrackingUrl(det);
  }

  return { labelUrl, trackingUrl, lastDetail };
}

export function isQrSupported(serviceCode: string | null | undefined): boolean {
  if (!serviceCode) return false;
  return QR_SUPPORTED_SERVICE_CODES.has(serviceCode.toLowerCase());
}

/**
 * Backwards-compat alias for older callers that still import the old name.
 * Returns dimensions matching the legacy ParcelDimensions shape.
 */
export function parcelForPackageSize(size: string | null | undefined) {
  const p = packageForSize(size);
  return {
    weight_kg: p.weight_kg,
    length_cm: p.depth_cm,
    width_cm: p.width_cm,
    height_cm: p.height_cm,
  };
}

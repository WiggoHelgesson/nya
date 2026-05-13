/**
 * Shared Shipmondo API v3 helpers.
 * Docs: https://shipmondo.dev/docs
 *
 * Auth: Basic (api_user:api_key) — secrets SHIPMONDO_API_USER + SHIPMONDO_API_KEY
 */

/** Production default per Shipmondo docs (`app`, not `api` — the latter redirects to docs). */
export const SHIPMONDO_BASE_URL =
  Deno.env.get("SHIPMONDO_BASE_URL") ?? "https://app.shipmondo.com/api/public/v3";

export function shipmondoHeaders(): HeadersInit {
  const user = Deno.env.get("SHIPMONDO_API_USER") ?? "";
  const key = Deno.env.get("SHIPMONDO_API_KEY") ?? "";
  const token = btoa(`${user}:${key}`);
  return {
    Authorization: `Basic ${token}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  };
}

/** Parcel weight in grams from listing package_size (XS/S/M/L/XL). */
export function parcelWeightGrams(size: string | null | undefined): number {
  const code = (size ?? "M").toUpperCase();
  switch (code) {
    case "XS":
      return 1000;
    case "S":
      return 2000;
    case "M":
      return 5000;
    case "L":
      return 10000;
    case "XL":
      return 20000;
    default:
      return 5000;
  }
}

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
    name: Deno.env.get("SHIPMONDO_DEFAULT_FROM_NAME") ??
      Deno.env.get("SENDIFY_DEFAULT_FROM_NAME") ??
      "Up&Down",
    street: Deno.env.get("SHIPMONDO_DEFAULT_FROM_STREET") ??
      Deno.env.get("SENDIFY_DEFAULT_FROM_STREET") ??
      "Storgatan 1",
    postal_code: Deno.env.get("SHIPMONDO_DEFAULT_FROM_POSTAL") ??
      Deno.env.get("SENDIFY_DEFAULT_FROM_POSTAL") ??
      "11122",
    city: Deno.env.get("SHIPMONDO_DEFAULT_FROM_CITY") ??
      Deno.env.get("SENDIFY_DEFAULT_FROM_CITY") ??
      "Stockholm",
    country: "SE",
    phone: Deno.env.get("SHIPMONDO_DEFAULT_FROM_PHONE") ??
      Deno.env.get("SENDIFY_DEFAULT_FROM_PHONE") ??
      "+46700000000",
    email: Deno.env.get("SHIPMONDO_DEFAULT_FROM_EMAIL") ??
      Deno.env.get("SENDIFY_DEFAULT_FROM_EMAIL") ??
      "support@upanddown.se",
  };
}

export function mapCarrierKey(carrierName: string | null | undefined): string {
  const raw = (carrierName ?? "").toLowerCase().trim();
  if (!raw) return "unknown";
  if (raw.includes("postnord")) return "postnord";
  if (raw.includes("dhl")) return "dhl";
  if (raw.includes("budbee")) return "budbee";
  if (raw.includes("instabox") || raw.includes("instabee")) return "instabox";
  if (raw.includes("bring")) return "bring";
  if (raw.includes("gls")) return "gls";
  if (raw.includes("schenker")) return "schenker";
  return raw.replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "") || "unknown";
}

export function slugProduct(productName: string | null | undefined): string {
  const raw = (productName ?? "").toLowerCase().trim();
  if (!raw) return "default";
  return raw.replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "") || "default";
}

export function etaTextFor(productName: string | null | undefined): string {
  const p = (productName ?? "").toLowerCase();
  if (p.includes("instabox")) return "Samma dag";
  if (p.includes("budbee")) return "1–2 dagar";
  if (p.includes("mypack")) return "1–3 dagar";
  if (p.includes("service point") || p.includes("ombud")) return "1–3 dagar";
  if (p.includes("hemleverans") || p.includes("home delivery")) return "2–5 dagar";
  return "1–3 dagar";
}

function isExcludedHomeDeliveryProduct(productName: string | null | undefined): boolean {
  const p = (productName ?? "").toLowerCase();
  if (!p) return false;
  if (p.includes("hemleverans")) return true;
  if (p.includes("home delivery")) return true;
  if (p.includes("budbee home")) return true;
  if (p.includes(" till hem")) return true;
  return false;
}

/**
 * Ombuds-/service-point-produkter först; DHL Freight SE hemleverans (t.ex. DHLFSE_HP)
 * tillåts som fallback när kontot saknar ombudsprodukter på /products.
 */
export function isAllowedMarketplaceRate(
  carrierKey: string,
  productName: string | null | undefined,
): boolean {
  const c = (carrierKey ?? "").toLowerCase();
  const p = (productName ?? "").toLowerCase();
  if (
    c === "dhl" &&
    (p.includes("hemleverans") || p.includes("home delivery"))
  ) {
    return true;
  }
  if (isExcludedHomeDeliveryProduct(productName)) return false;
  if (c === "postnord") {
    return (
      p.includes("mypack") ||
      p.includes("collect") ||
      p.includes("ombud") ||
      p.includes("service point") ||
      p.includes("paket")
    );
  }
  if (c === "dhl") {
    return p.includes("service point") || p.includes("servicepoint") || p.includes("ombud");
  }
  if (c === "budbee") {
    return p.includes("box") || p.includes("ombud");
  }
  if (c === "instabox") return true;
  if (c === "schenker") {
    return p.includes("ombud") || p.includes("service point") || p.includes("paketombud");
  }
  return false;
}

export const QR_SUPPORTED_SERVICE_CODES = new Set<string>([
  "postnord_mypack_collect",
  "postnord_service_point_return",
  "dhl_service_point",
  "schenker_paket_ombud",
  "db_schenker_paket_ombud",
  "budbee_box",
]);

export function isQrSupported(serviceCode: string | null | undefined): boolean {
  if (!serviceCode) return false;
  return QR_SUPPORTED_SERVICE_CODES.has(serviceCode.toLowerCase());
}

function parsePriceMap(): Record<string, number> {
  const raw = Deno.env.get("SHIPMONDO_PRODUCT_PRICES_ORE_JSON");
  if (!raw?.trim()) return {};
  try {
    const o = JSON.parse(raw) as Record<string, number>;
    return o && typeof o === "object" ? o : {};
  } catch {
    return {};
  }
}

const DEFAULT_PRICE_ORE = 6900;

async function fetchProductsSE(): Promise<unknown[]> {
  const url = `${SHIPMONDO_BASE_URL}/products?country_code=SE`;
  const r = await fetch(url, { headers: shipmondoHeaders() });
  if (!r.ok) {
    console.warn("Shipmondo GET /products", r.status, await r.text());
    return [];
  }
  const j = await r.json();
  if (Array.isArray(j)) return j;
  if (Array.isArray((j as Record<string, unknown>)?.products)) {
    return (j as { products: unknown[] }).products;
  }
  if (Array.isArray((j as Record<string, unknown>)?.data)) {
    return (j as { data: unknown[] }).data;
  }
  return [];
}

export interface MarketplaceRateRow {
  carrier: string;
  carrierName: string;
  productName: string;
  serviceCode: string;
  name: string;
  priceOre: number;
  etaText: string;
  qrSupported: boolean;
  requiresServicePoint: boolean;
  bookingToken: string;
  shipmentId: string;
}

/**
 * Build checkout rate rows from Shipmondo /products for SE domestic.
 * `bookingToken` carries the Shipmondo `product_code` (no Sendify-style token).
 */
export async function buildMarketplaceRatesFromProducts(
  packageSize: string,
): Promise<MarketplaceRateRow[]> {
  const weightG = parcelWeightGrams(packageSize);
  const priceMap = parsePriceMap();
  const rawList = await fetchProductsSE();
  const rows: MarketplaceRateRow[] = [];

  for (const raw of rawList) {
    if (!raw || typeof raw !== "object") continue;
    const p = raw as Record<string, unknown>;
    const code = String(p.code ?? "").trim();
    if (!code) continue;
    const name = String(p.name ?? code);
    const carrierObj = p.carrier as Record<string, unknown> | undefined;
    const carrierName = String(carrierObj?.name ?? carrierObj?.code ?? "unknown");
    const carrierKey = mapCarrierKey(carrierName);
    if (!isAllowedMarketplaceRate(carrierKey, name)) continue;

    const intervals = p.weight_intervals as
      | Array<{ from_weight?: number; to_weight?: number }>
      | undefined;
    if (intervals && intervals.length > 0) {
      const ok = intervals.some((wi) => {
        const from = Number(wi.from_weight ?? 0);
        const to = Number(wi.to_weight ?? 999999999);
        return weightG >= from && weightG <= to;
      });
      if (!ok) continue;
    }

    const spFlag = Boolean(p.service_point_product);
    const nl = name.toLowerCase();
    const requiresServicePoint =
      spFlag ||
      nl.includes("ombud") ||
      nl.includes("service point") ||
      nl.includes("mypack collect") ||
      nl.includes("instabox") ||
      nl.includes("budbee box");

    const serviceCode = `${carrierKey}_${slugProduct(name)}`;
    const priceOre = Math.round(priceMap[code] ?? priceMap[name] ?? DEFAULT_PRICE_ORE);

    rows.push({
      carrier: carrierKey,
      carrierName,
      productName: name,
      serviceCode,
      name,
      priceOre,
      etaText: etaTextFor(name),
      qrSupported: isQrSupported(serviceCode),
      requiresServicePoint,
      bookingToken: code,
      shipmentId: "",
    });
  }

  const deduped: MarketplaceRateRow[] = [];
  for (const r of rows.sort((a, b) => a.priceOre - b.priceOre)) {
    const idx = deduped.findIndex((x) => x.serviceCode === r.serviceCode);
    if (idx === -1) deduped.push(r);
    else if (r.priceOre < deduped[idx].priceOre) deduped[idx] = r;
  }

  if (deduped.length > 0) return deduped;

  const schenkerCode = Deno.env.get("SHIPMONDO_FALLBACK_PRODUCT_SCHENKER")?.trim();
  const dhlCode = Deno.env.get("SHIPMONDO_FALLBACK_PRODUCT_DHL")?.trim();
  const manual: MarketplaceRateRow[] = [];
  if (schenkerCode) {
    manual.push({
      carrier: "schenker",
      carrierName: "DB Schenker",
      productName: "Paket Ombud (konfigurerad)",
      serviceCode: "schenker_paket_ombud",
      name: "DB Schenker Paket Ombud",
      priceOre: 5900,
      etaText: "1–3 dagar",
      qrSupported: true,
      requiresServicePoint: true,
      bookingToken: schenkerCode,
      shipmentId: "",
    });
  }
  if (dhlCode) {
    manual.push({
      carrier: "dhl",
      carrierName: "DHL",
      productName: "Service Point (konfigurerad)",
      serviceCode: "dhl_service_point",
      name: "DHL Service Point",
      priceOre: 6500,
      etaText: "1–3 dagar",
      qrSupported: true,
      requiresServicePoint: true,
      bookingToken: dhlCode,
      shipmentId: "",
    });
  }
  if (manual.length > 0) return manual;

  return [];
}

/**
 * Vanliga checkout-rader, eller om avtalet saknar ombudsprodukter som matchar filtret:
 * första SE-produkt från API (för admin/CLI-smoketest av nycklar och POST /shipments).
 */
export async function buildMarketplaceRatesForAdminTest(
  packageSize: string,
): Promise<MarketplaceRateRow[]> {
  const normal = await buildMarketplaceRatesFromProducts(packageSize);
  if (normal.length > 0) return normal;

  const url = `${SHIPMONDO_BASE_URL}/products?country_code=SE`;
  const resp = await fetch(url, { headers: shipmondoHeaders() });
  if (!resp.ok) {
    throw new Error(`Shipmondo GET /products ${resp.status}: ${await resp.text()}`);
  }
  const json = await resp.json();
  const arr = Array.isArray(json)
    ? json
    : Array.isArray((json as { products?: unknown[] })?.products)
    ? (json as { products: unknown[] }).products
    : [];
  const p = arr[0] as Record<string, unknown> | undefined;
  if (!p || !p.code) {
    throw new Error("Inga SE-produkter på Shipmondo-kontot.");
  }
  const carrierObj = p.carrier as Record<string, unknown> | undefined;
  const carrierName = String(carrierObj?.name ?? "unknown");
  const carrierKey = mapCarrierKey(carrierName);
  const code = String(p.code);
  const name = String(p.name ?? code);
  const requiresServicePoint = Boolean(p.service_point_required) ||
    Boolean(p.service_point_product);

  return [{
    carrier: carrierKey,
    carrierName,
    productName: `${name} (smoketest: saknar ombudsprodukter i avtalet)`,
    serviceCode: `${carrierKey}_admin_smoke`,
    name,
    priceOre: DEFAULT_PRICE_ORE,
    etaText: "—",
    qrSupported: false,
    requiresServicePoint,
    bookingToken: code,
    shipmentId: "",
  }];
}

export function mergeShipmondoShipmentExtras(
  body: Record<string, unknown>,
): Record<string, unknown> {
  const raw = Deno.env.get("SHIPMONDO_SHIPMENTS_CREATE_EXTRAS_JSON");
  if (!raw?.trim()) return body;
  try {
    return { ...body, ...JSON.parse(raw) as Record<string, unknown> };
  } catch {
    return body;
  }
}

export interface Party {
  type: "sender" | "receiver";
  name: string;
  address1: string;
  postal_code: string;
  city: string;
  country_code: string;
  email?: string;
  phone?: string;
  mobile?: string;
}

export function buildShipmentCreateBody(args: {
  productCode: string;
  serviceCodes?: string;
  parties: Party[];
  servicePointId?: string | null;
  parcelWeightGrams: number;
  reference: string;
  automaticSelectServicePoint?: boolean;
}): Record<string, unknown> {
  const len = Number(Deno.env.get("SHIPMONDO_DEFAULT_PARCEL_LENGTH_CM") ?? "30");
  const wid = Number(Deno.env.get("SHIPMONDO_DEFAULT_PARCEL_WIDTH_CM") ?? "20");
  const hgt = Number(Deno.env.get("SHIPMONDO_DEFAULT_PARCEL_HEIGHT_CM") ?? "15");
  // DHL m.fl. kräver förpackningstyp enligt produkt (t.ex. PK, 701) — se Shipmondo products `required_parcel_fields`.
  const pkgType = Deno.env.get("SHIPMONDO_DEFAULT_PACKAGE_TYPE")?.trim() ?? "PK";
  const parcel: Record<string, unknown> = {
    weight: args.parcelWeightGrams,
    length: len,
    width: wid,
    height: hgt,
    package_type: pkgType,
  };

  const parties = args.parties.map((raw) => {
    const p = { ...(raw as unknown as Record<string, unknown>) };
    const phone = p.phone ?? p.mobile;
    if (phone) p.phone = phone;
    delete p.mobile;
    return p;
  });

  const printRequested =
    (Deno.env.get("SHIPMONDO_REQUEST_LABEL_PRINT") ?? "true") === "true";
  const labelFormat =
    Deno.env.get("SHIPMONDO_LABEL_FORMAT")?.trim() ?? "10x19_pdf";

  const body: Record<string, unknown> = {
    own_agreement: (Deno.env.get("SHIPMONDO_OWN_AGREEMENT") ?? "true") === "true",
    product_code: args.productCode,
    parties,
    parcels: [parcel],
    reference: args.reference,
    print: printRequested,
    request_label: true,
    label_format: labelFormat,
  };
  if (args.serviceCodes?.trim()) body.service_codes = args.serviceCodes.trim();
  if (args.servicePointId && String(args.servicePointId).trim().length > 0) {
    body.service_point_id = String(args.servicePointId).trim();
  } else if (args.automaticSelectServicePoint) {
    body.automatic_select_service_point = true;
  }
  return mergeShipmondoShipmentExtras(body);
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

export function extractShipmondoLabelUrl(root: unknown): string | null {
  if (root == null || typeof root !== "object") return null;
  const p = root as Record<string, unknown>;
  const direct = firstHttpUrlString(
    p.label_url,
    p.label_pdf_url,
    p.pdf_url,
    p.label_file_url,
    p.shipping_label_url,
  );
  if (direct) return direct;
  const label = p.label;
  if (label && typeof label === "object") {
    const L = label as Record<string, unknown>;
    const u = firstHttpUrlString(L.url, L.pdf_url, L.download_url);
    if (u) return u;
  }
  for (const k of ["shipment", "data"]) {
    const c = p[k];
    if (c && typeof c === "object") {
      const u = extractShipmondoLabelUrl(c);
      if (u) return u;
    }
  }
  const fromParcels = extractShipmondoLabelUrlFromParcels(p.parcels);
  if (fromParcels) return fromParcels;
  return null;
}

/** Label URL sometimes lives on `parcels[].label_url` / pdf fields. */
export function extractShipmondoLabelUrlFromParcels(parcels: unknown): string | null {
  if (!Array.isArray(parcels)) return null;
  for (const pr of parcels) {
    if (!pr || typeof pr !== "object") continue;
    const o = pr as Record<string, unknown>;
    const u = firstHttpUrlString(
      o.label_url,
      o.label_pdf_url,
      o.pdf_url,
      o.shipping_label_url,
    );
    if (u) return u;
  }
  return null;
}

export function extractShipmondoTrackingUrl(root: unknown): string | null {
  if (root == null || typeof root !== "object") return null;
  const p = root as Record<string, unknown>;
  const u = firstHttpUrlString(p.tracking_url, p.tracking_link, p.public_tracking_url);
  if (u) return u;
  const t = p.tracking;
  if (t && typeof t === "object") {
    const tr = t as Record<string, unknown>;
    const u2 = firstHttpUrlString(tr.url, tr.tracking_url);
    if (u2) return u2;
  }
  return null;
}

/** Numeric or string id from Shipmondo shipment resource. */
export function extractShipmondoShipmentId(root: unknown): string {
  if (root == null || typeof root !== "object") return "";
  const p = root as Record<string, unknown>;
  const id = p.id ?? (p.shipment as Record<string, unknown> | undefined)?.id;
  if (id == null) return "";
  return String(id);
}

export async function pollShipmondoShipmentForLabelAndTracking(
  shipmentId: string,
  bookResponse: unknown,
  options?: { attempts?: number; delayMs?: number },
): Promise<{
  labelUrl: string | null;
  trackingUrl: string | null;
  trackingNumber: string | null;
  qrPayload: string | null;
  lastDetail: unknown | null;
}> {
  const attempts = Math.min(20, Math.max(1, options?.attempts ?? 12));
  const delayMs = Math.min(4000, Math.max(200, options?.delayMs ?? 1000));

  let labelUrl = extractShipmondoLabelUrl(bookResponse);
  let trackingUrl = extractShipmondoTrackingUrl(bookResponse);
  let lastDetail: unknown | null = null;
  let trackingNumber: string | null = null;
  let qrPayload: string | null = null;

  const scanTracking = (det: unknown) => {
    if (!det || typeof det !== "object") return;
    const o = det as Record<string, unknown>;
    const tn = o.tracking_number ?? o.barcode ?? o.main_tracking_number;
    if (typeof tn === "string" && tn.trim()) trackingNumber = tn.trim();
    const qr = o.qr_code ?? o.qr_payload ?? o.label_qr;
    if (typeof qr === "string" && qr.trim()) qrPayload = qr.trim();
    const parcels = o.parcels;
    if (Array.isArray(parcels)) {
      for (const pr of parcels) {
        if (!pr || typeof pr !== "object") continue;
        const p = pr as Record<string, unknown>;
        const bc = p.barcode ?? p.tracking_number;
        if (typeof bc === "string" && bc.trim() && !trackingNumber) {
          trackingNumber = bc.trim();
        }
      }
    }
  };
  scanTracking(bookResponse);
  if (!labelUrl && bookResponse && typeof bookResponse === "object") {
    labelUrl = extractShipmondoLabelUrlFromParcels(
      (bookResponse as Record<string, unknown>).parcels,
    );
  }

  for (let i = 0; i < attempts; i++) {
    if (i > 0) {
      if (labelUrl && trackingNumber) break;
      await new Promise((r) => setTimeout(r, delayMs));
    }
    const url = `${SHIPMONDO_BASE_URL}/shipments/${encodeURIComponent(shipmentId)}`;
    const resp = await fetch(url, { method: "GET", headers: shipmondoHeaders() });
    if (!resp.ok) continue;
    const det = await resp.json();
    lastDetail = det;
    scanTracking(det);
    if (!labelUrl) labelUrl = extractShipmondoLabelUrl(det);
    if (!labelUrl && det && typeof det === "object") {
      labelUrl = extractShipmondoLabelUrlFromParcels(
        (det as Record<string, unknown>).parcels,
      );
    }
    if (!trackingUrl) trackingUrl = extractShipmondoTrackingUrl(det);
  }

  return { labelUrl, trackingUrl, trackingNumber, qrPayload, lastDetail };
}

/** Map Shipmondo shipment status string → marketplace_orders.shipping_status */
export function mapShipmondoShippingStatus(s: string | null | undefined): string | null {
  const x = (s ?? "").toLowerCase().trim();
  if (!x) return null;
  if (
    x.includes("created") ||
    x.includes("pending") ||
    x.includes("booked") ||
    x.includes("label")
  ) {
    return "label_ready";
  }
  if (x.includes("picked") || x.includes("collected") || x.includes("submitted")) {
    return "picked_up";
  }
  if (
    x.includes("arrived_to_servicepoint") ||
    x.includes("available_for_delivery") ||
    (x.includes("arrived") && x.includes("service"))
  ) {
    return "arrived_servicepoint";
  }
  if (x.includes("transit") || x.includes("transport") || x.includes("delivery")) {
    return "in_transit";
  }
  if (x.includes("delivered") || x.includes("completed") || x.includes("done")) {
    return "delivered";
  }
  if (x.includes("return")) return "returned";
  if (x.includes("fail") || x.includes("error") || x.includes("cancel")) return "failed";
  return null;
}

/** iOS list-marketplace-service-points: map internal carrier key → Shipmondo carrier_code query param */
export function shipmondoCarrierCodeForServicePoints(carrierKey: string): string {
  const c = (carrierKey ?? "").toLowerCase().trim();
  const envKey = `SHIPMONDO_PICKUP_CARRIER_${c.toUpperCase()}`;
  const fromEnv = Deno.env.get(envKey);
  if (fromEnv?.trim()) return fromEnv.trim();
  const defaults: Record<string, string> = {
    // Shipmondo pickup_points uses carrier `code` from GET /carriers (e.g. SE domestic DHL → dhl_freight_se).
    // PostNord pickup_points uses `pdk` on many SE agreements (see GET /carriers / trial pickup_points).
    postnord: "pdk",
    dhl: "dhl_freight_se",
    budbee: "budbee",
    instabox: "instabox",
    schenker: "db_schenker",
    bring: "bring",
    gls: "gls",
  };
  return defaults[c] ?? c;
}

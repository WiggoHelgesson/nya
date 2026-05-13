// =============================================================================
// INTE Supabase SQL Editor — det här är TypeScript. Klistra IN i SQL Editor.
//
// Enklast på din Mac: sätt nyckel i sendify_test.local (se sendify_test.local.example)
// och kör:  bash supabase/scripts/run_test_sendify_label.sh
// (skriptet installerar Deno automatiskt första gången om det saknas)
// =============================================================================

/**
 * Verifierar att Sendify skapar fraktsedel (samma kedja som edge-funktionen
 * `book-marketplace-shipping`).
 *
 * Kräver:
 *   SENDIFY_API_KEY
 *
 * Valfritt:
 *   SENDIFY_BASE_URL   (default https://app.sendify.se/external/v1)
 *                      Sandbox: https://app.dev.sendify.se/external/v1
 *
 * Kör från projektroten (IntelliJ/Terminal, inte Supabase → SQL):
 *   deno run --allow-env --allow-net --allow-read --allow-write --allow-run \
 *     supabase/scripts/test_sendify_label.ts
 *
 * Flaggor:
 *   --size XS|S|M|L|XL          Paketstorlek (default M)
 *   --to-name "Namn"          Mottagare
 *   --to-street "Gatan 1"
 *   --to-postal 41122
 *   --to-city Göteborg
 *   --to-email buyer@test.se
 *   --from-name / --from-street / --from-postal / --from-city / --from-phone
 *   --carrier dhl|schenker    Välj billigaste inom denna bärare
 *   --keep-pdf                Spara PDF men kör inte `open` (CI / headless)
 */

import {
  SENDIFY_BASE_URL,
  defaultFromAddress,
  isAllowedMarketplaceRate,
  mapCarrierKey,
  mergeSendifyBookExtras,
  mergeSendifyShipmentCreateExtras,
  packageForSize,
  sendifyHeaders,
  sendifyRatesRequestPayload,
  slugProduct,
  pollSendifyShipmentForLabelAndTracking,
} from "../functions/_shared/sendifyMapping.ts";

interface Flags {
  size: string;
  toName: string;
  toStreet: string;
  toPostal: string;
  toCity: string;
  toEmail: string;
  fromName: string | null;
  fromStreet: string | null;
  fromPostal: string | null;
  fromCity: string | null;
  fromPhone: string | null;
  fromEmail: string | null;
  carrier: string | null;
  keepPdf: boolean;
}

function parseFlags(argv: string[]): Flags {
  const d: Flags = {
    size: "M",
    toName: "Test Köpare",
    toStreet: "Testgatan 1",
    toPostal: "41122",
    toCity: "Göteborg",
    toEmail: "buyer@test.upanddown.se",
    fromName: null,
    fromStreet: null,
    fromPostal: null,
    fromCity: null,
    fromPhone: null,
    fromEmail: null,
    carrier: null,
    keepPdf: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      const v = argv[++i];
      if (!v) throw new Error(`Flagga ${a} kräver ett värde`);
      return v;
    };
    switch (a) {
      case "--size":
        d.size = next();
        break;
      case "--to-name":
        d.toName = next();
        break;
      case "--to-street":
        d.toStreet = next();
        break;
      case "--to-postal":
        d.toPostal = next();
        break;
      case "--to-city":
        d.toCity = next();
        break;
      case "--to-email":
        d.toEmail = next();
        break;
      case "--from-name":
        d.fromName = next();
        break;
      case "--from-street":
        d.fromStreet = next();
        break;
      case "--from-postal":
        d.fromPostal = next();
        break;
      case "--from-city":
        d.fromCity = next();
        break;
      case "--from-phone":
        d.fromPhone = next();
        break;
      case "--from-email":
        d.fromEmail = next();
        break;
      case "--carrier":
        d.carrier = next().toLowerCase();
        break;
      case "--keep-pdf":
        d.keepPdf = true;
        break;
      default:
        if (a.startsWith("-")) {
          throw new Error(`Okänd flagga: ${a}`);
        }
    }
  }
  return d;
}

function buildFrom(flags: Flags) {
  const fb = defaultFromAddress();
  return {
    name: flags.fromName ?? fb.name,
    address: {
      address_line_1: flags.fromStreet ?? fb.street,
      country_code: "SE",
      postal_code: flags.fromPostal ?? fb.postal_code,
      city: flags.fromCity ?? fb.city,
    },
    contact: {
      name: flags.fromName ?? fb.name,
      phone: flags.fromPhone ?? fb.phone,
      email: flags.fromEmail ?? fb.email,
    },
  };
}

async function fetchServicePointToken(
  buyerPostal: string,
  buyerCity: string,
  wantedCarrier: string
): Promise<string | null> {
  const body = {
    address_line: `${buyerPostal} ${buyerCity}`,
    postal_code: buyerPostal,
    city: buyerCity,
    country_code: "SE",
  };
  const resp = await fetch(`${SENDIFY_BASE_URL}/locations/servicepoints`, {
    method: "POST",
    headers: sendifyHeaders(),
    body: JSON.stringify(body),
  });
  if (!resp.ok) {
    const t = await resp.text();
    throw new Error(`Sendify /locations/servicepoints ${resp.status}: ${t}`);
  }
  const json = await resp.json();
  const locations: any[] = Array.isArray(json?.locations)
    ? json.locations
    : Array.isArray(json?.service_points)
    ? json.service_points
    : [];

  const wanted = wantedCarrier.toLowerCase();
  for (const l of locations) {
    const carrierKey = mapCarrierKey(l.carrier ?? l.carrier_name);
    if (carrierKey !== wanted) continue;
    const token = String(l.service_point_token ?? l.token ?? "");
    if (token.length > 0) return token;
  }
  return null;
}

async function main() {
  const apiKey = Deno.env.get("SENDIFY_API_KEY") ?? "";
  if (!apiKey.trim()) {
    console.error("Saknar SENDIFY_API_KEY i miljön.");
    Deno.exit(1);
  }

  const flags = parseFlags(Deno.args);

  const pkg = packageForSize(flags.size, "Sendify testpaket");
  const from = buildFrom(flags);

  const createBody = mergeSendifyShipmentCreateExtras({
    reference_id: `cli-test-${Date.now()}`,
    enable_bookable_validation: true,
    from,
    to: {
      name: flags.toName,
      address: {
        address_line_1: flags.toStreet,
        country_code: "SE",
        postal_code: flags.toPostal,
        city: flags.toCity,
      },
      contact: {
        name: flags.toName,
        phone: "+46700000000",
        email: flags.toEmail,
      },
      is_private_individual: true,
    },
    packages: [pkg],
    system: "UpAndDown",
  });

  console.log("POST /shipments …");
  const createResp = await fetch(`${SENDIFY_BASE_URL}/shipments`, {
    method: "POST",
    headers: sendifyHeaders(),
    body: JSON.stringify(createBody),
  });
  if (!createResp.ok) {
    const t = await createResp.text();
    throw new Error(`Sendify /shipments ${createResp.status}: ${t}`);
  }
  const createJson = await createResp.json();
  const shipmentIdDraft: string =
    createJson?.id ?? createJson?.shipment_id ?? "";
  if (!shipmentIdDraft) throw new Error("Inget shipment-id från Sendify");

  console.log("POST /shipments/rates …");
  const ratesResp = await fetch(`${SENDIFY_BASE_URL}/shipments/rates`, {
    method: "POST",
    headers: sendifyHeaders(),
    body: JSON.stringify(sendifyRatesRequestPayload(shipmentIdDraft)),
  });
  if (!ratesResp.ok) {
    const t = await ratesResp.text();
    throw new Error(`Sendify /shipments/rates ${ratesResp.status}: ${t}`);
  }
  const ratesJson = await ratesResp.json();
  const allRates: any[] = Array.isArray(ratesJson?.rates) ? ratesJson.rates : [];

  let rates = allRates.filter((r) => {
    const c = mapCarrierKey(r.carrier_name ?? r.carrier);
    const pn = String(r.product_name ?? r.service_name ?? r.name ?? "");
    return isAllowedMarketplaceRate(c, pn);
  });

  if (flags.carrier) {
    rates = rates.filter(
      (r) => mapCarrierKey(r.carrier_name ?? r.carrier) === flags.carrier
    );
  }

  rates.sort((a, b) => Number(a.price ?? 0) - Number(b.price ?? 0));
  const chosen = rates[0];
  if (!chosen) {
    throw new Error(
      "Inga tillåtna fraktalternativ (DHL service point / DB Schenker ombud). " +
        "Kolla API-svaret eller prova annan --from-postal / --to-postal."
    );
  }

  const bookingToken: string = chosen.booking_token ?? "";
  if (!bookingToken) throw new Error("Saknar booking_token på vald rate");

  const carrierKey = mapCarrierKey(chosen.carrier_name ?? chosen.carrier);
  const productName = String(
    chosen.product_name ?? chosen.service_name ?? chosen.name ?? ""
  );

  const requiresServicePoint = Boolean(
    chosen.require_delivery_service_point ??
      chosen.requires_service_point ??
      chosen.delivery_to_service_point
  );

  let deliveryServicePointToken: string | null = null;
  if (requiresServicePoint) {
    console.log(
      `Rate kräver ombud (${carrierKey}). POST /locations/servicepoints …`
    );
    deliveryServicePointToken = await fetchServicePointToken(
      flags.toPostal,
      flags.toCity,
      carrierKey
    );
    if (!deliveryServicePointToken) {
      throw new Error(
        `Hittade inget ombud för ${carrierKey} nära ${flags.toPostal} ${flags.toCity}`
      );
    }
  }

  const bookBody = mergeSendifyBookExtras({
    booking_token: bookingToken,
    ...(deliveryServicePointToken
      ? { delivery_service_point_token: deliveryServicePointToken }
      : {}),
  });

  console.log("POST /shipments/book …");
  const bookResp = await fetch(`${SENDIFY_BASE_URL}/shipments/book`, {
    method: "POST",
    headers: sendifyHeaders(),
    body: JSON.stringify(bookBody),
  });
  if (!bookResp.ok) {
    const t = await bookResp.text();
    throw new Error(`Sendify /shipments/book ${bookResp.status}: ${t}`);
  }
  const bookJson = await bookResp.json();

  const sendifyShipmentId: string =
    bookJson?.shipment_id ?? bookJson?.id ?? "";
  const trackingNumber: string | null =
    bookJson?.main_tracking_id ?? bookJson?.tracking_number ?? null;

  let labelUrl: string | null = null;
  let trackingUrl: string | null = null;
  if (sendifyShipmentId) {
    console.log("GET /shipments/{id} (ev. flera försök tills label finns) …");
    const polled = await pollSendifyShipmentForLabelAndTracking(
      sendifyShipmentId,
      bookJson
    );
    labelUrl = polled.labelUrl;
    trackingUrl = polled.trackingUrl;
  }

  const out = {
    sendify_shipment_id: sendifyShipmentId,
    carrier: carrierKey,
    product_name: productName,
    product_slug: slugProduct(productName),
    price_sek: chosen.price ?? chosen.price_incl_vat,
    tracking_number: trackingNumber,
    tracking_url: trackingUrl,
    label_url: labelUrl,
    requires_service_point: requiresServicePoint,
    service_point_token_used: deliveryServicePointToken ? "[satt]" : null,
  };

  console.log("\nResultat:\n", JSON.stringify(out, null, 2));

  if (labelUrl) {
    const pdfResp = await fetch(labelUrl);
    if (!pdfResp.ok) {
      throw new Error(`Kunde inte ladda label-PDF: HTTP ${pdfResp.status}`);
    }
    const bytes = new Uint8Array(await pdfResp.arrayBuffer());
    await Deno.mkdir("tmp", { recursive: true });
    const path = `tmp/sendify-label-${sendifyShipmentId}.pdf`;
    await Deno.writeFile(path, bytes);
    console.log(`\nPDF sparad: ${path} (${bytes.length} bytes)`);

    if (!flags.keepPdf && Deno.build.os === "darwin") {
      const run = new Deno.Command("open", { args: [path] });
      await run.output();
    } else if (!flags.keepPdf) {
      console.log("(Öppna PDF manuellt — `open` finns bara på macOS)");
    }
  } else {
    console.warn("\nIngen label_url i svaret — kolla Sendify-dashboard eller API-respons.");
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  Deno.exit(1);
});

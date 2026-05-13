// =============================================================================
// CLI: samma Shipmondo-kedja som edge-funktionen `test-shipmondo-label`.
//
// Kräver:
//   SHIPMONDO_API_USER
//   SHIPMONDO_API_KEY
//
// Valfritt: SHIPMONDO_BASE_URL (sandbox i shipmondoMapping)
//
// Kör från projektroten:
//   deno run --allow-env --allow-net --allow-read --allow-write --allow-run \
//     supabase/scripts/test_shipmondo_label.ts
//
// Eller: bash supabase/scripts/run_test_shipmondo_label.sh
// =============================================================================

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
} from "../functions/_shared/shipmondoMapping.ts";

interface Flags {
  size: string;
  toName: string;
  toStreet: string;
  toPostal: string;
  toCity: string;
  toEmail: string;
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

async function main() {
  const u = Deno.env.get("SHIPMONDO_API_USER") ?? "";
  const k = Deno.env.get("SHIPMONDO_API_KEY") ?? "";
  if (!u.trim() || !k.trim()) {
    console.error("Saknar SHIPMONDO_API_USER och/eller SHIPMONDO_API_KEY.");
    Deno.exit(1);
  }

  const flags = parseFlags(Deno.args);
  const sizeRaw = flags.size.toUpperCase();
  const packageSize = ["XS", "S", "M", "L", "XL"].includes(sizeRaw)
    ? sizeRaw
    : "M";

  const rates = await buildMarketplaceRatesForAdminTest(packageSize);
  let chosen = rates[0];
  const carrierFilter = (flags.carrier ?? "").toLowerCase().trim();
  if (carrierFilter && carrierFilter !== "auto") {
    const filtered = rates.filter((r) => r.carrier === carrierFilter);
    if (filtered.length > 0) chosen = filtered[0];
    else {
      throw new Error(
        `Ingen produkt för bärare «${carrierFilter}». Kör utan --carrier eller lägg till avtalsprodukter i Shipmondo.`,
      );
    }
  }
  if (!chosen) {
    throw new Error("Inga fraktprodukter från Shipmondo /products");
  }

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
    name: flags.toName,
    address1: flags.toStreet,
    postal_code: flags.toPostal.replace(/\s/g, ""),
    city: flags.toCity,
    country_code: "SE",
    email: flags.toEmail,
    mobile: "+46700000000",
  };

  let servicePointId: string | null = null;
  if (chosen.requiresServicePoint) {
    servicePointId = await fetchFirstPickup(chosen.carrier, flags.toPostal);
    if (!servicePointId) {
      throw new Error(
        `Hittade inget ombud för ${chosen.carrier} nära ${flags.toPostal}`,
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
    reference: `cli-test-${Date.now()}`,
    automaticSelectServicePoint: !servicePointId && chosen.requiresServicePoint,
  });

  console.log(`POST ${SHIPMONDO_BASE_URL}/shipments …`);
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
    console.log("GET /shipments/{id} (poll tills label/spårning finns) …");
    const polled = await pollShipmondoShipmentForLabelAndTracking(
      shipmondoShipmentId,
      bookJson,
    );
    labelUrl = polled.labelUrl;
    trackingUrl = polled.trackingUrl;
    trackingNumber = polled.trackingNumber;
  }

  const out = {
    shipmondo_shipment_id: shipmondoShipmentId,
    carrier: chosen.carrier,
    product_name: chosen.productName,
    product_code: chosen.bookingToken,
    price_ore: chosen.priceOre,
    tracking_number: trackingNumber,
    tracking_url: trackingUrl,
    label_url: labelUrl,
  };

  console.log("\nResultat:\n", JSON.stringify(out, null, 2));

  if (labelUrl) {
    const pdfResp = await fetch(labelUrl);
    if (!pdfResp.ok) {
      throw new Error(`Kunde inte ladda label-PDF: HTTP ${pdfResp.status}`);
    }
    const bytes = new Uint8Array(await pdfResp.arrayBuffer());
    await Deno.mkdir("tmp", { recursive: true });
    const path = `tmp/shipmondo-label-${shipmondoShipmentId || "unknown"}.pdf`;
    await Deno.writeFile(path, bytes);
    console.log(`\nPDF sparad: ${path} (${bytes.length} bytes)`);

    if (!flags.keepPdf && Deno.build.os === "darwin") {
      const run = new Deno.Command("open", { args: [path] });
      await run.output();
    } else if (!flags.keepPdf) {
      console.log("(Öppna PDF manuellt — `open` finns bara på macOS)");
    }
  } else {
    console.warn(
      "\nIngen label_url i svaret — kolla Shipmondo eller kör polling igen.",
    );
  }
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  Deno.exit(1);
});

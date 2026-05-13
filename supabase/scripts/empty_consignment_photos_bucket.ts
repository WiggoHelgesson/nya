// INTE för Supabase SQL Editor — kör i terminal med Deno (se nedan).
/**
 * Tömmer bucket `consignment-photos` via Storage API (inte SQL).
 *
 * Kräver:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *
 * Kör i projektroten:
 *   deno run --allow-env --allow-net supabase/scripts/empty_consignment_photos_bucket.ts
 *
 * (Supabase tillåter inte DELETE mot storage.objects i SQL Editor — se
 *  supabase/sql/reset_community_listings.sql)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const BUCKET = "consignment-photos";
const BATCH = 1000;

const url = Deno.env.get("SUPABASE_URL")?.trim();
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();

if (!url || !key) {
  console.error(
    "Sätt SUPABASE_URL och SUPABASE_SERVICE_ROLE_KEY i miljön.",
  );
  Deno.exit(1);
}

const supabase = createClient(url, key, {
  auth: { persistSession: false, autoRefreshToken: false },
});

/** Lista alla objektfiler rekursivt (mappar har metadata == null i list-svaret). */
async function collectFilePaths(prefix: string): Promise<string[]> {
  const { data, error } = await supabase.storage.from(BUCKET).list(prefix, {
    limit: 1000,
    offset: 0,
  });
  if (error) throw error;

  const out: string[] = [];
  for (const item of data ?? []) {
    const rel = prefix ? `${prefix}/${item.name}` : item.name;
    if (item.metadata != null) {
      out.push(rel);
    } else {
      out.push(...await collectFilePaths(rel));
    }
  }
  return out;
}

const paths = await collectFilePaths("");
console.log(`Hittade ${paths.length} fil(er) i ${BUCKET}.`);

for (let i = 0; i < paths.length; i += BATCH) {
  const batch = paths.slice(i, i + BATCH);
  const { error } = await supabase.storage.from(BUCKET).remove(batch);
  if (error) throw error;
  console.log(`Raderade ${batch.length} (batch ${Math.floor(i / BATCH) + 1}).`);
}

console.log("Klart.");

// =============================================================================
// Prefyller Supabase bucket `exercise-gifs` med RapidAPI ExerciseDB-GIF:er
// genom att anropa Edge Function `ensure-exercise-gif` for varje id i den
// bundlade exercises.json. Idempotent: redan uppladdade objekt rapporteras
// som `alreadyExists` och hoppas over.
//
// Kraver miljovariabler:
//   SUPABASE_URL              t.ex. https://xebatkodviqgkpsbyuiv.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY service-role-nyckel (anvands som Bearer)
//
// Valfritt:
//   EXERCISES_JSON_PATH       default: riktiga/riktiga/Resources/exercises.json
//   THROTTLE_MS               default: 200 (paus mellan anrop, mildrar 429)
//   START_INDEX               default: 0  (for att fortsatta efter avbrott)
//   LIMIT                     default: ingen (testa pa subset)
//
// Kor fran projektroten:
//   bash supabase/scripts/run_prepopulate_exercise_gifs.sh
// =============================================================================

interface BundledExercise {
  id: string;
  name?: string;
}

interface FunctionResponse {
  success: boolean;
  alreadyExists?: boolean;
  uploaded?: boolean;
  url?: string;
  size?: number;
  error?: string;
  status?: number;
}

function envOrThrow(key: string): string {
  const v = Deno.env.get(key);
  if (!v || v.trim() === '') {
    throw new Error(`Missing required env: ${key}`);
  }
  return v.trim();
}

function envOptional(key: string, fallback: string): string {
  const v = Deno.env.get(key);
  return v && v.trim() !== '' ? v.trim() : fallback;
}

async function main(): Promise<void> {
  const supabaseUrl = envOrThrow('SUPABASE_URL').replace(/\/$/, '');
  const serviceRoleKey = envOrThrow('SUPABASE_SERVICE_ROLE_KEY');
  const exercisesPath = envOptional(
    'EXERCISES_JSON_PATH',
    'riktiga/riktiga/Resources/exercises.json',
  );
  const throttleMs = parseInt(envOptional('THROTTLE_MS', '200'), 10);
  const startIndex = parseInt(envOptional('START_INDEX', '0'), 10);
  const limitStr = Deno.env.get('LIMIT');
  const limit = limitStr ? parseInt(limitStr, 10) : undefined;

  console.log(`Reading exercises from: ${exercisesPath}`);
  const raw = await Deno.readTextFile(exercisesPath);
  const all: BundledExercise[] = JSON.parse(raw);
  console.log(`Loaded ${all.length} exercises.`);

  const slice = all.slice(startIndex, limit ? startIndex + limit : undefined);
  console.log(
    `Processing ${slice.length} entries (startIndex=${startIndex}, throttleMs=${throttleMs})`,
  );

  const endpoint = `${supabaseUrl}/functions/v1/ensure-exercise-gif`;
  let uploaded = 0;
  let cached = 0;
  let failed = 0;
  const failures: { id: string; error: string }[] = [];

  for (let i = 0; i < slice.length; i++) {
    const e = slice[i];
    const id = (e.id ?? '').trim();
    if (!id) continue;

    try {
      const resp = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${serviceRoleKey}`,
          apikey: serviceRoleKey,
        },
        body: JSON.stringify({ exerciseId: id }),
      });

      const payload = (await resp.json().catch(() => ({}))) as FunctionResponse;

      if (resp.ok && payload.success) {
        if (payload.alreadyExists) {
          cached++;
          if ((i + 1) % 25 === 0) {
            console.log(
              `[${i + 1}/${slice.length}] ${id} cached (uploaded=${uploaded} cached=${cached} failed=${failed})`,
            );
          }
        } else {
          uploaded++;
          console.log(
            `[${i + 1}/${slice.length}] ${id} UPLOADED size=${payload.size ?? '?'}`,
          );
        }
      } else if (resp.status === 503) {
        console.warn(
          `[${i + 1}/${slice.length}] ${id} 429 from RapidAPI — sleeping 5s`,
        );
        await sleep(5000);
        i--;
        continue;
      } else {
        failed++;
        const errMsg = payload.error ?? `HTTP ${resp.status}`;
        failures.push({ id, error: errMsg });
        console.warn(`[${i + 1}/${slice.length}] ${id} FAILED: ${errMsg}`);
      }
    } catch (err) {
      failed++;
      const errMsg = (err as Error).message;
      failures.push({ id, error: errMsg });
      console.warn(`[${i + 1}/${slice.length}] ${id} EXCEPTION: ${errMsg}`);
    }

    if (i < slice.length - 1 && throttleMs > 0) {
      await sleep(throttleMs);
    }
  }

  console.log('---');
  console.log(`Uploaded: ${uploaded}`);
  console.log(`Cached:   ${cached}`);
  console.log(`Failed:   ${failed}`);

  if (failures.length > 0) {
    const logPath = 'supabase/scripts/prepopulate_exercise_gifs.failures.log';
    await Deno.writeTextFile(
      logPath,
      failures.map((f) => `${f.id}\t${f.error}`).join('\n') + '\n',
    );
    console.log(`Failures written to: ${logPath}`);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((err) => {
  console.error('prepopulate_exercise_gifs failed:', err);
  Deno.exit(1);
});

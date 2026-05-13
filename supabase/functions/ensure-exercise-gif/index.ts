/**
 * Ensures a RapidAPI ExerciseDB GIF for a given `exerciseId` is mirrored to the
 * public Supabase Storage bucket `exercise-gifs`. The iOS app calls this when
 * a direct GET of the public object returned 404, and once-off `prepopulate_exercise_gifs.ts`
 * uses it to fill the bucket for every bundled exercise.
 *
 * Required Supabase secrets:
 *   - SUPABASE_URL
 *   - SUPABASE_SERVICE_ROLE_KEY
 *   - RAPIDAPI_EXERCISEDB_KEY
 */
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const BUCKET = 'exercise-gifs';
const RAPID_HOST = 'exercisedb.p.rapidapi.com';
const DEFAULT_RESOLUTION = '180';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface EnsureBody {
  exerciseId?: string;
  resolution?: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const rapidKey = Deno.env.get('RAPIDAPI_EXERCISEDB_KEY') ?? '';

    if (!supabaseUrl || !serviceRoleKey) {
      return json({ success: false, error: 'Supabase env missing on function' }, 500);
    }
    if (!rapidKey) {
      return json({ success: false, error: 'RAPIDAPI_EXERCISEDB_KEY missing on function' }, 500);
    }

    let body: EnsureBody = {};
    if (req.method === 'POST') {
      try {
        body = await req.json();
      } catch (_) {
        body = {};
      }
    } else {
      const url = new URL(req.url);
      body.exerciseId = url.searchParams.get('exerciseId') ?? undefined;
      body.resolution = url.searchParams.get('resolution') ?? undefined;
    }

    const exerciseId = (body.exerciseId ?? '').trim();
    const resolution = (body.resolution ?? DEFAULT_RESOLUTION).trim();

    if (!exerciseId) {
      return json({ success: false, error: 'exerciseId is required' }, 400);
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
    const objectPath = `${exerciseId}.gif`;
    const publicUrl = `${supabaseUrl}/storage/v1/object/public/${BUCKET}/${objectPath}`;

    // Cheap existence check: ask Storage API directly via HEAD on the public URL.
    const headResp = await fetch(publicUrl, { method: 'HEAD' });
    if (headResp.ok) {
      return json({ success: true, alreadyExists: true, url: publicUrl });
    }

    // Pull from RapidAPI.
    const rapidUrl = `https://${RAPID_HOST}/image?exerciseId=${encodeURIComponent(exerciseId)}&resolution=${encodeURIComponent(resolution)}`;
    const rapidResp = await fetch(rapidUrl, {
      method: 'GET',
      headers: {
        'X-RapidAPI-Key': rapidKey,
        'X-RapidAPI-Host': RAPID_HOST,
      },
    });

    if (rapidResp.status === 429) {
      return json({ success: false, error: 'RapidAPI rate limited', status: 429 }, 503);
    }
    if (!rapidResp.ok) {
      const txt = await rapidResp.text().catch(() => '');
      return json({
        success: false,
        error: `RapidAPI returned ${rapidResp.status}`,
        body: txt.slice(0, 256),
      }, rapidResp.status === 404 ? 404 : 502);
    }

    const bytes = new Uint8Array(await rapidResp.arrayBuffer());
    if (bytes.byteLength === 0) {
      return json({ success: false, error: 'RapidAPI returned empty body' }, 502);
    }
    const contentType = rapidResp.headers.get('content-type') ?? 'image/gif';

    const { error: uploadErr } = await supabaseAdmin.storage
      .from(BUCKET)
      .upload(objectPath, bytes, {
        contentType,
        upsert: true,
        cacheControl: '31536000',
      });

    if (uploadErr) {
      return json({ success: false, error: `Upload failed: ${uploadErr.message}` }, 500);
    }

    return json({ success: true, uploaded: true, url: publicUrl, size: bytes.byteLength });
  } catch (error) {
    console.error('ensure-exercise-gif:', error);
    return json({ success: false, error: (error as Error).message }, 500);
  }
});

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

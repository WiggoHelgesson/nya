/**
 * LIST MARKETPLACE SERVICE POINTS (Shipmondo)
 * ===========================================
 * GET /pickup_points with carrier_code, country_code, zipcode.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import {
  SHIPMONDO_BASE_URL,
  shipmondoHeaders,
  mapCarrierKey,
  shipmondoCarrierCodeForServicePoints,
} from '../_shared/shipmondoMapping.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing Authorization header');

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) throw new Error('Unauthorized');

    const { carrier, addressLine, postalCode, city, limit } = await req.json();
    if (!carrier) throw new Error('carrier is required');
    if (!postalCode) throw new Error('postalCode is required');
    if (!city) throw new Error('city is required');

    const wanted = String(carrier).toLowerCase();
    const max = Math.min(Math.max(Number(limit) || 8, 1), 25);
    const carrierCode = shipmondoCarrierCodeForServicePoints(wanted);

    const params = new URLSearchParams({
      carrier_code: carrierCode,
      country_code: 'SE',
      zipcode: String(postalCode).replace(/\s/g, ''),
    });
    if (addressLine && String(addressLine).trim().length > 0) {
      params.set('address', String(addressLine).trim());
    }

    const url = `${SHIPMONDO_BASE_URL}/pickup_points?${params.toString()}`;
    let locations: unknown[] = [];
    try {
      const resp = await fetch(url, { method: 'GET', headers: shipmondoHeaders() });
      if (!resp.ok) {
        const errText = await resp.text();
        console.warn('Shipmondo /pickup_points non-OK:', resp.status, errText);
      } else {
        const json = await resp.json();
        if (Array.isArray(json)) locations = json;
        else if (Array.isArray((json as Record<string, unknown>)?.pickup_points)) {
          locations = (json as { pickup_points: unknown[] }).pickup_points;
        }
      }
    } catch (e) {
      console.warn('Shipmondo /pickup_points fetch failed:', (e as Error).message);
    }

    const filtered = locations
      .map((l: unknown) => {
        const row = l as Record<string, unknown>;
        const num = String(row.number ?? row.id ?? '');
        const agent = String(row.agent ?? row.carrier_code ?? '');
        const carrierKey = mapCarrierKey(agent);
        const dist = Number(row.distance ?? 0);
        return {
          token: num,
          name: String(row.name ?? row.company_name ?? 'Ombud'),
          carrier: carrierKey,
          addressLine: String(row.address ?? ''),
          postalCode: String(row.zipcode ?? ''),
          city: String(row.city ?? ''),
          country: String(row.country ?? 'SE'),
          distanceMeters: Number.isFinite(dist) ? Math.round(dist) : 0,
        };
      })
      .filter((sp) => sp.token.length > 0 && sp.carrier === wanted)
      .sort((a, b) => a.distanceMeters - b.distanceMeters)
      .slice(0, max);

    return new Response(
      JSON.stringify({ success: true, servicePoints: filtered }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
    );
  } catch (error) {
    console.error('list-marketplace-service-points error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
    );
  }
});

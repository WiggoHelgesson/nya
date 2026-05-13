/**
 * GET MARKETPLACE SHIPPING RATES (Shipmondo)
 * ==========================================
 * Lists available products from Shipmondo GET /products?country_code=SE,
 * filtered to ombud/service-point style carriers. `bookingToken` in the
 * response is the Shipmondo `product_code` (stored on the order row).
 *
 * Optional: set `SHIPMONDO_PRODUCT_PRICES_ORE_JSON` to map product_code → öre.
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { buildMarketplaceRatesFromProducts } from '../_shared/shipmondoMapping.ts';

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

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) throw new Error('Unauthorized');

    const { listingId, buyerPostal, buyerCity } = await req.json();
    if (!listingId) throw new Error('listingId is required');
    if (!buyerPostal) throw new Error('buyerPostal is required');

    const { data: listing, error: listingErr } = await supabaseAdmin
      .from('consignment_submissions')
      .select('id, user_id, package_size, ai_payload')
      .eq('id', listingId)
      .single();
    if (listingErr || !listing) throw new Error('Listing not found');

    const packageSize: string =
      listing.package_size ??
      listing.ai_payload?.packageSize ??
      'M';

    void buyerCity;

    const rates = await buildMarketplaceRatesFromProducts(packageSize);

    return new Response(
      JSON.stringify({ success: true, rates }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
    );
  } catch (error) {
    console.error('get-marketplace-shipping-rates error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
    );
  }
});

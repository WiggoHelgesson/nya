import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { format } = await req.json();

    if (!format || !['feed', 'banner', 'popup'].includes(format)) {
      return new Response(
        JSON.stringify({ error: '"format" must be feed, banner, or popup' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const now = new Date().toISOString();

    const { data: ads, error } = await supabase
      .from('ad_campaigns')
      .select('id, format, title, description, image_url, profile_image_url, cta_text, cta_url, daily_bid')
      .eq('format', format)
      .eq('status', 'active')
      .lte('start_date', now)
      .or(`end_date.is.null,end_date.gt.${now}`)
      .order('daily_bid', { ascending: false });

    if (error) {
      throw new Error(error.message);
    }

    if (ads && ads.length > 0) {
      const ids = ads.map((a: any) => a.id);
      await supabase.rpc('increment_ad_views', { campaign_ids: ids });
    }

    return new Response(
      JSON.stringify({ ads: ads || [] }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('get-active-ads error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Failed to fetch ads' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

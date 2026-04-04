import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const webhookSecret = Deno.env.get('SHOPIFY_WEBHOOK_SECRET') ?? ''
    const payload = await req.json()

    console.log('Received product webhook:', JSON.stringify({
      id: payload.id,
      title: payload.title,
      tags: payload.tags,
      handle: payload.handle,
    }))

    const tags: string = payload.tags ?? ''
    const bagTagMatch = tags.match(/bag:(UD-[A-Z0-9]{4})/i)

    if (!bagTagMatch) {
      console.log('No bag tag found on product, skipping')
      return new Response(
        JSON.stringify({ skipped: true, reason: 'No bag tag found' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const bagCode = bagTagMatch[1].toUpperCase()
    console.log(`Found bag code: ${bagCode}`)

    const { data: bags, error: bagError } = await supabase
      .from('seller_bags')
      .select('id, user_id, status')
      .eq('bag_code', bagCode)
      .limit(1)

    if (bagError || !bags || bags.length === 0) {
      console.error('Bag not found for code:', bagCode, bagError)
      return new Response(
        JSON.stringify({ error: `Bag not found for code ${bagCode}` }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const bag = bags[0]
    const productId = String(payload.id)
    const handle = payload.handle ?? ''
    const title = payload.title ?? ''
    const imageUrl = payload.image?.src ?? payload.images?.[0]?.src ?? ''
    const price = parseFloat(payload.variants?.[0]?.price ?? '0')

    let sellerShare = price * 0.40
    if (price > 500) {
      sellerShare = 500 * 0.40 + (price - 500) * 0.70
    }

    const { data: existing } = await supabase
      .from('seller_items')
      .select('id')
      .eq('shopify_product_id', productId)
      .limit(1)

    if (existing && existing.length > 0) {
      console.log(`Product ${productId} already synced, updating`)
      await supabase
        .from('seller_items')
        .update({
          title,
          image_url: imageUrl,
          price,
          seller_share: sellerShare,
        })
        .eq('shopify_product_id', productId)
    } else {
      const { error: insertError } = await supabase
        .from('seller_items')
        .insert({
          bag_id: bag.id,
          user_id: bag.user_id,
          shopify_product_id: productId,
          shopify_handle: handle,
          title,
          image_url: imageUrl,
          price,
          status: 'listed',
          seller_share: sellerShare,
          ad_cost: 12,
        })

      if (insertError) {
        console.error('Failed to insert seller_item:', insertError)
        return new Response(
          JSON.stringify({ error: 'Failed to create seller item', details: insertError }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    if (bag.status !== 'listed' && bag.status !== 'completed') {
      await supabase
        .from('seller_bags')
        .update({ status: 'listed' })
        .eq('id', bag.id)
    }

    console.log(`Successfully synced product ${productId} to bag ${bagCode}`)

    return new Response(
      JSON.stringify({
        success: true,
        bagCode,
        productId,
        title,
        sellerShare,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

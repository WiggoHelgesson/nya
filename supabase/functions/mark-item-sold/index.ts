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

    const payload = await req.json()

    console.log('Received order webhook:', JSON.stringify({
      id: payload.id,
      order_number: payload.order_number,
      financial_status: payload.financial_status,
      line_items_count: payload.line_items?.length,
    }))

    const lineItems = payload.line_items ?? []

    if (lineItems.length === 0) {
      return new Response(
        JSON.stringify({ skipped: true, reason: 'No line items' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let updatedCount = 0
    const results: any[] = []

    for (const item of lineItems) {
      const productId = String(item.product_id)

      const { data: sellerItems, error } = await supabase
        .from('seller_items')
        .select('id, bag_id, user_id, price, seller_share, status')
        .eq('shopify_product_id', productId)
        .eq('status', 'listed')
        .limit(1)

      if (error || !sellerItems || sellerItems.length === 0) {
        results.push({ productId, skipped: true, reason: 'Not a seller item or already sold' })
        continue
      }

      const sellerItem = sellerItems[0]
      const soldPrice = parseFloat(item.price ?? '0')

      let sellerShare = soldPrice * 0.40
      if (soldPrice > 500) {
        sellerShare = 500 * 0.40 + (soldPrice - 500) * 0.70
      }

      const { error: updateError } = await supabase
        .from('seller_items')
        .update({
          status: 'sold',
          sold_at: new Date().toISOString(),
          price: soldPrice,
          seller_share: sellerShare,
        })
        .eq('id', sellerItem.id)

      if (updateError) {
        console.error(`Failed to update seller_item ${sellerItem.id}:`, updateError)
        results.push({ productId, error: updateError.message })
        continue
      }

      updatedCount++
      results.push({ productId, sellerItemId: sellerItem.id, soldPrice, sellerShare })

      const { data: remainingItems } = await supabase
        .from('seller_items')
        .select('id')
        .eq('bag_id', sellerItem.bag_id)
        .eq('status', 'listed')
        .limit(1)

      if (!remainingItems || remainingItems.length === 0) {
        await supabase
          .from('seller_bags')
          .update({ status: 'completed' })
          .eq('id', sellerItem.bag_id)
        console.log(`Bag ${sellerItem.bag_id} marked as completed (all items sold)`)
      }
    }

    console.log(`Processed order ${payload.order_number}: ${updatedCount} items marked as sold`)

    return new Response(
      JSON.stringify({
        success: true,
        orderId: payload.id,
        orderNumber: payload.order_number,
        updatedCount,
        results,
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

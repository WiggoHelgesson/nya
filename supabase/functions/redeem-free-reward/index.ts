import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RedeemRequest {
  userId: string
  rewardId: string
  productId: string        // Shopify product GID, e.g. "gid://shopify/Product/123"
  productTitle: string
  productPrice: number     // price in SEK, validated against app_config.max_reward_cost
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { userId, rewardId, productId, productTitle, productPrice } = await req.json() as RedeemRequest

    if (!userId || !rewardId || !productId) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: userId, rewardId, productId' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 1. Verify the reward exists and is still earned (unredeemed)
    const { data: reward, error: rewardError } = await supabase
      .from('free_product_rewards')
      .select('id, status')
      .eq('id', rewardId)
      .eq('user_id', userId)
      .single()

    if (rewardError || !reward) {
      return new Response(
        JSON.stringify({ error: 'Reward not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (reward.status !== 'earned') {
      return new Response(
        JSON.stringify({ error: 'Reward already redeemed' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Validate cost cap from app_config
    const { data: config } = await supabase
      .from('app_config')
      .select('max_reward_cost')
      .limit(1)
      .single()

    const maxCost = config?.max_reward_cost ?? 500
    if (typeof productPrice === 'number' && productPrice > maxCost) {
      return new Response(
        JSON.stringify({ error: 'Product exceeds max reward cost', maxCost }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. Get Shopify Admin token (client_credentials grant, same as create-points-discount)
    const shopifyStore = 'up-down-gear-1b0k2'
    const clientId = Deno.env.get('SHOPIFY_CLIENT_ID') ?? ''
    const clientSecret = Deno.env.get('SHOPIFY_CLIENT_SECRET') ?? ''

    const tokenRes = await fetch(
      `https://${shopifyStore}.myshopify.com/admin/oauth/access_token`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'client_credentials',
          client_id: clientId,
          client_secret: clientSecret,
        }),
      }
    )

    if (!tokenRes.ok) {
      console.error('Failed to obtain Shopify access token:', await tokenRes.text())
      return new Response(
        JSON.stringify({ error: 'Failed to authenticate with Shopify' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { access_token: shopifyAdminToken } = await tokenRes.json()

    // 4. Create a 100% price rule restricted to this specific product.
    //    Shipping is NOT included — Shopify charges shipping at checkout as usual.
    const code = `UDFREE-${Date.now().toString(36).toUpperCase()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`
    const numericProductId = productId.split('/').pop() // GID -> numeric id

    const priceRuleRes = await fetch(
      `https://${shopifyStore}.myshopify.com/admin/api/2025-07/price_rules.json`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': shopifyAdminToken,
        },
        body: JSON.stringify({
          price_rule: {
            title: code,
            target_type: 'line_item',
            target_selection: 'entitled',
            entitled_product_ids: [Number(numericProductId)],
            allocation_method: 'across',
            value_type: 'percentage',
            value: '-100',
            customer_selection: 'all',
            usage_limit: 1,
            allocation_limit: 1,
            starts_at: new Date().toISOString(),
          }
        })
      }
    )

    if (!priceRuleRes.ok) {
      console.error('Shopify price rule creation failed:', await priceRuleRes.text())
      return new Response(
        JSON.stringify({ error: 'Failed to create discount on Shopify' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const priceRule = await priceRuleRes.json()
    const priceRuleId = priceRule.price_rule.id

    const discountRes = await fetch(
      `https://${shopifyStore}.myshopify.com/admin/api/2025-07/price_rules/${priceRuleId}/discount_codes.json`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': shopifyAdminToken,
        },
        body: JSON.stringify({
          discount_code: { code }
        })
      }
    )

    if (!discountRes.ok) {
      console.error('Shopify discount code creation failed:', await discountRes.text())
      return new Response(
        JSON.stringify({ error: 'Failed to create discount code' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 5. Mark reward as redeemed atomically BEFORE returning the code.
    //    The RPC only flips status when it is still 'earned' — double redemption is impossible.
    const { data: redeemed, error: redeemError } = await supabase.rpc('redeem_free_reward', {
      p_reward_id: rewardId,
      p_user_id: userId,
      p_product_id: productId,
      p_product_title: productTitle ?? '',
      p_discount_code: code,
      p_order_id: null,
    })

    if (redeemError || redeemed !== true) {
      console.error('Failed to mark reward redeemed:', redeemError)
      return new Response(
        JSON.stringify({ error: 'Reward could not be redeemed (already used?)' }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ code }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('Error:', err)
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

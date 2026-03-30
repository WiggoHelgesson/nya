import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DiscountRequest {
  userId: string
  xpCost: number
  percent: number
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

    const { userId, xpCost, percent } = await req.json() as DiscountRequest

    if (!userId || !xpCost || !percent) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: userId, xpCost, percent' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fetch current XP
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('current_xp')
      .eq('id', userId)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'User profile not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (profile.current_xp < xpCost) {
      return new Response(
        JSON.stringify({ error: 'Insufficient XP', required: xpCost, current: profile.current_xp }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate unique discount code
    const code = `UD${percent}-${Date.now().toString(36).toUpperCase()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`

    // Obtain a fresh Shopify Admin API token via client_credentials grant
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
      const errBody = await tokenRes.text()
      console.error('Failed to obtain Shopify access token:', errBody)
      return new Response(
        JSON.stringify({ error: 'Failed to authenticate with Shopify' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { access_token: shopifyAdminToken } = await tokenRes.json()

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
            target_selection: 'all',
            allocation_method: 'across',
            value_type: 'percentage',
            value: `-${percent}`,
            customer_selection: 'all',
            usage_limit: 1,
            starts_at: new Date().toISOString(),
          }
        })
      }
    )

    if (!priceRuleRes.ok) {
      const errBody = await priceRuleRes.text()
      console.error('Shopify price rule creation failed:', errBody)
      return new Response(
        JSON.stringify({ error: 'Failed to create discount on Shopify' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const priceRule = await priceRuleRes.json()
    const priceRuleId = priceRule.price_rule.id

    // Create discount code for the price rule
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
      const errBody = await discountRes.text()
      console.error('Shopify discount code creation failed:', errBody)
      return new Response(
        JSON.stringify({ error: 'Failed to create discount code' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Deduct XP from profile
    const newXP = profile.current_xp - xpCost
    const { error: updateError } = await supabase
      .from('profiles')
      .update({ current_xp: newXP })
      .eq('id', userId)

    if (updateError) {
      console.error('Failed to deduct XP:', updateError)
    }

    return new Response(
      JSON.stringify({ code, percent }),
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

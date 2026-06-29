import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { verifySessionToken, jsonResponse, corsHeaders, getFunctionsBase, exchangeSessionTokenForOfflineToken } from "../_shared/shopify.ts"
import { finalizeInstall } from "../_shared/install.ts"

// Backend for the embedded merchant dashboard (App Bridge).
//
// Auth: a Shopify session token (JWT signed with the app secret) in the
// Authorization: Bearer <token> header. We verify it and derive the shop
// domain, so the merchant can only ever read/write its own data.
//
// Routes (path suffix after /merchant-api):
//   GET  /status              -> connection status, product count, webhooks, settings
//   GET  /products             -> recent synced products (sample)
//   POST /settings             -> update commission_rate + discount_model
//   POST /sync                 -> trigger a product re-sync
//   POST /campaign             -> create/update a default discount campaign
//   POST /upload-image         -> upload a banner/logo to Storage, return public URL
//   POST /merchant-reward      -> create/update a self-serve reward (status active)
//   GET  /merchant-rewards     -> list this shop's rewards
//   POST /merchant-reward/unpublish -> set a reward to status 'inactive'
//
// Deploy with --no-verify-jwt.

const REWARD_BUCKET = 'merchant-assets'
const ALLOWED_DISCOUNTS = [5, 10, 15, 20, 25]

// Decode a data URL ("data:image/png;base64,....") into bytes + content type.
function decodeDataUrl(dataUrl: string): { bytes: Uint8Array; contentType: string; ext: string } | null {
  const match = /^data:([^;]+);base64,(.*)$/s.exec(dataUrl)
  if (!match) return null
  const contentType = match[1]
  const binary = atob(match[2])
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  const ext = contentType.split('/')[1]?.replace('jpeg', 'jpg') ?? 'jpg'
  return { bytes, contentType, ext }
}

const REQUIRED_WEBHOOK_TOPICS = [
  'products/create', 'products/update', 'products/delete',
  'inventory_levels/update', 'orders/create', 'orders/updated', 'app/uninstalled',
]

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: { ...corsHeaders, 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' },
    })
  }

  try {
    // 1. Verify the Shopify session token.
    const authHeader = req.headers.get('Authorization') ?? ''
    const token = authHeader.replace(/^Bearer\s+/i, '')
    if (!token) return jsonResponse({ error: 'Missing session token' }, 401)

    let shop: string
    try {
      const claims = await verifySessionToken(token)
      shop = claims.shop
    } catch (e) {
      console.error('session token verification failed:', e)
      return jsonResponse({ error: 'Invalid session token' }, 401)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const url = new URL(req.url)
    const route = url.pathname.replace(/^.*\/merchant-api/, '') || '/status'

    // ---- POST /connect ----
    // Auto-connect via token exchange: swap the App Bridge session token for an
    // expiring offline token and (re)activate the installation. Runs before the
    // merchant lookup so brand-new stores (no merchant row yet) can connect.
    if (req.method === 'POST' && route === '/connect') {
      try {
        const bundle = await exchangeSessionTokenForOfflineToken(shop, token)
        const { merchantId } = await finalizeInstall(supabase, shop, bundle)
        return jsonResponse({ connected: true, merchantId })
      } catch (e) {
        console.error('connect failed:', e)
        return jsonResponse({ error: `Connect failed: ${e instanceof Error ? e.message : String(e)}` }, 502)
      }
    }

    // 2. Resolve the merchant for this shop.
    const { data: merchant } = await supabase
      .from('merchants')
      .select('*')
      .eq('shop_domain', shop)
      .maybeSingle()

    if (!merchant) return jsonResponse({ error: 'Merchant not found' }, 404)

    const { data: installation } = await supabase
      .from('merchant_shopify_installations')
      .select('is_active, scopes, api_version, installed_at')
      .eq('merchant_id', merchant.id)
      .maybeSingle()

    // ---- GET /status ----
    if (req.method === 'GET' && (route === '/status' || route === '' || route === '/')) {
      const { count: productCount } = await supabase
        .from('products')
        .select('id', { count: 'exact', head: true })
        .eq('merchant_id', merchant.id)
        .eq('status', 'active')

      const { data: lastSync } = await supabase
        .from('sync_logs')
        .select('status, items_processed, finished_at, type')
        .eq('merchant_id', merchant.id)
        .order('started_at', { ascending: false })
        .limit(1)
        .maybeSingle()

      const { count: webhookCount } = await supabase
        .from('webhook_events')
        .select('id', { count: 'exact', head: true })
        .eq('merchant_id', merchant.id)

      return jsonResponse({
        shop,
        connected: !!installation?.is_active,
        status: merchant.status,
        productsSynced: productCount ?? 0,
        lastSync,
        webhooksActive: !!installation?.is_active, // configured at install via shopify.app.toml + ensureWebhook
        requiredWebhooks: REQUIRED_WEBHOOK_TOPICS,
        commissionRate: merchant.commission_rate,
        discountModel: merchant.discount_model,
        installedAt: installation?.installed_at ?? null,
      })
    }

    // ---- GET /products ----
    if (req.method === 'GET' && route === '/products') {
      const { data: products } = await supabase
        .from('products')
        .select('id, title, vendor, product_type, min_price, currency, status, synced_at')
        .eq('merchant_id', merchant.id)
        .order('synced_at', { ascending: false })
        .limit(50)
      return jsonResponse({ products: products ?? [] })
    }

    // ---- POST /settings ----
    if (req.method === 'POST' && route === '/settings') {
      const body = await req.json()
      const update: Record<string, unknown> = {}
      if (typeof body.commissionRate === 'number') update.commission_rate = body.commissionRate
      if (body.discountModel && typeof body.discountModel === 'object') update.discount_model = body.discountModel
      if (Object.keys(update).length === 0) return jsonResponse({ error: 'Nothing to update' }, 400)

      const { error } = await supabase.from('merchants').update(update).eq('id', merchant.id)
      if (error) return jsonResponse({ error: 'Update failed' }, 500)
      return jsonResponse({ ok: true })
    }

    // ---- POST /sync ----
    if (req.method === 'POST' && route === '/sync') {
      fetch(`${getFunctionsBase()}/shopify-sync-products`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''}`,
        },
        body: JSON.stringify({ merchantId: merchant.id, type: 'full' }),
      }).catch((e) => console.error('sync trigger failed:', e))
      return jsonResponse({ ok: true, started: true })
    }

    // ---- POST /campaign ----
    if (req.method === 'POST' && route === '/campaign') {
      const body = await req.json()
      const row = {
        merchant_id: merchant.id,
        name: body.name ?? 'Default discount',
        code_prefix: body.codePrefix ?? 'UD',
        type: body.type ?? 'percentage',
        value: body.value ?? 0,
        scope: body.scope ?? 'order',
        entitled_product_ids: body.entitledProductIds ?? [],
        once_per_user: body.oncePerUser ?? true,
        usage_limit: body.usageLimit ?? 1,
        validity_days: body.validityDays ?? 30,
        xp_cost: body.xpCost ?? 200,
        active: body.active ?? true,
      }
      const { data, error } = body.id
        ? await supabase.from('discount_campaigns').update(row).eq('id', body.id).eq('merchant_id', merchant.id).select('id').single()
        : await supabase.from('discount_campaigns').insert(row).select('id').single()
      if (error) return jsonResponse({ error: 'Campaign save failed' }, 500)
      return jsonResponse({ ok: true, id: data?.id })
    }

    // ---- POST /upload-image ----
    // Body: { kind: 'banner' | 'logo', dataUrl: 'data:image/...;base64,...' }
    if (req.method === 'POST' && route === '/upload-image') {
      const body = await req.json()
      const kind = body.kind === 'logo' ? 'logo' : 'banner'
      const decoded = typeof body.dataUrl === 'string' ? decodeDataUrl(body.dataUrl) : null
      if (!decoded) return jsonResponse({ error: 'Invalid image data' }, 400)

      const objectPath = `${shop}/${kind}-${Date.now()}.${decoded.ext}`
      const { error: uploadErr } = await supabase.storage
        .from(REWARD_BUCKET)
        .upload(objectPath, decoded.bytes, {
          contentType: decoded.contentType,
          upsert: true,
          cacheControl: '31536000',
        })
      if (uploadErr) {
        console.error('image upload failed:', uploadErr)
        return jsonResponse({ error: 'Upload failed' }, 500)
      }

      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
      const url = `${supabaseUrl}/storage/v1/object/public/${REWARD_BUCKET}/${objectPath}`
      return jsonResponse({ url })
    }

    // ---- GET /commission-stats ----
    if (req.method === 'GET' && route === '/commission-stats') {
      const { data: rows } = await supabase
        .from('merchant_reward_redemptions')
        .select('order_value, commission_amount, status, commission_status')
        .eq('shop_domain', shop)
        .eq('status', 'used')

      const used = rows ?? []
      const totalSales = used.reduce((sum, r) => sum + Number(r.order_value ?? 0), 0)
      const totalCommission = used.reduce((sum, r) => sum + Number(r.commission_amount ?? 0), 0)
      // Outstanding = commission not yet paid (pending + invoiced).
      const outstandingCommission = used
        .filter((r) => r.commission_status !== 'paid')
        .reduce((sum, r) => sum + Number(r.commission_amount ?? 0), 0)

      return jsonResponse({
        purchases: used.length,
        totalSales: Math.round(totalSales * 100) / 100,
        totalCommission: Math.round(totalCommission * 100) / 100,
        outstandingCommission: Math.round(outstandingCommission * 100) / 100,
        currency: merchant.currency ?? null,
      })
    }

    // ---- GET /commission-purchases ----
    // Per-purchase breakdown for the merchant's "Provision" tab.
    if (req.method === 'GET' && route === '/commission-purchases') {
      const { data: rows } = await supabase
        .from('merchant_reward_redemptions')
        .select(
          'order_number, order_value, commission_amount, commission_status, discount_code, used_at, created_at, merchant_rewards(title)',
        )
        .eq('shop_domain', shop)
        .eq('status', 'used')
        .order('used_at', { ascending: false })

      return jsonResponse({
        currency: merchant.currency ?? null,
        purchases: (rows ?? []).map((r) => ({
          orderNumber: r.order_number,
          rewardTitle: (r.merchant_rewards as { title?: string } | null)?.title ?? null,
          orderValue: Number(r.order_value ?? 0),
          commission: Number(r.commission_amount ?? 0),
          commissionStatus: r.commission_status,
          discountCode: r.discount_code,
          date: r.used_at ?? r.created_at,
        })),
      })
    }

    // ---- GET /merchant-rewards ----
    if (req.method === 'GET' && route === '/merchant-rewards') {
      const { data: rewards } = await supabase
        .from('merchant_rewards')
        .select('*')
        .eq('shop_domain', shop)
        .order('created_at', { ascending: false })
      return jsonResponse({ rewards: rewards ?? [] })
    }

    // ---- POST /merchant-reward/unpublish ----
    if (req.method === 'POST' && route === '/merchant-reward/unpublish') {
      const body = await req.json()
      if (!body.id) return jsonResponse({ error: 'Missing id' }, 400)
      const { error } = await supabase
        .from('merchant_rewards')
        .update({ status: 'inactive' })
        .eq('id', body.id)
        .eq('shop_domain', shop)
      if (error) return jsonResponse({ error: 'Unpublish failed' }, 500)
      return jsonResponse({ ok: true })
    }

    // ---- POST /merchant-reward ----  (create or update + publish)
    if (req.method === 'POST' && route === '/merchant-reward') {
      const body = await req.json()
      const title = typeof body.title === 'string' ? body.title.trim() : ''
      const description = typeof body.description === 'string' ? body.description.trim() : ''
      const bannerImageUrl = typeof body.bannerImageUrl === 'string' ? body.bannerImageUrl.trim() : ''
      const logoUrl = typeof body.logoUrl === 'string' ? body.logoUrl.trim() : ''
      const discount = Number(body.customerDiscountPercent)

      if (!title || !description || !bannerImageUrl || !logoUrl) {
        return jsonResponse({ error: 'All fields (title, description, banner, logo) are required' }, 400)
      }
      if (!ALLOWED_DISCOUNTS.includes(discount)) {
        return jsonResponse({ error: 'Discount must be one of 5, 10, 15, 20, 25' }, 400)
      }

      const row = {
        shop_domain: shop,
        title,
        description,
        banner_image_url: bannerImageUrl,
        logo_url: logoUrl,
        customer_discount_percent: discount,
        updown_commission_percent: 5,
        status: 'active',
      }

      const { data, error } = body.id
        ? await supabase
            .from('merchant_rewards')
            .update(row)
            .eq('id', body.id)
            .eq('shop_domain', shop)
            .select('*')
            .single()
        : await supabase.from('merchant_rewards').insert(row).select('*').single()

      if (error) {
        console.error('reward save failed:', error)
        return jsonResponse({ error: 'Reward save failed' }, 500)
      }
      return jsonResponse({ ok: true, reward: data })
    }

    return jsonResponse({ error: 'Not found' }, 404)
  } catch (err) {
    console.error('merchant-api error:', err)
    return jsonResponse({ error: String(err) }, 500)
  }
})

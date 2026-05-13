import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
import {
  fetchBuyerDisplayName,
  resolveListingConversation,
} from '../_shared/marketplaceListingConversation.ts'
import { buildMarketplaceRatesFromProducts } from '../_shared/shipmondoMapping.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

type SimulateRequest = {
  listing_id?: string
  book_shipping?: boolean
  replay?: boolean
}

function parseAdminIds(): Set<string> {
  const raw = Deno.env.get('ADMIN_USER_IDS') ?? ''
  return new Set(raw.split(',').map((s) => s.trim()).filter(Boolean))
}

async function bookShipping(orderId: string): Promise<boolean> {
  try {
    const url = `${Deno.env.get('SUPABASE_URL')}/functions/v1/book-marketplace-shipping`
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''}`,
        'apikey': Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      },
      body: JSON.stringify({ orderId }),
    })
    if (!resp.ok) {
      const text = await resp.text()
      console.warn('simulate-marketplace-purchase shipping booking failed:', resp.status, text)
      return false
    }
    return true
  } catch (e) {
    console.warn('simulate-marketplace-purchase shipping booking exception:', (e as Error).message)
    return false
  }
}

type PostPurchaseResult = {
  skipped: boolean
  conversationId: string | null
  bookedShipping: boolean
}

async function runPostPurchaseEffects(
  supabaseAdmin: ReturnType<typeof createClient>,
  orderId: string,
  buyerId: string,
  bookShippingWanted: boolean
): Promise<PostPurchaseResult> {
  const { data: order, error: orderErr } = await supabaseAdmin
    .from('marketplace_orders')
    .select(`
      id, status, listing_id, seller_id, buyer_id, listing_title,
      amount_item, amount_buyer_total, buyer_username, ship_by_deadline
    `)
    .eq('id', orderId)
    .single()

  if (orderErr || !order) {
    throw new Error(`Order not found while processing simulate flow: ${orderErr?.message ?? 'unknown'}`)
  }

  const terminalOrPostStatuses = ['succeeded', 'released', 'refunded', 'disputed', 'cancelled']
  if (terminalOrPostStatuses.includes(order.status)) {
    return {
      skipped: true,
      conversationId: null,
      bookedShipping: false,
    }
  }

  const nowIso = new Date().toISOString()
  const { error: statusErr } = await supabaseAdmin
    .from('marketplace_orders')
    .update({
      status: 'succeeded',
      stripe_charge_id: `test_charge_${crypto.randomUUID()}`,
      updated_at: nowIso,
    })
    .eq('id', order.id)
  if (statusErr) {
    console.error('simulate-marketplace-purchase status update failed:', statusErr)
  }

  const buyerName = await fetchBuyerDisplayName(supabaseAdmin, buyerId)
  const productLabel =
    typeof order.listing_title === 'string' && order.listing_title.trim().length > 0
      ? order.listing_title.trim()
      : 'din produkt'
  const itemKr = Math.round(Number(order.amount_item ?? 0) / 100)
  const totalKr = Math.round(Number(order.amount_buyer_total ?? 0) / 100)
  const sellerBody = `${buyerName} köpte din ${productLabel} för ${itemKr} kr`
  const buyerBody =
    `Ditt köp av ${productLabel} är genomfört — totalt ${totalKr} kr. Säljaren packar och skickar inom 3 dagar.`

  const { error: buyerNameErr } = await supabaseAdmin
    .from('marketplace_orders')
    .update({ buyer_username: buyerName })
    .eq('id', order.id)
  if (buyerNameErr) {
    console.error('simulate-marketplace-purchase buyer_username update failed:', buyerNameErr)
  }

  const { error: notifErr } = await supabaseAdmin.from('notifications').insert([
    {
      user_id: order.seller_id,
      type: 'marketplace_sale',
      actor_id: order.buyer_id,
      related_id: order.listing_id,
      comment_text: sellerBody,
    },
    {
      user_id: order.buyer_id,
      type: 'marketplace_purchase',
      actor_id: order.seller_id,
      related_id: order.listing_id,
      comment_text: buyerBody,
    },
  ])
  if (notifErr) {
    console.error('simulate-marketplace-purchase notifications insert failed:', notifErr)
  }

  let bookedShipping = false
  if (bookShippingWanted) {
    bookedShipping = await bookShipping(order.id as string)
  }

  // Re-fetch after optional booking to include ship_by_deadline when available.
  const { data: orderAfterBooking } = await supabaseAdmin
    .from('marketplace_orders')
    .select('id, listing_id, seller_id, buyer_id, listing_title, amount_item, buyer_username, ship_by_deadline')
    .eq('id', order.id)
    .maybeSingle()

  const resolvedOrder = orderAfterBooking ?? order
  const conversationId = await resolveListingConversation(
    supabaseAdmin,
    resolvedOrder.buyer_id as string,
    resolvedOrder.seller_id as string,
    resolvedOrder.listing_id as string
  )

  if (conversationId) {
    const payload = {
      kind: 'purchase_completed',
      order_id: resolvedOrder.id,
      listing_id: resolvedOrder.listing_id,
      listing_title: resolvedOrder.listing_title ?? null,
      buyer_id: resolvedOrder.buyer_id,
      buyer_username: resolvedOrder.buyer_username ?? buyerName,
      seller_id: resolvedOrder.seller_id,
      amount_item_ore: resolvedOrder.amount_item,
      ship_by_deadline: resolvedOrder.ship_by_deadline ?? null,
    }
    const { error: dmErr } = await supabaseAdmin.from('direct_messages').insert({
      conversation_id: conversationId,
      sender_id: resolvedOrder.buyer_id,
      message: JSON.stringify(payload),
      message_type: 'purchase_completed',
    })
    if (dmErr) {
      console.error('simulate-marketplace-purchase direct_messages insert failed:', dmErr)
    }
  } else {
    console.warn('simulate-marketplace-purchase: no conversation created/resolved', order.id)
  }

  return {
    skipped: false,
    conversationId: conversationId ?? null,
    bookedShipping,
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: authData, error: authErr } = await supabaseClient.auth.getUser()
    if (authErr || !authData?.user) {
      throw new Error('Unauthorized')
    }
    const user = authData.user

    const adminEmails = new Set([
      'admin@updown.app',
      'wiggohelgesson@gmail.com',
      'info@wiggio.se',
      'info@bylito.se',
    ])
    const adminIds = parseAdminIds()
    const userEmail = (user.email ?? '').toLowerCase()
    const isAdmin = adminEmails.has(userEmail) || adminIds.has(user.id)
    if (!isAdmin) {
      return new Response(
        JSON.stringify({ success: false, error: 'Admin only' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const body = (await req.json()) as SimulateRequest
    const listingId = body.listing_id?.trim()
    const bookShipping = body.book_shipping !== false
    const replay = body.replay === true
    if (!listingId) throw new Error('listing_id is required')

    const { data: listing, error: listingErr } = await supabaseAdmin
      .from('consignment_submissions')
      .select('id, user_id, admin_status, sold_at, sold_order_id, title, user_brand, image_urls, price_sek, package_size')
      .eq('id', listingId)
      .single()
    if (listingErr || !listing) throw new Error('Listing not found')
    if (listing.admin_status !== 'accepted') throw new Error('Listing must be accepted')
    if (listing.sold_at) throw new Error('Listing is already sold')
    if (listing.user_id === user.id) throw new Error('You cannot simulate buying your own listing')

    const priceSek = Number(listing.price_sek ?? 0)
    if (!Number.isFinite(priceSek) || priceSek <= 0) throw new Error('Listing has no valid price')

    const itemOre = Math.round(priceSek * 100)
    const platformFeeOre = Math.round(itemOre * 0.05) + 750
    const packageSize =
      typeof listing.package_size === 'string' && listing.package_size.trim().length > 0
        ? listing.package_size
        : 'M'
    const rates = await buildMarketplaceRatesFromProducts(packageSize)
    const chosenRate = rates.find((r) => r.bookingToken.trim().length > 0) ?? rates[0]
    if (!chosenRate) throw new Error('No Shipmondo rates available for package size')
    const shippingOre = Number(chosenRate.priceOre)
    if (!Number.isFinite(shippingOre) || shippingOre <= 0) {
      throw new Error('Invalid shipping rate')
    }
    const buyerTotalOre = itemOre + platformFeeOre + shippingOre
    const nowIso = new Date().toISOString()
    const pseudoIntent = `test_${crypto.randomUUID()}`
    const bookingTokenExpiresAt = new Date(Date.now() + 25 * 60 * 1000).toISOString()

    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('username, full_name, email')
      .eq('id', user.id)
      .maybeSingle()

    const displayName =
      (typeof profile?.username === 'string' && profile.username.trim()) ||
      (typeof profile?.full_name === 'string' && profile.full_name.trim()) ||
      user.email ||
      'Testköpare'
    const buyerEmail = (typeof profile?.email === 'string' && profile.email.trim()) || user.email || null

    const listingTitle =
      typeof listing.title === 'string' && listing.title.trim().length > 0
        ? listing.title.trim()
        : null
    const listingBrand =
      typeof listing.user_brand === 'string' && listing.user_brand.trim().length > 0
        ? listing.user_brand.trim()
        : null
    const firstImage = Array.isArray(listing.image_urls)
      ? listing.image_urls.find((u: unknown) => typeof u === 'string' && u.length > 0) ?? null
      : null

    const { data: insertedOrder, error: orderErr } = await supabaseAdmin
      .from('marketplace_orders')
      .insert({
        listing_id: listing.id,
        buyer_id: user.id,
        seller_id: listing.user_id,
        amount_item: itemOre,
        amount_platform_fee: platformFeeOre,
        amount_shipping: shippingOre,
        amount_buyer_total: buyerTotalOre,
        amount_seller_payout: itemOre,
        currency: 'sek',
        status: 'pending',
        is_held: true,
        is_test: true,
        stripe_payment_intent_id: pseudoIntent,
        stripe_charge_id: null,
        buyer_username: String(displayName).slice(0, 120),
        buyer_email: buyerEmail,
        buyer_shipping_name: String(displayName).slice(0, 120),
        buyer_shipping_address: 'Testgatan 1',
        buyer_shipping_postal: '41122',
        buyer_shipping_city: 'Göteborg',
        buyer_phone: '+46700000000',
        shipping_carrier: chosenRate.carrier,
        shipping_service_code: chosenRate.serviceCode,
        shipping_product_name: chosenRate.productName ?? chosenRate.name,
        shipping_booking_token: chosenRate.bookingToken,
        shipping_booking_token_expires_at: bookingTokenExpiresAt,
        shipping_status: 'pending',
        listing_title: listingTitle,
        listing_brand: listingBrand,
        listing_image_url: firstImage,
        updated_at: nowIso,
      })
      .select('id')
      .single()
    if (orderErr || !insertedOrder) {
      throw new Error(`Failed to create simulated order: ${orderErr?.message ?? 'unknown'}`)
    }

    await supabaseAdmin
      .from('consignment_submissions')
      .update({ sold_at: nowIso, sold_order_id: insertedOrder.id })
      .eq('id', listing.id)

    const firstPass = await runPostPurchaseEffects(
      supabaseAdmin,
      insertedOrder.id as string,
      user.id,
      bookShipping
    )
    let replaySecondPassSkipped = false
    if (replay) {
      const secondPass = await runPostPurchaseEffects(
        supabaseAdmin,
        insertedOrder.id as string,
        user.id,
        false
      )
      replaySecondPassSkipped = secondPass.skipped
    }

    return new Response(
      JSON.stringify({
        success: true,
        orderId: insertedOrder.id,
        conversationId: firstPass.conversationId,
        bookedShipping: firstPass.bookedShipping,
        replaySecondPassSkipped,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('simulate-marketplace-purchase error:', error)
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

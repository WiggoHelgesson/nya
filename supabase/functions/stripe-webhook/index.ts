import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from 'https://esm.sh/stripe@14.21.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
import {
  fetchBuyerDisplayName,
  resolveListingConversation,
} from '../_shared/marketplaceListingConversation.ts'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
})

const endpointSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') || ''

serve(async (req) => {
  const signature = req.headers.get('stripe-signature')
  if (!signature) {
    return new Response('No signature', { status: 400 })
  }

  try {
    const body = await req.text()
    const event = await stripe.webhooks.constructEventAsync(body, signature, endpointSecret)

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    switch (event.type) {
      case 'payment_intent.succeeded': {
        const intent = event.data.object as Stripe.PaymentIntent
        const source = intent.metadata?.source
        console.log(
          'webhook payment_intent.succeeded',
          'pi=',
          intent.id,
          'source=',
          source,
          'order_id=',
          intent.metadata?.order_id,
          'kind=',
          intent.metadata?.kind,
        )

        if (source === 'marketplace') {
          const shouldInsertKopNuPurchaseDm = await handleMarketplaceSucceeded(supabaseAdmin, intent)
          if (intent.metadata?.kind === 'listing_offer') {
            await supabaseAdmin
              .from('listing_offers')
              .update({
                status: 'captured',
                captured_at: new Date().toISOString(),
              })
              .eq('stripe_payment_intent_id', intent.id)
            // Offer flow books shipping in `finalize-marketplace-offer`
            // (it captures the PI itself), so we don't trigger booking
            // again from here.
          } else {
            // Direct "Köp nu"-flow: book shipping, then system-DM (deadline known).
            await triggerShippingBooking(intent)
            if (shouldInsertKopNuPurchaseDm) {
              await insertKopNuPurchaseCompletedDm(supabaseAdmin, intent)
            }
          }
        } else {
          await handleLessonSucceeded(supabaseAdmin, intent)
        }
        break
      }

      case 'payment_intent.canceled': {
        const intent = event.data.object as Stripe.PaymentIntent
        const source = intent.metadata?.source

        if (source === 'marketplace' && intent.metadata?.kind === 'listing_offer') {
          // Stripe uses cancellation_reason='automatic' (or 'abandoned')
          // when an uncaptured authorisation expires. We surface that as
          // 'expired' so the UI can distinguish it from seller decline or
          // auto-cancel.
          const reason = intent.cancellation_reason
          const isExpiry = reason === 'automatic' || reason === 'abandoned'
          const newStatus = isExpiry ? 'expired' : 'cancelled'

          // Flip both pending and accepted rows – an accepted offer can
          // still expire if the buyer never finalises within the
          // authorisation window (default 7 days).
          await supabaseAdmin
            .from('listing_offers')
            .update({ status: newStatus })
            .eq('stripe_payment_intent_id', intent.id)
            .in('status', ['pending', 'accepted'])
        }
        console.log('Payment canceled:', intent.id)
        break
      }

      case 'payment_intent.payment_failed': {
        const intent = event.data.object as Stripe.PaymentIntent
        const source = intent.metadata?.source

        if (source === 'marketplace') {
          if (intent.metadata?.kind === 'listing_offer') {
            await supabaseAdmin
              .from('listing_offers')
              .update({ status: 'cancelled' })
              .eq('stripe_payment_intent_id', intent.id)
          }
          await supabaseAdmin
            .from('marketplace_orders')
            .update({
              status: 'failed',
              updated_at: new Date().toISOString(),
            })
            .eq('stripe_payment_intent_id', intent.id)
        } else {
          await supabaseAdmin
            .from('lesson_payments')
            .update({
              status: 'failed',
              updated_at: new Date().toISOString(),
            })
            .eq('stripe_payment_intent_id', intent.id)
        }
        console.log('Payment failed:', intent.id)
        break
      }

      case 'charge.refunded': {
        const charge = event.data.object as Stripe.Charge

        // Marketplace refund
        const { data: marketplaceOrder } = await supabaseAdmin
          .from('marketplace_orders')
          .select('id, listing_id')
          .eq('stripe_charge_id', charge.id)
          .single()

        if (marketplaceOrder) {
          await supabaseAdmin
            .from('marketplace_orders')
            .update({ status: 'refunded', updated_at: new Date().toISOString() })
            .eq('id', marketplaceOrder.id)

          // Make listing purchasable again
          await supabaseAdmin
            .from('consignment_submissions')
            .update({ sold_at: null, sold_order_id: null })
            .eq('id', marketplaceOrder.listing_id)

          console.log('Marketplace order refunded:', marketplaceOrder.id)
          break
        }

        // Fallback: lesson payment
        await supabaseAdmin
          .from('lesson_payments')
          .update({
            status: 'refunded',
            updated_at: new Date().toISOString(),
          })
          .eq('stripe_charge_id', charge.id)

        console.log('Payment refunded:', charge.id)
        break
      }

      case 'account.updated': {
        const account = event.data.object as Stripe.Account
        const updates = {
          stripe_onboarding_complete: account.details_submitted,
          stripe_charges_enabled: account.charges_enabled,
          stripe_payouts_enabled: account.payouts_enabled,
        }

        // Try profiles (marketplace sellers) first
        const { data: profileMatch } = await supabaseAdmin
          .from('profiles')
          .select('id')
          .eq('stripe_account_id', account.id)
          .maybeSingle()

        if (profileMatch) {
          await supabaseAdmin
            .from('profiles')
            .update(updates)
            .eq('id', profileMatch.id)
          console.log(`Updated seller profile ${profileMatch.id} via account.updated`)
        }

        // Also try trainer_profiles (existing trainer flow)
        const { data: trainerMatch } = await supabaseAdmin
          .from('trainer_profiles')
          .select('id')
          .eq('stripe_account_id', account.id)
          .maybeSingle()

        if (trainerMatch) {
          await supabaseAdmin
            .from('trainer_profiles')
            .update(updates)
            .eq('id', trainerMatch.id)
          console.log(`Updated trainer profile ${trainerMatch.id} via account.updated`)
        }

        break
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err) {
    console.error('Webhook error:', err)
    return new Response(`Webhook Error: ${(err as Error).message}`, { status: 400 })
  }
})

async function handleMarketplaceSucceeded(
  supabaseAdmin: ReturnType<typeof createClient>,
  intent: Stripe.PaymentIntent
): Promise<boolean> {
  const chargeId = typeof intent.latest_charge === 'string' ? intent.latest_charge : undefined
  const isOfferFlow = intent.metadata?.kind === 'listing_offer'

  const { data: order } = await supabaseAdmin
    .from('marketplace_orders')
    .select('id, listing_id, seller_id, buyer_id, is_held, status')
    .eq('stripe_payment_intent_id', intent.id)
    .single()

  if (!order) {
    console.error('Marketplace order not found for intent', intent.id)
    return false
  }

  // Idempotens: Stripe kan leverera `payment_intent.succeeded` flera
  // gånger (retries / replays). Om vi redan har behandlat ordern (status
  // är `succeeded` / `released` / `refunded` / `disputed`) hoppar vi
  // över notiser och listing-update — annars duplicerar vi notiser.
  const terminalOrPostStatuses = ['succeeded', 'released', 'refunded', 'disputed', 'cancelled']
  if (terminalOrPostStatuses.includes(order.status)) {
    // Säkerställ ändå att stripe_charge_id är satt om det saknades.
    if (chargeId) {
      await supabaseAdmin
        .from('marketplace_orders')
        .update({ stripe_charge_id: chargeId })
        .eq('id', order.id)
        .is('stripe_charge_id', null)
    }
    console.log(`Marketplace order ${order.id} already in status=${order.status}, skipping idempotent webhook handling`)
    return false
  }

  await supabaseAdmin
    .from('marketplace_orders')
    .update({
      status: 'succeeded',
      stripe_charge_id: chargeId,
      updated_at: new Date().toISOString(),
    })
    .eq('id', order.id)

  // Mark listing sold so the card disappears from the feed
  await supabaseAdmin
    .from('consignment_submissions')
    .update({
      sold_at: new Date().toISOString(),
      sold_order_id: order.id,
    })
    .eq('id', order.listing_id)

  // Prisförslag: finalize-marketplace-offer skickar redan push + purchase_completed-DM.
  if (isOfferFlow) {
    console.log('Marketplace order succeeded (offer flow — notifications/DM from finalize):', order.id)
    return false
  }

  // Köp nu: personlig push + buyer_username. Systemchatten läggs in efter
  // book-marketplace-shipping (se insertKopNuPurchaseCompletedDm).
  try {
    const { data: orderFull } = await supabaseAdmin
      .from('marketplace_orders')
      .select('listing_id, seller_id, buyer_id, listing_title, amount_item, amount_buyer_total')
      .eq('id', order.id)
      .single()

    if (
      orderFull &&
      orderFull.listing_id &&
      orderFull.buyer_id &&
      orderFull.seller_id
    ) {
      const buyerName = await fetchBuyerDisplayName(supabaseAdmin, orderFull.buyer_id as string)
      const productLabel =
        typeof orderFull.listing_title === 'string' && orderFull.listing_title.trim().length > 0
          ? orderFull.listing_title.trim()
          : 'din produkt'
      const itemKr = Math.round(Number(orderFull.amount_item ?? 0) / 100)
      const totalKr = Math.round(Number(orderFull.amount_buyer_total ?? 0) / 100)
      const sellerBody = `${buyerName} köpte din ${productLabel} för ${itemKr} kr`
      const buyerBody =
        `Ditt köp av ${productLabel} är genomfört — totalt ${totalKr} kr. Säljaren packar och skickar inom 3 dagar.`

      const { error: buyerNameErr } = await supabaseAdmin
        .from('marketplace_orders')
        .update({ buyer_username: buyerName })
        .eq('id', order.id)
      if (buyerNameErr) {
        console.error('marketplace_orders buyer_username update failed (Köp nu):', buyerNameErr)
      }

      const { error: notifErr } = await supabaseAdmin.from('notifications').insert([
        {
          user_id: orderFull.seller_id,
          type: 'marketplace_sale',
          actor_id: orderFull.buyer_id,
          related_id: orderFull.listing_id,
          comment_text: sellerBody,
        },
        {
          user_id: orderFull.buyer_id,
          type: 'marketplace_purchase',
          actor_id: orderFull.seller_id,
          related_id: orderFull.listing_id,
          comment_text: buyerBody,
        },
      ])
      if (notifErr) {
        console.error('notifications insert failed (Köp nu marketplace_sale/purchase):', notifErr)
      }
    }
  } catch (e) {
    console.error('Failed to insert marketplace Köp nu notifications:', e)
  }

  console.log('Marketplace order succeeded:', order.id)
  return true
}

/**
 * Listing chat: purchase_completed efter att frakt bokats (ship_by_deadline satt om bokningen lyckades).
 */
async function insertKopNuPurchaseCompletedDm(
  supabaseAdmin: ReturnType<typeof createClient>,
  intent: Stripe.PaymentIntent
) {
  if (intent.metadata?.kind === 'listing_offer') return
  try {
    const { data: orderFull } = await supabaseAdmin
      .from('marketplace_orders')
      .select(
        'id, listing_id, seller_id, buyer_id, listing_title, amount_item, buyer_username, ship_by_deadline'
      )
      .eq('stripe_payment_intent_id', intent.id)
      .maybeSingle()

    if (
      !orderFull ||
      !orderFull.listing_id ||
      !orderFull.buyer_id ||
      !orderFull.seller_id
    ) {
      return
    }

    let buyerName =
      typeof orderFull.buyer_username === 'string' && orderFull.buyer_username.trim().length > 0
        ? orderFull.buyer_username.trim()
        : null
    if (!buyerName) {
      buyerName = await fetchBuyerDisplayName(supabaseAdmin, orderFull.buyer_id as string)
    }

    const conv = await resolveListingConversation(
      supabaseAdmin,
      orderFull.buyer_id as string,
      orderFull.seller_id as string,
      orderFull.listing_id as string
    )
    if (!conv) {
      console.warn('insertKopNuPurchaseCompletedDm: no conversation', orderFull.id)
      return
    }

    const payload = {
      kind: 'purchase_completed',
      order_id: orderFull.id,
      listing_id: orderFull.listing_id,
      listing_title: orderFull.listing_title ?? null,
      buyer_id: orderFull.buyer_id,
      buyer_username: buyerName,
      seller_id: orderFull.seller_id,
      amount_item_ore: orderFull.amount_item,
      ship_by_deadline: orderFull.ship_by_deadline ?? null,
    }

    const { error: dmErr } = await supabaseAdmin.from('direct_messages').insert({
      conversation_id: conv,
      sender_id: orderFull.buyer_id,
      message: JSON.stringify(payload),
      message_type: 'purchase_completed',
    })
    if (dmErr) {
      console.error('direct_messages insert failed (purchase_completed Köp nu):', dmErr)
    }
  } catch (e) {
    console.error('insertKopNuPurchaseCompletedDm failed:', e)
  }
}

/**
 * Invokes `book-marketplace-shipping` for a successfully-captured Köp nu
 * order. Looks up the order id either from intent.metadata.order_id (set
 * by create-marketplace-payment-intent) or by querying marketplace_orders
 * by stripe_payment_intent_id. Failures here never throw — booking is
 * also retryable from the admin manual-fallback flow.
 */
async function triggerShippingBooking(intent: Stripe.PaymentIntent) {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let orderId: string | null = intent.metadata?.order_id ?? null
    let existingShipmentId: string | null = null
    if (!orderId) {
      const { data } = await supabaseAdmin
        .from('marketplace_orders')
        .select('id, shipmondo_shipment_id')
        .eq('stripe_payment_intent_id', intent.id)
        .maybeSingle()
      orderId = (data?.id as string | undefined) ?? null
      existingShipmentId = (data?.shipmondo_shipment_id as string | undefined) ?? null
    } else {
      const { data } = await supabaseAdmin
        .from('marketplace_orders')
        .select('shipmondo_shipment_id')
        .eq('id', orderId)
        .maybeSingle()
      existingShipmentId = (data?.shipmondo_shipment_id as string | undefined) ?? null
    }
    if (!orderId) {
      console.warn('triggerShippingBooking: no orderId for intent', intent.id)
      return
    }
    if (existingShipmentId) {
      // Shipmondo-bokning finns redan — webhooken är en replay.
      console.log(`triggerShippingBooking: order ${orderId} has shipment ${existingShipmentId}, skipping`)
      return
    }

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
      console.warn('book-marketplace-shipping non-OK:', resp.status, text)
    }
  } catch (e) {
    console.warn('triggerShippingBooking failed:', (e as Error).message)
  }
}

async function handleLessonSucceeded(
  supabaseAdmin: ReturnType<typeof createClient>,
  intent: Stripe.PaymentIntent
) {
  const { error } = await supabaseAdmin
    .from('lesson_payments')
    .update({
      status: 'succeeded',
      stripe_charge_id: intent.latest_charge as string,
      updated_at: new Date().toISOString(),
    })
    .eq('stripe_payment_intent_id', intent.id)

  if (error) {
    console.error('Error updating payment:', error)
    return
  }

  console.log('Payment succeeded:', intent.id)

  const { data: payment } = await supabaseAdmin
    .from('lesson_payments')
    .select('trainer_id, student_id')
    .eq('stripe_payment_intent_id', intent.id)
    .single()

  if (!payment) return

  const { data: trainer } = await supabaseAdmin
    .from('trainer_profiles')
    .select('user_id')
    .eq('id', payment.trainer_id)
    .single()

  if (!trainer) return
  await supabaseAdmin.from('notifications').insert({
    user_id: trainer.user_id,
    type: 'payment_received',
    actor_id: payment.student_id,
    comment_text: 'Du har fått en ny betalning för en lektion!',
  })
}

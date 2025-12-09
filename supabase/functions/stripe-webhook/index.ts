import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from 'https://esm.sh/stripe@14.21.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

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
    const event = stripe.webhooks.constructEvent(body, signature, endpointSecret)
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    switch (event.type) {
      case 'payment_intent.succeeded': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent
        
        // Update payment status in database
        const { error } = await supabaseAdmin
          .from('lesson_payments')
          .update({
            status: 'succeeded',
            stripe_charge_id: paymentIntent.latest_charge as string,
            updated_at: new Date().toISOString(),
          })
          .eq('stripe_payment_intent_id', paymentIntent.id)

        if (error) {
          console.error('Error updating payment:', error)
        } else {
          console.log('Payment succeeded:', paymentIntent.id)
        }
        
        // Create a notification for the trainer
        const { data: payment } = await supabaseAdmin
          .from('lesson_payments')
          .select('trainer_id, student_id')
          .eq('stripe_payment_intent_id', paymentIntent.id)
          .single()
        
        if (payment) {
          // Get trainer's user_id
          const { data: trainer } = await supabaseAdmin
            .from('trainer_profiles')
            .select('user_id')
            .eq('id', payment.trainer_id)
            .single()
          
          if (trainer) {
            // Create notification for trainer
            await supabaseAdmin
              .from('notifications')
              .insert({
                user_id: trainer.user_id,
                type: 'payment_received',
                actor_id: payment.student_id,
                message: 'Du har fått en ny betalning för en lektion!',
              })
          }
        }
        break
      }
      
      case 'payment_intent.payment_failed': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent
        
        await supabaseAdmin
          .from('lesson_payments')
          .update({
            status: 'failed',
            updated_at: new Date().toISOString(),
          })
          .eq('stripe_payment_intent_id', paymentIntent.id)
        
        console.log('Payment failed:', paymentIntent.id)
        break
      }
      
      case 'charge.refunded': {
        const charge = event.data.object as Stripe.Charge
        
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
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err) {
    console.error('Webhook error:', err)
    return new Response(`Webhook Error: ${err.message}`, { status: 400 })
  }
})



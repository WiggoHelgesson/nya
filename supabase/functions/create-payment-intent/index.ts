import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from 'https://esm.sh/stripe@14.21.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
      apiVersion: '2023-10-16',
    })

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get authenticated user
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      throw new Error('Unauthorized')
    }

    const { trainer_id, amount } = await req.json()

    // Get trainer info
    const { data: trainer, error: trainerError } = await supabaseClient
      .from('trainer_profiles')
      .select('name, hourly_rate, user_id')
      .eq('id', trainer_id)
      .single()

    if (trainerError || !trainer) {
      throw new Error('Trainer not found')
    }

    // Calculate amount (trainer's hourly rate in öre/cents)
    const paymentAmount = amount || trainer.hourly_rate * 100

    // Create or get Stripe customer
    let customerId: string
    
    const { data: existingCustomer } = await supabaseClient
      .from('stripe_customers')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .single()

    if (existingCustomer?.stripe_customer_id) {
      customerId = existingCustomer.stripe_customer_id
    } else {
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: {
          supabase_user_id: user.id,
        },
      })
      customerId = customer.id
      
      // Save customer ID
      await supabaseClient
        .from('stripe_customers')
        .insert({ user_id: user.id, stripe_customer_id: customerId })
    }

    // Create ephemeral key for the customer
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: '2023-10-16' }
    )

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: paymentAmount,
      currency: 'sek',
      customer: customerId,
      metadata: {
        trainer_id: trainer_id,
        student_id: user.id,
        trainer_name: trainer.name,
      },
      automatic_payment_methods: {
        enabled: true,
      },
    })

    // Save pending payment
    await supabaseClient
      .from('lesson_payments')
      .insert({
        student_id: user.id,
        trainer_id: trainer_id,
        amount: paymentAmount,
        currency: 'sek',
        stripe_payment_intent_id: paymentIntent.id,
        status: 'pending',
      })

    return new Response(
      JSON.stringify({
        paymentIntent: paymentIntent.client_secret,
        ephemeralKey: ephemeralKey.secret,
        customer: customerId,
        publishableKey: 'pk_test_51SZ8AiDGa589KjR0xVDyspO7Uvet70EsdIMC4sERcpi67sRCsDfqtYlgzbPabtxgxQkvA5AXNM7HJc2HEYTUiZAk00nq6LUfLi',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})


import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from 'https://esm.sh/stripe@14.21.0'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Platform fee percentage (15%)
const PLATFORM_FEE_PERCENT = 15;

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

    // Get trainer info INCLUDING Stripe account
    const { data: trainer, error: trainerError } = await supabaseClient
      .from('trainer_profiles')
      .select('name, hourly_rate, user_id, stripe_account_id, stripe_charges_enabled')
      .eq('id', trainer_id)
      .single()

    if (trainerError || !trainer) {
      throw new Error('Trainer not found')
    }

    // Calculate amount (trainer's hourly rate in öre/cents)
    const paymentAmount = amount || trainer.hourly_rate * 100

    // Calculate platform fee (15%)
    const platformFee = Math.round(paymentAmount * (PLATFORM_FEE_PERCENT / 100));
    
    console.log(`Payment: ${paymentAmount} öre, Platform fee: ${platformFee} öre, Trainer gets: ${paymentAmount - platformFee} öre`);

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

    // Build payment intent options
    const paymentIntentOptions: Stripe.PaymentIntentCreateParams = {
      amount: paymentAmount,
      currency: 'sek',
      customer: customerId,
      metadata: {
        trainer_id: trainer_id,
        student_id: user.id,
        trainer_name: trainer.name,
        platform_fee_percent: String(PLATFORM_FEE_PERCENT),
      },
      automatic_payment_methods: {
        enabled: true,
      },
    };

    // If trainer has Stripe Connect account, use destination charges
    if (trainer.stripe_account_id && trainer.stripe_charges_enabled) {
      console.log(`Using destination charges to trainer account: ${trainer.stripe_account_id}`);
      paymentIntentOptions.application_fee_amount = platformFee;
      paymentIntentOptions.transfer_data = {
        destination: trainer.stripe_account_id,
      };
    } else {
      console.log('Trainer has no Stripe Connect account - payment goes to platform');
    }

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create(paymentIntentOptions)

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
        publishableKey: 'pk_live_51SZ8AiDGa589KjR0jMkTAI5BfGNf65qPzajTPVHNVYWsdhmgCPNgFoT13BlQkuMOPfBwBYodLhv3wUPSWpfx0Q2x00WI8tmMXu',
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


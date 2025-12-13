/**
 * CREATE LESSON CHECKOUT SESSION
 * ================================
 * Creates a Stripe Checkout session for booking a trainer lesson.
 * 
 * Uses Destination Charges to:
 * - Charge the student the full amount
 * - Automatically take 15% platform fee
 * - Transfer the rest to the trainer's Stripe account
 * 
 * Flow:
 * 1. Student selects lesson and clicks "Pay"
 * 2. This function creates a Checkout Session
 * 3. Student completes payment on Stripe-hosted page
 * 4. Money is split: 15% to platform, 85% to trainer
 * 5. Student is redirected back to app
 * 
 * Usage:
 * POST /create-lesson-checkout
 * Body: {
 *   bookingId: string,
 *   trainerId: string,
 *   studentId: string,
 *   amount: number (in SEK, e.g., 500 for 500 kr),
 *   trainerName: string,
 *   lessonDescription: string,
 *   studentEmail: string,
 *   successUrl?: string,
 *   cancelUrl?: string,
 * }
 */

import Stripe from 'https://esm.sh/stripe@14.14.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Platform fee percentage (15%)
const PLATFORM_FEE_PERCENT = 15;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // =========================================
    // 1. VALIDATE ENVIRONMENT
    // =========================================
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
    if (!stripeSecretKey) {
      throw new Error('STRIPE_SECRET_KEY is not set.');
    }

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2024-12-18.acacia',
      httpClient: Stripe.createFetchHttpClient(),
    });

    // =========================================
    // 2. PARSE REQUEST
    // =========================================
    const {
      bookingId,
      trainerId,
      studentId,
      amount,              // Amount in SEK (e.g., 500)
      trainerName,
      lessonDescription,
      studentEmail,
      successUrl = 'upanddown://payment-success',
      cancelUrl = 'upanddown://payment-cancel',
    } = await req.json();

    // Validate required fields
    if (!bookingId) throw new Error('bookingId is required');
    if (!trainerId) throw new Error('trainerId is required');
    if (!studentId) throw new Error('studentId is required');
    if (!amount || amount <= 0) throw new Error('amount must be positive');
    if (!trainerName) throw new Error('trainerName is required');

    console.log(`Creating checkout for booking ${bookingId}, amount: ${amount} SEK`);

    // =========================================
    // 3. GET TRAINER'S STRIPE ACCOUNT
    // =========================================
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Supabase environment variables not set');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: trainer, error: trainerError } = await supabase
      .from('trainer_profiles')
      .select('stripe_account_id, stripe_charges_enabled')
      .eq('id', trainerId)
      .single();

    if (trainerError || !trainer) {
      throw new Error(`Trainer not found: ${trainerError?.message}`);
    }

    if (!trainer.stripe_account_id) {
      throw new Error('Trainer has not connected their Stripe account for payouts');
    }

    if (!trainer.stripe_charges_enabled) {
      throw new Error('Trainer\'s Stripe account is not yet ready to receive payments');
    }

    // =========================================
    // 4. CALCULATE FEES
    // =========================================
    // Convert SEK to öre (cents)
    const amountInOre = Math.round(amount * 100);
    
    // Calculate platform fee (15%)
    const platformFeeOre = Math.round(amountInOre * (PLATFORM_FEE_PERCENT / 100));
    
    // Trainer receives the rest
    const trainerAmountOre = amountInOre - platformFeeOre;

    console.log(`Amount: ${amountInOre} öre, Platform fee: ${platformFeeOre} öre, Trainer: ${trainerAmountOre} öre`);

    // =========================================
    // 5. CREATE CHECKOUT SESSION
    // =========================================
    const session = await stripe.checkout.sessions.create({
      // Line items (what the customer sees)
      line_items: [
        {
          price_data: {
            currency: 'sek',
            unit_amount: amountInOre,
            product_data: {
              name: `Golflektion med ${trainerName}`,
              description: lessonDescription || 'Privat golflektion',
            },
          },
          quantity: 1,
        },
      ],
      
      // Payment mode
      mode: 'payment',
      
      // DESTINATION CHARGE CONFIGURATION
      // This is where the magic happens - money goes to trainer
      payment_intent_data: {
        // Platform takes 15% as application fee
        application_fee_amount: platformFeeOre,
        
        // Rest goes to trainer's Stripe account
        transfer_data: {
          destination: trainer.stripe_account_id,
        },
        
        // Metadata for tracking
        metadata: {
          booking_id: bookingId,
          trainer_id: trainerId,
          student_id: studentId,
          platform_fee_percent: PLATFORM_FEE_PERCENT.toString(),
        },
      },
      
      // Customer email (for receipt)
      customer_email: studentEmail,
      
      // Redirect URLs
      success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}&booking_id=${bookingId}`,
      cancel_url: `${cancelUrl}?booking_id=${bookingId}`,
      
      // Metadata on the session
      metadata: {
        booking_id: bookingId,
        trainer_id: trainerId,
        student_id: studentId,
      },
      
      // Swedish locale
      locale: 'sv',
    });

    console.log(`Created checkout session: ${session.id}`);

    // =========================================
    // 6. RECORD PAYMENT IN DATABASE
    // =========================================
    const { error: paymentError } = await supabase
      .from('booking_payments')
      .insert({
        booking_id: bookingId,
        trainer_id: trainerId,
        student_id: studentId,
        stripe_checkout_session_id: session.id,
        amount_total: amountInOre,
        amount_platform_fee: platformFeeOre,
        amount_trainer: trainerAmountOre,
        currency: 'sek',
        status: 'pending',
      });

    if (paymentError) {
      console.error('Failed to record payment:', paymentError);
      // Don't fail - checkout was created successfully
    }

    // =========================================
    // 7. RETURN CHECKOUT URL
    // =========================================
    return new Response(
      JSON.stringify({
        success: true,
        checkoutUrl: session.url,
        sessionId: session.id,
        breakdown: {
          totalAmount: amount,
          totalAmountOre: amountInOre,
          platformFee: platformFeeOre / 100,
          platformFeeOre: platformFeeOre,
          platformFeePercent: PLATFORM_FEE_PERCENT,
          trainerAmount: trainerAmountOre / 100,
          trainerAmountOre: trainerAmountOre,
          currency: 'SEK',
        },
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error creating checkout:', error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to create checkout session',
      }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});





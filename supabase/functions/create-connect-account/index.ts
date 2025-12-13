/**
 * CREATE STRIPE CONNECT ACCOUNT
 * ==============================
 * Creates a new Stripe Connect Express account for a trainer.
 * 
 * The platform is responsible for:
 * - Pricing and fee collection (application_fee)
 * - Losses, refunds, and chargebacks
 * 
 * Trainers get access to the Express dashboard for:
 * - Viewing their balance
 * - Managing payout schedule
 * - Viewing transaction history
 * 
 * Usage:
 * POST /create-connect-account
 * Body: { trainerId: string, email: string, country?: string }
 */

import Stripe from 'https://esm.sh/stripe@14.14.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

// CORS headers for browser requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // =========================================
    // 1. VALIDATE STRIPE SECRET KEY
    // =========================================
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
    if (!stripeSecretKey) {
      throw new Error(
        'STRIPE_SECRET_KEY is not set. ' +
        'Please add it to your Supabase Edge Function secrets: ' +
        'supabase secrets set STRIPE_SECRET_KEY=sk_live_xxx'
      );
    }

    // Initialize Stripe with the latest API version
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2024-12-18.acacia',
      httpClient: Stripe.createFetchHttpClient(),
    });

    // =========================================
    // 2. PARSE REQUEST BODY
    // =========================================
    const { trainerId, email, country = 'SE' } = await req.json();

    if (!trainerId) {
      throw new Error('trainerId is required');
    }
    if (!email) {
      throw new Error('email is required');
    }

    console.log(`Creating Connect account for trainer: ${trainerId}, email: ${email}`);

    // =========================================
    // 3. INITIALIZE SUPABASE CLIENT
    // =========================================
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Supabase environment variables not set');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // =========================================
    // 4. CHECK IF TRAINER ALREADY HAS ACCOUNT
    // =========================================
    const { data: trainer, error: trainerError } = await supabase
      .from('trainer_profiles')
      .select('stripe_account_id')
      .eq('id', trainerId)
      .single();

    if (trainerError) {
      throw new Error(`Failed to fetch trainer: ${trainerError.message}`);
    }

    // If trainer already has a Stripe account, return it
    if (trainer?.stripe_account_id) {
      console.log(`Trainer already has Stripe account: ${trainer.stripe_account_id}`);
      
      // Get current account status
      const account = await stripe.accounts.retrieve(trainer.stripe_account_id);
      
      return new Response(
        JSON.stringify({
          success: true,
          accountId: trainer.stripe_account_id,
          alreadyExists: true,
          chargesEnabled: account.charges_enabled,
          payoutsEnabled: account.payouts_enabled,
          detailsSubmitted: account.details_submitted,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // =========================================
    // 5. CREATE STRIPE CONNECT ACCOUNT
    // =========================================
    // Using controller properties (NOT top-level type)
    // This creates an Express-like account where:
    // - Platform handles fees and losses
    // - Trainer gets Express dashboard access
    const account = await stripe.accounts.create({
      // Account holder's email
      email: email,
      
      // Country for the account (affects available features)
      country: country,
      
      // Controller settings (replaces deprecated 'type' parameter)
      controller: {
        // Platform is responsible for pricing and fee collection
        fees: {
          payer: 'application' as const,
        },
        // Platform is responsible for losses / refunds / chargebacks
        losses: {
          payments: 'application' as const,
        },
        // Give trainers access to the Express dashboard
        stripe_dashboard: {
          type: 'express' as const,
        },
      },
      
      // Capabilities we need
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      
      // Business type (individual for most trainers)
      business_type: 'individual',
      
      // Metadata for our reference
      metadata: {
        trainer_id: trainerId,
        platform: 'upanddown',
      },
    });

    console.log(`Created Stripe Connect account: ${account.id}`);

    // =========================================
    // 6. SAVE ACCOUNT ID TO DATABASE
    // =========================================
    const { error: updateError } = await supabase
      .from('trainer_profiles')
      .update({
        stripe_account_id: account.id,
        stripe_onboarding_complete: false,
        stripe_payouts_enabled: false,
        stripe_charges_enabled: false,
      })
      .eq('id', trainerId);

    if (updateError) {
      // Log but don't fail - account was created successfully
      console.error(`Failed to update trainer profile: ${updateError.message}`);
    }

    // =========================================
    // 7. RETURN SUCCESS RESPONSE
    // =========================================
    return new Response(
      JSON.stringify({
        success: true,
        accountId: account.id,
        alreadyExists: false,
        chargesEnabled: account.charges_enabled,
        payoutsEnabled: account.payouts_enabled,
        detailsSubmitted: account.details_submitted,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error creating Connect account:', error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to create Connect account',
      }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});





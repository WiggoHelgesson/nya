/**
 * CREATE STRIPE ONBOARDING LINK
 * ==============================
 * Generates an Account Link for a trainer to complete their Stripe onboarding.
 * 
 * The trainer will be redirected to Stripe's hosted onboarding flow where they:
 * - Verify their identity
 * - Add bank account for payouts
 * - Provide business/tax information
 * 
 * After completion, they're redirected back to the app via deep link.
 * 
 * Usage:
 * POST /create-onboarding-link
 * Body: { stripeAccountId: string, refreshUrl?: string, returnUrl?: string }
 */

import Stripe from 'https://esm.sh/stripe@14.14.0?target=deno';

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
        'Please add it to your Supabase Edge Function secrets.'
      );
    }

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2024-12-18.acacia',
      httpClient: Stripe.createFetchHttpClient(),
    });

    // =========================================
    // 2. PARSE REQUEST BODY
    // =========================================
    const { 
      stripeAccountId,
      // Stripe requires HTTPS URLs - we'll use a simple success page
      // that can redirect to the app via universal links or show a success message
      refreshUrl = 'https://xebatkodviqgkpsbyuiv.supabase.co/functions/v1/stripe-redirect?status=refresh',
      returnUrl = 'https://xebatkodviqgkpsbyuiv.supabase.co/functions/v1/stripe-redirect?status=success',
    } = await req.json();

    if (!stripeAccountId) {
      throw new Error('stripeAccountId is required');
    }

    console.log(`Creating onboarding link for account: ${stripeAccountId}`);

    // =========================================
    // 3. VERIFY ACCOUNT EXISTS
    // =========================================
    let account;
    try {
      account = await stripe.accounts.retrieve(stripeAccountId);
    } catch (e) {
      throw new Error(`Invalid Stripe account ID: ${stripeAccountId}`);
    }

    // If already fully onboarded, return status instead
    if (account.details_submitted && account.charges_enabled && account.payouts_enabled) {
      return new Response(
        JSON.stringify({
          success: true,
          alreadyComplete: true,
          message: 'Account is already fully onboarded',
          chargesEnabled: account.charges_enabled,
          payoutsEnabled: account.payouts_enabled,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // =========================================
    // 4. CREATE ACCOUNT LINK
    // =========================================
    // Account Links are the recommended way to onboard Express accounts
    // They expire after a short time for security
    const accountLink = await stripe.accountLinks.create({
      account: stripeAccountId,
      
      // URL to redirect if link expires or user needs to restart
      refresh_url: refreshUrl,
      
      // URL to redirect after successful onboarding
      return_url: returnUrl,
      
      // Type of link - account_onboarding for initial setup
      type: 'account_onboarding',
      
      // Collect all required information
      collect: 'eventually_due',
    });

    console.log(`Created onboarding link, expires at: ${new Date(accountLink.expires_at * 1000).toISOString()}`);

    // =========================================
    // 5. RETURN ONBOARDING URL
    // =========================================
    return new Response(
      JSON.stringify({
        success: true,
        url: accountLink.url,
        expiresAt: accountLink.expires_at,
        // Include current status for UI
        currentStatus: {
          chargesEnabled: account.charges_enabled,
          payoutsEnabled: account.payouts_enabled,
          detailsSubmitted: account.details_submitted,
        },
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error creating onboarding link:', error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to create onboarding link',
      }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});


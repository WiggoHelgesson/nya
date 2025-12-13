/**
 * GET STRIPE ACCOUNT STATUS
 * ==========================
 * Retrieves the current status of a Stripe Connect account.
 * 
 * Used to check:
 * - Whether onboarding is complete
 * - If charges can be processed
 * - If payouts are enabled
 * - Any outstanding requirements
 * 
 * Also updates the trainer_profiles table with current status.
 * 
 * Usage:
 * POST /get-account-status
 * Body: { stripeAccountId: string, trainerId?: string }
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
      throw new Error('STRIPE_SECRET_KEY is not set.');
    }

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2024-12-18.acacia',
      httpClient: Stripe.createFetchHttpClient(),
    });

    // =========================================
    // 2. PARSE REQUEST BODY
    // =========================================
    const { stripeAccountId, trainerId } = await req.json();

    if (!stripeAccountId) {
      throw new Error('stripeAccountId is required');
    }

    console.log(`Getting status for account: ${stripeAccountId}`);

    // =========================================
    // 3. RETRIEVE ACCOUNT FROM STRIPE
    // =========================================
    const account = await stripe.accounts.retrieve(stripeAccountId);

    // =========================================
    // 4. DETERMINE ONBOARDING STATUS
    // =========================================
    const isFullyOnboarded = 
      account.details_submitted && 
      account.charges_enabled && 
      account.payouts_enabled;

    // Get any outstanding requirements
    const requirements = account.requirements || {};
    const currentlyDue = requirements.currently_due || [];
    const eventuallyDue = requirements.eventually_due || [];
    const pastDue = requirements.past_due || [];

    // Determine a human-readable status
    let statusMessage = 'Okänd status';
    let statusType = 'unknown';

    if (isFullyOnboarded) {
      statusMessage = 'Konto aktivt - redo att ta emot betalningar';
      statusType = 'active';
    } else if (!account.details_submitted) {
      statusMessage = 'Väntar på att du slutför registreringen';
      statusType = 'pending_onboarding';
    } else if (pastDue.length > 0) {
      statusMessage = 'Åtgärd krävs - information saknas';
      statusType = 'action_required';
    } else if (currentlyDue.length > 0) {
      statusMessage = 'Verifiering pågår';
      statusType = 'pending_verification';
    } else if (!account.charges_enabled) {
      statusMessage = 'Väntar på aktivering av betalningar';
      statusType = 'pending_charges';
    } else if (!account.payouts_enabled) {
      statusMessage = 'Väntar på aktivering av utbetalningar';
      statusType = 'pending_payouts';
    }

    // =========================================
    // 5. UPDATE DATABASE (if trainerId provided)
    // =========================================
    if (trainerId) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL');
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
      
      if (supabaseUrl && supabaseServiceKey) {
        const supabase = createClient(supabaseUrl, supabaseServiceKey);
        
        await supabase
          .from('trainer_profiles')
          .update({
            stripe_onboarding_complete: account.details_submitted,
            stripe_payouts_enabled: account.payouts_enabled,
            stripe_charges_enabled: account.charges_enabled,
          })
          .eq('id', trainerId);
        
        console.log(`Updated trainer profile ${trainerId} with Stripe status`);
      }
    }

    // =========================================
    // 6. GET BALANCE (if account is active)
    // =========================================
    let balance = null;
    if (account.charges_enabled) {
      try {
        const stripeBalance = await stripe.balance.retrieve({
          stripeAccount: stripeAccountId,
        });
        
        balance = {
          available: stripeBalance.available.map(b => ({
            amount: b.amount,
            currency: b.currency,
          })),
          pending: stripeBalance.pending.map(b => ({
            amount: b.amount,
            currency: b.currency,
          })),
        };
      } catch (e) {
        console.log('Could not retrieve balance:', e.message);
      }
    }

    // =========================================
    // 7. RETURN STATUS
    // =========================================
    return new Response(
      JSON.stringify({
        success: true,
        accountId: stripeAccountId,
        
        // Core status flags
        detailsSubmitted: account.details_submitted,
        chargesEnabled: account.charges_enabled,
        payoutsEnabled: account.payouts_enabled,
        isFullyOnboarded,
        
        // Human-readable status
        statusMessage,
        statusType,
        
        // Requirements (if any)
        requirements: {
          currentlyDue,
          eventuallyDue,
          pastDue,
          disabledReason: requirements.disabled_reason,
        },
        
        // Balance (if available)
        balance,
        
        // Account metadata
        country: account.country,
        defaultCurrency: account.default_currency,
        email: account.email,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error getting account status:', error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to get account status',
      }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});





/**
 * CREATE SELLER STRIPE CONNECT ACCOUNT
 * ====================================
 * Creates an Express Stripe Connect account for a community
 * marketplace seller (any user in `public.profiles`).
 *
 * Platform responsibilities:
 * - Fee collection (application_fee)
 * - Losses, refunds, chargebacks
 *
 * Usage:
 * POST /create-seller-connect-account
 * Body: { userId: string, email: string, country?: string }
 */

import Stripe from 'https://esm.sh/stripe@14.14.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
    if (!stripeSecretKey) {
      throw new Error('STRIPE_SECRET_KEY is not set');
    }

    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2024-12-18.acacia',
      httpClient: Stripe.createFetchHttpClient(),
    });

    const { userId, email, country = 'SE' } = await req.json();
    if (!userId) throw new Error('userId is required');
    if (!email) throw new Error('email is required');

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Supabase environment variables not set');
    }
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Reuse existing account if one is already on file
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('stripe_account_id')
      .eq('id', userId)
      .single();

    if (profileError) {
      throw new Error(`Failed to fetch profile: ${profileError.message}`);
    }

    if (profile?.stripe_account_id) {
      const account = await stripe.accounts.retrieve(profile.stripe_account_id);

      // Keep cached flags in sync
      await supabase
        .from('profiles')
        .update({
          stripe_charges_enabled: account.charges_enabled,
          stripe_payouts_enabled: account.payouts_enabled,
          stripe_onboarding_complete: account.details_submitted,
        })
        .eq('id', userId);

      return new Response(
        JSON.stringify({
          success: true,
          accountId: profile.stripe_account_id,
          alreadyExists: true,
          chargesEnabled: account.charges_enabled,
          payoutsEnabled: account.payouts_enabled,
          detailsSubmitted: account.details_submitted,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const account = await stripe.accounts.create({
      email,
      country,
      controller: {
        fees: { payer: 'application' as const },
        losses: { payments: 'application' as const },
        stripe_dashboard: { type: 'express' as const },
      },
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      business_type: 'individual',
      metadata: {
        user_id: userId,
        platform: 'upanddown',
        role: 'marketplace_seller',
      },
    });

    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        stripe_account_id: account.id,
        stripe_onboarding_complete: false,
        stripe_payouts_enabled: false,
        stripe_charges_enabled: false,
      })
      .eq('id', userId);

    if (updateError) {
      console.error(`Failed to update profile: ${updateError.message}`);
    }

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
    console.error('Error creating seller Connect account:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to create Connect account',
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

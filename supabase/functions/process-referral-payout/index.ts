// Supabase Edge Function for processing referral payouts via Stripe Connect
// Deploy with: supabase functions deploy process-referral-payout

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@13.6.0?target=deno"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')!

    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    const stripe = new Stripe(stripeSecretKey, {
      apiVersion: '2023-10-16',
    })

    // Get the authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    // Verify the user
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    
    if (authError || !user) {
      throw new Error('Unauthorized')
    }

    const { action, payoutId } = await req.json()

    switch (action) {
      case 'create_connect_account': {
        // Create a Stripe Connect Express account for the user
        const account = await stripe.accounts.create({
          type: 'express',
          country: 'SE',
          email: user.email,
          capabilities: {
            transfers: { requested: true },
          },
          metadata: {
            user_id: user.id,
          },
        })

        // Save the Stripe account ID to the user's profile
        await supabase
          .from('profiles')
          .update({ stripe_connect_id: account.id })
          .eq('id', user.id)

        // Create an account link for onboarding
        const accountLink = await stripe.accountLinks.create({
          account: account.id,
          refresh_url: 'upanddown://stripe-refresh',
          return_url: 'upanddown://stripe-return',
          type: 'account_onboarding',
        })

        return new Response(
          JSON.stringify({ 
            success: true, 
            accountId: account.id,
            onboardingUrl: accountLink.url 
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'get_onboarding_link': {
        // Get the user's Stripe Connect ID
        const { data: profile } = await supabase
          .from('profiles')
          .select('stripe_connect_id')
          .eq('id', user.id)
          .single()

        if (!profile?.stripe_connect_id) {
          throw new Error('No Stripe Connect account found')
        }

        const accountLink = await stripe.accountLinks.create({
          account: profile.stripe_connect_id,
          refresh_url: 'upanddown://stripe-refresh',
          return_url: 'upanddown://stripe-return',
          type: 'account_onboarding',
        })

        return new Response(
          JSON.stringify({ success: true, onboardingUrl: accountLink.url }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'check_account_status': {
        // Check if the user's Stripe account is ready for payouts
        const { data: profile } = await supabase
          .from('profiles')
          .select('stripe_connect_id')
          .eq('id', user.id)
          .single()

        if (!profile?.stripe_connect_id) {
          return new Response(
            JSON.stringify({ 
              success: true, 
              hasAccount: false,
              canReceivePayouts: false 
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }

        const account = await stripe.accounts.retrieve(profile.stripe_connect_id)

        return new Response(
          JSON.stringify({ 
            success: true,
            hasAccount: true,
            canReceivePayouts: account.payouts_enabled,
            detailsSubmitted: account.details_submitted,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      case 'process_payout': {
        if (!payoutId) {
          throw new Error('Missing payout ID')
        }

        // Get the payout request
        const { data: payout, error: payoutError } = await supabase
          .from('referral_payouts')
          .select('*')
          .eq('id', payoutId)
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .single()

        if (payoutError || !payout) {
          throw new Error('Payout not found or already processed')
        }

        // Get the user's Stripe Connect ID
        const { data: profile } = await supabase
          .from('profiles')
          .select('stripe_connect_id')
          .eq('id', user.id)
          .single()

        if (!profile?.stripe_connect_id) {
          throw new Error('No Stripe Connect account found. Please set up your payout account first.')
        }

        // Check if account can receive payouts
        const account = await stripe.accounts.retrieve(profile.stripe_connect_id)
        if (!account.payouts_enabled) {
          throw new Error('Your Stripe account is not yet ready to receive payouts. Please complete the onboarding.')
        }

        // Update payout status to processing
        await supabase
          .from('referral_payouts')
          .update({ status: 'processing' })
          .eq('id', payoutId)

        try {
          // Convert SEK to öre (Stripe uses smallest currency unit)
          const amountInOre = Math.round(payout.amount_sek * 100)

          // Create a transfer to the connected account
          const transfer = await stripe.transfers.create({
            amount: amountInOre,
            currency: 'sek',
            destination: profile.stripe_connect_id,
            metadata: {
              payout_id: payoutId,
              user_id: user.id,
            },
          })

          // Update payout as completed
          await supabase
            .from('referral_payouts')
            .update({ 
              status: 'completed',
              stripe_transfer_id: transfer.id 
            })
            .eq('id', payoutId)

          return new Response(
            JSON.stringify({ 
              success: true, 
              transferId: transfer.id,
              amount: payout.amount_sek 
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        } catch (stripeError) {
          // Revert status to pending if transfer failed
          await supabase
            .from('referral_payouts')
            .update({ status: 'failed' })
            .eq('id', payoutId)

          throw stripeError
        }
      }

      default:
        throw new Error('Invalid action')
    }
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})




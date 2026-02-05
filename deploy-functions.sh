#!/bin/bash

# Deploy all Supabase Edge Functions
# Usage: ./deploy-functions.sh

echo "🚀 Deploying all Supabase Edge Functions..."
echo ""

# Array of all functions
functions=(
  "accept-coach-invitation"
  "decline-coach-invitation"
  "send-coach-invitation"
  "send-cheer-notification"
  "send-push-notification"
  "notify-active-session"
  "create-connect-account"
  "create-lesson-checkout"
  "create-onboarding-link"
  "create-payment-intent"
  "delete-user"
  "get-account-status"
  "process-referral-payout"
  "strava-callback"
  "stripe-redirect"
  "stripe-webhook"
  "terra-webhook"
)

# Deploy each function
for func in "${functions[@]}"
do
  echo "📦 Deploying $func..."
  supabase functions deploy "$func" --no-verify-jwt
  
  if [ $? -eq 0 ]; then
    echo "✅ $func deployed successfully!"
  else
    echo "❌ Failed to deploy $func"
  fi
  echo ""
done

echo "🎉 All functions deployed!"

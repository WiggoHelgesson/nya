#!/usr/bin/env bash
# Deploy script for the marketplace Stripe Connect integration.
#
# Usage:
#   cd /path/to/riktiga
#   ./supabase/deploy_marketplace_stripe.sh [--project-ref <ref>]
#
# Requires:
#   - supabase CLI (https://supabase.com/docs/guides/cli) logged in via `supabase login`
#   - psql available and a SUPABASE_DB_URL env var pointing at the project's Postgres
#     connection string (or run the SQL migration manually via the dashboard).
#   - STRIPE_SECRET_KEY already configured as an edge function secret
#     (the existing create-connect-account uses it, so this should already be set).
#
# This script:
#   1. Applies the SQL migration that adds marketplace_orders + seller Stripe
#      columns on profiles + sold_at on consignment_submissions.
#   2. Deploys the 3 new marketplace edge functions and redeploys the two
#      existing functions that were extended to handle marketplace flows.

set -euo pipefail

PROJECT_REF=""
if [[ "${1:-}" == "--project-ref" && -n "${2:-}" ]]; then
  PROJECT_REF="$2"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL_FILE="$ROOT/supabase/sql/marketplace_stripe_connect.sql"
OFFERS_SQL_FILE="$ROOT/supabase/sql/listing_offers.sql"
SELLER_PICKUP_SQL_FILE="$ROOT/supabase/sql/seller_pickup_addresses.sql"
ORDERS_SHIPPING_SQL_FILE="$ROOT/supabase/sql/marketplace_orders_shipping_extras.sql"
OFFERS_SHIPPING_SQL_FILE="$ROOT/supabase/sql/listing_offers_shipping_choice.sql"
LISTING_SNAPSHOT_SQL_FILE="$ROOT/supabase/sql/marketplace_orders_listing_snapshot.sql"
SHIPMONDO_RENAME_SQL_FILE="$ROOT/supabase/sql/marketplace_orders_shipmondo_rename.sql"
BUYER_PHONE_SQL_FILE="$ROOT/supabase/sql/marketplace_orders_buyer_phone.sql"
PHASE1_SELLER_ORDER_SQL_FILE="$ROOT/supabase/sql/marketplace_phase1_seller_order_flow.sql"
PHASE2_SELLER_FLOW_SQL_FILE="$ROOT/supabase/sql/marketplace_phase2_seller_flow.sql"
ORDERS_IS_TEST_SQL_FILE="$ROOT/supabase/sql/marketplace_orders_is_test.sql"
# Köp nu / listing-chat: en tråd per (köpare, säljare, annons) + RPC med listing_id
# (behövs för purchase_completed-DM efter webhook — kör om du bara kört notifications_type_check.)
DIRECT_CONV_LISTING_SQL_FILE="$ROOT/supabase/sql/direct_conversations_listing_id.sql"
NOTIFICATIONS_MARKETPLACE_TYPES_SQL_FILE="$ROOT/supabase/sql/notifications_type_check_marketplace.sql"

apply_sql () {
  local file="$1"
  echo "==> Applying SQL migration: $file"
  if [[ -n "${SUPABASE_DB_URL:-}" ]]; then
    psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$file"
  else
    echo "   SUPABASE_DB_URL not set."
    echo "   Run this SQL manually via the Supabase SQL editor:"
    echo "     $file"
  fi
}

apply_sql "$SQL_FILE"
apply_sql "$OFFERS_SQL_FILE"
apply_sql "$SELLER_PICKUP_SQL_FILE"
apply_sql "$ORDERS_SHIPPING_SQL_FILE"
apply_sql "$OFFERS_SHIPPING_SQL_FILE"
apply_sql "$LISTING_SNAPSHOT_SQL_FILE"
apply_sql "$SHIPMONDO_RENAME_SQL_FILE"
apply_sql "$BUYER_PHONE_SQL_FILE"
apply_sql "$PHASE1_SELLER_ORDER_SQL_FILE"
apply_sql "$PHASE2_SELLER_FLOW_SQL_FILE"
apply_sql "$ORDERS_IS_TEST_SQL_FILE"

# Marketplace notiser (CHECK tillåter marketplace_*) + konversationer kopplade till annons
apply_sql "$NOTIFICATIONS_MARKETPLACE_TYPES_SQL_FILE"
apply_sql "$DIRECT_CONV_LISTING_SQL_FILE"

deploy_function () {
  local name="$1"
  echo "==> Deploying edge function: $name"
  if [[ -n "$PROJECT_REF" ]]; then
    supabase functions deploy "$name" --project-ref "$PROJECT_REF"
  else
    supabase functions deploy "$name"
  fi
}

deploy_public_function () {
  local name="$1"
  echo "==> Deploying public webhook function (no JWT): $name"
  if [[ -n "$PROJECT_REF" ]]; then
    supabase functions deploy "$name" --no-verify-jwt --project-ref "$PROJECT_REF"
  else
    supabase functions deploy "$name" --no-verify-jwt
  fi
}

# New marketplace-specific functions
deploy_function create-seller-connect-account
deploy_function create-marketplace-payment-intent
deploy_function process-pending-seller-payouts

# Price offer ("prisförslag") functions
deploy_function create-marketplace-offer-intent
deploy_function accept-marketplace-offer
deploy_function decline-marketplace-offer
deploy_function finalize-marketplace-offer

# Shipmondo multi-carrier shipping
deploy_function get-marketplace-shipping-rates
deploy_function list-marketplace-service-points
deploy_function book-marketplace-shipping
deploy_public_function shipmondo-webhook
deploy_function poll-shipmondo-tracking
deploy_function refresh-shipmondo-label
deploy_function test-shipmondo-label

deploy_function mark-marketplace-order-packed
deploy_function mark-marketplace-order-shipped
deploy_function process-marketplace-deadlines
deploy_function simulate-marketplace-purchase

# Extended functions (support both trainer + marketplace seller flows now)
deploy_function get-account-status
deploy_public_function stripe-webhook

echo ""
echo "All marketplace Stripe Connect pieces deployed."
echo "Stripe webhook signing: Supabase secret STRIPE_WEBHOOK_SECRET must match the"
echo "Signing secret (whsec_...) shown in Stripe Dashboard for THIS endpoint — live vs test."
echo "If marketplace purchases succeed in Stripe but orders stay pending / listings unsold,"
echo "check Dashboard → Developers → Webhooks → delivery logs for payment_intent.succeeded."
echo ""
echo "Reminder: ensure the Stripe webhook endpoint in the Stripe dashboard is"
echo "pointing at the 'stripe-webhook' function URL and that it's subscribed to:"
echo "  - payment_intent.succeeded"
echo "  - payment_intent.canceled"
echo "  - payment_intent.payment_failed"
echo "  - charge.refunded"
echo "  - account.updated"
echo ""
echo "Shipmondo setup:"
echo "  - Set secrets: SHIPMONDO_API_USER, SHIPMONDO_API_KEY, SHIPMONDO_WEBHOOK_SECRET (webhook JWT key)."
echo "  - Optional: SHIPMONDO_OWN_AGREEMENT (true/false — måste matcha era produkters «own agreement» i Shipmondo),"
echo "    SHIPMONDO_BASE_URL (prod default: https://app.shipmondo.com/api/public/v3; sandbox: https://sandbox.shipmondo.com/api/public/v3),"
echo "    SHIPMONDO_PRODUCT_PRICES_ORE_JSON, SHIPMONDO_DEFAULT_SERVICE_CODES, SHIPMONDO_SHIPMENTS_CREATE_EXTRAS_JSON."
echo "  - Run supabase/sql/shipmondo_polling_cron.sql after vault secrets shipmondo_poll_url + shipmondo_poll_key."
echo "  - Point Shipmondo webhooks at shipmondo-webhook (JWT disabled; signature/header verified in function code)."
echo "  - Verify the 'shipping-labels' Storage bucket exists and is private."
echo ""
echo "Listing-DM efter köp (om säljaren inte får systemchatten \"Köp genomfört\"):"
echo "  SQL (Supabase SQL Editor om du inte kör detta skript med SUPABASE_DB_URL):"
echo "    $DIRECT_CONV_LISTING_SQL_FILE"
echo "  Sedan redeploy: stripe-webhook + finalize-marketplace-offer (redan i detta skript)."

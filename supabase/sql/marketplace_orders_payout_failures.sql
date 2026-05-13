-- =====================================================================
-- MARKETPLACE ORDERS: PAYOUT FAILURE TRACKING
-- ---------------------------------------------------------------------
-- När `stripe.transfers.create` failar i `approve-marketplace-order`
-- eller `process-marketplace-deadlines` stämplar vi felet på ordern
-- så `process-pending-seller-payouts` kan retrya med backoff och
-- admin-vyn kan visa fastnade payouts.
--
--  payout_failed_at      — senaste fel-tillfället
--  payout_failure_reason — Stripe-felmeddelandet (max 500 tecken)
-- =====================================================================

ALTER TABLE public.marketplace_orders
    ADD COLUMN IF NOT EXISTS payout_failed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS payout_failure_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_payout_failed
    ON public.marketplace_orders (payout_failed_at)
    WHERE payout_failed_at IS NOT NULL AND released_at IS NULL;

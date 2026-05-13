-- =====================================================
-- MARKETPLACE STRIPE CONNECT
-- =====================================================
-- Enables Stripe Connect (Express) payouts for community
-- sellers. Buyers pay via Stripe PaymentSheet, sellers
-- receive 100 % of priceSEK, platform keeps 5 % + 7.50 kr
-- as buyer-protection fee.
--
-- Onboarding is "soft prompt": a listing can go live
-- without a Stripe account. If a buyer purchases before
-- the seller onboards, the charge is held on the platform
-- and transferred manually via `process-pending-seller-payouts`
-- once onboarding is complete.
-- =====================================================

BEGIN;

-- 1. Seller Stripe Connect fields on profiles ---------------------

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS stripe_account_id TEXT,
    ADD COLUMN IF NOT EXISTS stripe_onboarding_complete BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS stripe_charges_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS stripe_payouts_enabled BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_profiles_stripe_account_id
    ON public.profiles (stripe_account_id);

COMMENT ON COLUMN public.profiles.stripe_account_id IS 'Stripe Connect account ID (acct_...) for marketplace seller payouts';
COMMENT ON COLUMN public.profiles.stripe_onboarding_complete IS 'Whether the seller completed Stripe Express onboarding';
COMMENT ON COLUMN public.profiles.stripe_charges_enabled IS 'Whether Stripe can accept charges routed to this account';
COMMENT ON COLUMN public.profiles.stripe_payouts_enabled IS 'Whether Stripe can pay out to this account';

-- 2. Sold-flag on consignment_submissions -------------------------

ALTER TABLE public.consignment_submissions
    ADD COLUMN IF NOT EXISTS sold_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS sold_order_id UUID;

CREATE INDEX IF NOT EXISTS idx_consignment_submissions_sold_at
    ON public.consignment_submissions (sold_at);

-- 3. Marketplace orders table -------------------------------------

CREATE TABLE IF NOT EXISTS public.marketplace_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES public.consignment_submissions (id) ON DELETE RESTRICT,
    buyer_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    seller_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,

    -- Stripe identifiers
    stripe_payment_intent_id TEXT,
    stripe_charge_id TEXT,
    stripe_transfer_id TEXT,
    stripe_customer_id TEXT,

    -- Amounts in öre (smallest currency unit)
    amount_item INTEGER NOT NULL,              -- priceSEK * 100
    amount_platform_fee INTEGER NOT NULL,      -- 5 % of item + 750 öre
    amount_buyer_total INTEGER NOT NULL,       -- item + platform_fee
    amount_seller_payout INTEGER NOT NULL,     -- = amount_item
    currency TEXT NOT NULL DEFAULT 'sek',

    -- Lifecycle
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded', 'held_awaiting_seller', 'released')),
    is_held BOOLEAN NOT NULL DEFAULT FALSE,
    released_at TIMESTAMPTZ,

    -- Buyer shipping info (seller packs & ships)
    buyer_shipping_name TEXT,
    buyer_shipping_address TEXT,
    buyer_shipping_postal TEXT,
    buyer_shipping_city TEXT,
    buyer_email TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_listing_id ON public.marketplace_orders (listing_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_buyer_id ON public.marketplace_orders (buyer_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_seller_id ON public.marketplace_orders (seller_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_status ON public.marketplace_orders (status);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_is_held ON public.marketplace_orders (is_held);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_payment_intent ON public.marketplace_orders (stripe_payment_intent_id);

COMMENT ON TABLE public.marketplace_orders IS 'Tracks all marketplace purchases paid via Stripe Connect (destination charges or held platform charges).';

ALTER TABLE public.marketplace_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS marketplace_orders_select_own ON public.marketplace_orders;
CREATE POLICY marketplace_orders_select_own ON public.marketplace_orders
    FOR SELECT TO authenticated
    USING (
        auth.uid() = buyer_id
        OR auth.uid() = seller_id
        OR public.is_admin()
    );

-- Inserts and updates are performed exclusively by the service role
-- (edge functions) so no public INSERT/UPDATE/DELETE policies are added.

-- 4. Helper view for pending held payouts --------------------------

CREATE OR REPLACE VIEW public.seller_pending_held_orders AS
    SELECT *
    FROM public.marketplace_orders
    WHERE is_held = TRUE
      AND status = 'succeeded'
      AND stripe_transfer_id IS NULL;

COMMENT ON VIEW public.seller_pending_held_orders IS
    'Marketplace orders whose payment succeeded but whose transfer is pending the seller completing Stripe onboarding.';

COMMIT;

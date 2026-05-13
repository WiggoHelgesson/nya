-- =====================================================
-- LISTING OFFERS (Prisförslag)
-- =====================================================
-- Buyer-made price offers on community listings. A
-- PaymentIntent is created with capture_method='manual'
-- so the buyer's card is authorised but no money moves
-- until the seller accepts.
--
-- Flow:
--   pending   → buyer submitted, card authorised
--   accepted  → seller accepted, capture initiated
--   captured  → webhook confirmed payment_intent.succeeded
--   declined  → seller declined, PI cancelled
--   cancelled → auto-declined (another offer accepted) or PI cancelled
--   expired   → older than expires_at (future cron)
--   refunded  → post-capture refund
-- =====================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.listing_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    listing_id UUID NOT NULL REFERENCES public.consignment_submissions (id) ON DELETE CASCADE,
    buyer_id   UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
    seller_id  UUID NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,

    offered_price_sek INTEGER NOT NULL CHECK (offered_price_sek > 0),
    message TEXT,

    -- Amounts in öre, mirroring marketplace_orders conventions
    amount_item_ore          INTEGER NOT NULL,
    amount_platform_fee_ore  INTEGER NOT NULL,
    amount_shipping_ore      INTEGER NOT NULL,
    amount_buyer_total_ore   INTEGER NOT NULL,
    amount_seller_payout_ore INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'sek',

    -- Stripe
    stripe_payment_intent_id TEXT,
    stripe_customer_id TEXT,

    -- Buyer shipping (stored on offer so it can be moved onto the
    -- marketplace_orders row when the seller accepts).
    buyer_email TEXT,
    buyer_shipping_name    TEXT,
    buyer_shipping_address TEXT,
    buyer_shipping_postal  TEXT,
    buyer_shipping_city    TEXT,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled',
                          'expired', 'captured', 'refunded')),

    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    captured_at  TIMESTAMPTZ,
    expires_at   TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '72 hours')
);

CREATE INDEX IF NOT EXISTS idx_listing_offers_listing_status
    ON public.listing_offers (listing_id, status);
CREATE INDEX IF NOT EXISTS idx_listing_offers_seller_status
    ON public.listing_offers (seller_id, status);
CREATE INDEX IF NOT EXISTS idx_listing_offers_buyer
    ON public.listing_offers (buyer_id);
CREATE INDEX IF NOT EXISTS idx_listing_offers_payment_intent
    ON public.listing_offers (stripe_payment_intent_id);

COMMENT ON TABLE public.listing_offers IS
    'Buyer price offers ("prisförslag") with Stripe capture_method=manual PaymentIntents held until the seller accepts.';

ALTER TABLE public.listing_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS listing_offers_select_own ON public.listing_offers;
CREATE POLICY listing_offers_select_own ON public.listing_offers
    FOR SELECT TO authenticated
    USING (
        auth.uid() = buyer_id
        OR auth.uid() = seller_id
        OR public.is_admin()
    );

-- Inserts and updates are performed exclusively by the service role
-- (edge functions create-marketplace-offer-intent /
-- accept-marketplace-offer / decline-marketplace-offer), so no public
-- INSERT/UPDATE/DELETE policies are added here.

COMMIT;

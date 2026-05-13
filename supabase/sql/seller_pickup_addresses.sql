-- =====================================================
-- SELLER PICKUP ADDRESSES (Sendify shipping integration)
-- =====================================================
-- One row per seller with the address Sendify uses as
-- "from_address" when booking a shipment after a buyer
-- finalises a price offer. We collect this lazily — the
-- seller is prompted in `MyListingsView` the first time
-- they accept an offer.
--
-- The address is also reused as a default for future
-- bookings, but the seller can update it any time from
-- their profile / consignment-admin view.
-- =====================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.seller_pickup_addresses (
    user_id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    full_name   TEXT NOT NULL,
    phone       TEXT NOT NULL,
    street      TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    city        TEXT NOT NULL,
    country     TEXT NOT NULL DEFAULT 'SE',
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.seller_pickup_addresses IS
    'Seller-owned pickup address used by Sendify (from_address) when booking shipments for sold marketplace listings.';

ALTER TABLE public.seller_pickup_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS seller_pickup_addresses_select_own ON public.seller_pickup_addresses;
CREATE POLICY seller_pickup_addresses_select_own ON public.seller_pickup_addresses
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS seller_pickup_addresses_insert_own ON public.seller_pickup_addresses;
CREATE POLICY seller_pickup_addresses_insert_own ON public.seller_pickup_addresses
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS seller_pickup_addresses_update_own ON public.seller_pickup_addresses;
CREATE POLICY seller_pickup_addresses_update_own ON public.seller_pickup_addresses
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMIT;

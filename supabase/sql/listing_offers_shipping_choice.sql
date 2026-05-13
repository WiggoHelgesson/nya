-- =====================================================
-- LISTING OFFERS — SHIPPING CHOICE
-- =====================================================
-- Buyer picks a carrier + service in PriceOfferSheetView
-- before submitting their offer (rates fetched live from
-- Sendify). The chosen rate is locked on the offer row so
-- the price won't change between authorisation and capture
-- even if Sendify rates fluctuate.
--
-- `amount_shipping_ore` already exists on listing_offers;
-- this migration just adds the carrier/service identifiers
-- so `book-marketplace-shipping` can recreate the same
-- shipment Sendify quoted.
-- =====================================================

BEGIN;

ALTER TABLE public.listing_offers
    ADD COLUMN IF NOT EXISTS shipping_carrier      TEXT,
    ADD COLUMN IF NOT EXISTS shipping_service_code TEXT;

COMMENT ON COLUMN public.listing_offers.shipping_carrier IS
    'Buyer-selected carrier (e.g. postnord, dhl, bring) — locked at offer creation.';
COMMENT ON COLUMN public.listing_offers.shipping_service_code IS
    'Sendify service identifier matching the carrier rate the buyer picked.';

COMMIT;

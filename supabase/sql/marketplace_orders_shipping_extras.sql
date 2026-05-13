-- =====================================================
-- MARKETPLACE ORDERS — SHIPPING EXTRAS (Sendify)
-- =====================================================
-- Adds carrier / tracking / label columns to
-- marketplace_orders for the Sendify integration. These
-- are populated by `book-marketplace-shipping` after the
-- buyer finalises a price offer (Stripe captures) and the
-- shipment is booked with Sendify.
-- =====================================================

BEGIN;

ALTER TABLE public.marketplace_orders
    ADD COLUMN IF NOT EXISTS shipping_carrier         TEXT,
    ADD COLUMN IF NOT EXISTS shipping_service_code    TEXT,
    ADD COLUMN IF NOT EXISTS sendify_shipment_id      TEXT,
    ADD COLUMN IF NOT EXISTS shipping_tracking_number TEXT,
    ADD COLUMN IF NOT EXISTS shipping_tracking_url    TEXT,
    ADD COLUMN IF NOT EXISTS shipping_label_url       TEXT,
    ADD COLUMN IF NOT EXISTS shipping_qr_payload      TEXT,
    ADD COLUMN IF NOT EXISTS shipping_status          TEXT NOT NULL DEFAULT 'pending'
        CHECK (shipping_status IN ('pending','label_ready','picked_up','in_transit','delivered','returned','manual','failed')),
    ADD COLUMN IF NOT EXISTS shipping_booked_at       TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS shipping_delivered_at    TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_sendify_shipment
    ON public.marketplace_orders (sendify_shipment_id);

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_shipping_status
    ON public.marketplace_orders (shipping_status);

COMMENT ON COLUMN public.marketplace_orders.shipping_status IS
    'pending: awaiting booking. label_ready: Sendify booked, label/QR available. picked_up/in_transit/delivered: from Sendify webhook. manual: booking failed -> admin uploads PDF. returned/failed: terminal error states.';

COMMIT;

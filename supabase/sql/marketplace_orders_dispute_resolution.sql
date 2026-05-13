-- =====================================================================
-- MARKETPLACE ORDERS: ADMIN DISPUTE RESOLUTION COLUMNS
-- ---------------------------------------------------------------------
-- När en admin fattar beslut i en tvist (`resolve-marketplace-dispute`)
-- stämplar vi resultatet på ordern. Används för audit + UI.
--
--  dispute_resolved_at        — när admin avgjorde tvisten
--  dispute_resolution         — 'refund_buyer' | 'release_seller'
--                               | 'partial_refund'
--  dispute_resolved_by        — admin user_id
--  dispute_admin_note         — fri text från admin (synlig för båda parter)
--  dispute_refund_amount_ore  — belopp som faktiskt återbetalats
-- =====================================================================

ALTER TABLE public.marketplace_orders
    ADD COLUMN IF NOT EXISTS dispute_resolved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS dispute_resolution TEXT
        CHECK (dispute_resolution IN ('refund_buyer','release_seller','partial_refund')),
    ADD COLUMN IF NOT EXISTS dispute_resolved_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS dispute_admin_note TEXT,
    ADD COLUMN IF NOT EXISTS dispute_refund_amount_ore INTEGER;

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_disputed_open
    ON public.marketplace_orders (dispute_opened_at)
    WHERE status = 'disputed' AND dispute_resolved_at IS NULL;

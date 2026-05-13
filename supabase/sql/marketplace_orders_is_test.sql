-- =====================================================
-- marketplace_orders: mark synthetic/admin test orders
-- =====================================================
BEGIN;

ALTER TABLE public.marketplace_orders
    ADD COLUMN IF NOT EXISTS is_test BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_is_test
    ON public.marketplace_orders (is_test)
    WHERE is_test;

COMMIT;

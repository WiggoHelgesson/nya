-- =====================================================================
-- MARKETPLACE ORDERS: SHIP-BY REMINDER FLAG
-- ---------------------------------------------------------------------
-- Idempotent guard for `process-marketplace-deadlines` så vi inte
-- skickar fler än EN ship-by-påminnelse per order. Sätts till NOW()
-- när säljarens 24h-påminnelse skickats.
-- =====================================================================

ALTER TABLE public.marketplace_orders
    ADD COLUMN IF NOT EXISTS ship_by_reminded_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_ship_reminder_pending
    ON public.marketplace_orders (ship_by_deadline)
    WHERE shipped_at IS NULL
      AND auto_cancelled_at IS NULL
      AND ship_by_reminded_at IS NULL;

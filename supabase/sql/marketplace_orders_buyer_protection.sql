-- =====================================================
-- MARKETPLACE ORDERS — BUYER PROTECTION (Blocket-style)
-- =====================================================
-- Adds escrow lifecycle to marketplace orders:
--
--   1. ship_by_deadline       — seller must ship within 3 days
--                                 of `label_ready`. Otherwise the
--                                 order auto-cancels and the buyer
--                                 is refunded.
--
--   2. shipped_at             — set when Sendify reports
--                                 `picked_up` (paket inskannat).
--
--   3. buyer_approval_deadline — set when delivered. Buyer has 48 h
--                                 to either tap "Godkänn varan" or
--                                 "Anmäl problem". After 48 h the
--                                 funds auto-release to the seller
--                                 unless a dispute is open.
--
--   4. buyer_approved_at      — set when buyer taps godkänn (or
--                                 implicit via auto-release).
--
--   5. dispute_opened_at      — set when buyer reports a problem.
--                                 Freezes the auto-release until
--                                 admin resolves.
--
--   6. auto_cancelled_at      — set when ship-deadline expires and
--                                 the order is automatically
--                                 cancelled + refunded.
--
-- All released funds flow via `stripe.transfers.create` — we never
-- use `transfer_data.destination` on the PaymentIntent anymore so
-- the money sits on the platform balance until release.
-- =====================================================

BEGIN;

ALTER TABLE public.marketplace_orders
    ADD COLUMN IF NOT EXISTS ship_by_deadline        TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS shipped_at              TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS buyer_approval_deadline TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS buyer_approved_at       TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS dispute_opened_at       TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS dispute_reason          TEXT,
    ADD COLUMN IF NOT EXISTS auto_cancelled_at       TIMESTAMPTZ;

-- Drop existing status check so we can extend it with new states.
DO $$
BEGIN
    ALTER TABLE public.marketplace_orders DROP CONSTRAINT IF EXISTS marketplace_orders_status_check;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

ALTER TABLE public.marketplace_orders
    ADD CONSTRAINT marketplace_orders_status_check
    CHECK (status IN (
        'pending',
        'succeeded',
        'failed',
        'refunded',
        'held_awaiting_seller',
        'released',
        'disputed',
        'cancelled'
    ));

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_ship_by_deadline
    ON public.marketplace_orders (ship_by_deadline)
    WHERE shipped_at IS NULL AND status = 'succeeded';

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_approval_deadline
    ON public.marketplace_orders (buyer_approval_deadline)
    WHERE buyer_approved_at IS NULL
      AND dispute_opened_at IS NULL
      AND status = 'succeeded';

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_dispute_opened
    ON public.marketplace_orders (dispute_opened_at)
    WHERE dispute_opened_at IS NOT NULL;

COMMENT ON COLUMN public.marketplace_orders.ship_by_deadline IS
    'Säljaren måste lämna in paketet innan denna tid (Sendify status -> picked_up). Annars auto-cancellas ordern och köparen återbetalas.';
COMMENT ON COLUMN public.marketplace_orders.buyer_approval_deadline IS
    'Köparen har tills denna tid på sig att godkänna eller reklamera efter leverans. Auto-release efter deadline om ingen tvist är öppen.';
COMMENT ON COLUMN public.marketplace_orders.dispute_opened_at IS
    'När köparen tryckt "Anmäl problem". Stoppar auto-release och kräver manuell hantering.';

COMMIT;

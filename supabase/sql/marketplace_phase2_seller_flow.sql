-- Phase 2: seller packed timestamp, 48h ship-by reminder flag
BEGIN;

ALTER TABLE public.marketplace_orders
  ADD COLUMN IF NOT EXISTS seller_packed_at TIMESTAMPTZ;

ALTER TABLE public.marketplace_orders
  ADD COLUMN IF NOT EXISTS ship_by_reminder_48h_at TIMESTAMPTZ;

COMMENT ON COLUMN public.marketplace_orders.seller_packed_at IS
  'Set when seller taps "Jag har packat" (edge: mark-marketplace-order-packed).';

COMMENT ON COLUMN public.marketplace_orders.ship_by_reminder_48h_at IS
  'Set when 48h-before-deadline reminder was sent (process-marketplace-deadlines).';

COMMENT ON COLUMN public.marketplace_orders.ship_by_reminded_at IS
  'Set when <24h-to-deadline reminder was sent.';

COMMIT;

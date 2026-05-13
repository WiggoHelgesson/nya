-- =====================================================
-- MARKETPLACE ORDERS — rename Sendify column → Shipmondo
-- =====================================================
-- Run once after switching edge functions to Shipmondo.
-- Safe to re-run: only renames if the old column still exists.
-- =====================================================

BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'marketplace_orders'
      AND column_name = 'sendify_shipment_id'
  ) THEN
    ALTER TABLE public.marketplace_orders
      RENAME COLUMN sendify_shipment_id TO shipmondo_shipment_id;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'i'
      AND c.relname = 'idx_marketplace_orders_sendify_shipment'
      AND n.nspname = 'public'
  ) THEN
    ALTER INDEX public.idx_marketplace_orders_sendify_shipment
      RENAME TO idx_marketplace_orders_shipmondo_shipment;
  END IF;
END $$;

COMMENT ON COLUMN public.marketplace_orders.shipmondo_shipment_id IS
  'Shipmondo shipment id (API v3). Populated by book-marketplace-shipping.';

COMMIT;

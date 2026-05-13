-- =====================================================
-- ALLOW LISTING DELETION WHEN ORDERS EXIST
-- =====================================================
-- marketplace_orders.listing_id previously had
-- ON DELETE RESTRICT, which blocked sellers (and admins)
-- from deleting a consignment_submission once any order
-- referenced it. We keep the historical order row (needed
-- for bookkeeping, Stripe reconciliation and buyer
-- receipts) but drop the listing reference via SET NULL.
-- =====================================================

BEGIN;

ALTER TABLE public.marketplace_orders
    ALTER COLUMN listing_id DROP NOT NULL;

ALTER TABLE public.marketplace_orders
    DROP CONSTRAINT IF EXISTS marketplace_orders_listing_id_fkey;

ALTER TABLE public.marketplace_orders
    ADD CONSTRAINT marketplace_orders_listing_id_fkey
    FOREIGN KEY (listing_id)
    REFERENCES public.consignment_submissions (id)
    ON DELETE SET NULL;

COMMIT;

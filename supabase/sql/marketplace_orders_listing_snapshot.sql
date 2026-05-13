-- =============================================================================
-- KÖR BARA DENNA FIL I: Supabase Dashboard → SQL Editor
-- (Klistra INTE in deploy_marketplace_stripe.sh här — det är bash, inte SQL.)
-- =============================================================================
--
-- Snapshot listing title / brand / cover image on marketplace_orders so
-- "Mina köp" and "Mina försäljningar" still show thumbnails after the
-- consignment row is deleted (listing_id SET NULL) or when joins are skipped.

ALTER TABLE public.marketplace_orders
  ADD COLUMN IF NOT EXISTS listing_title text,
  ADD COLUMN IF NOT EXISTS listing_brand text,
  ADD COLUMN IF NOT EXISTS listing_image_url text;

UPDATE public.marketplace_orders mo
SET
  listing_title = COALESCE(mo.listing_title, cs.title),
  listing_brand = COALESCE(mo.listing_brand, cs.user_brand),
  listing_image_url = COALESCE(
    mo.listing_image_url,
    CASE
      WHEN cs.image_urls IS NOT NULL AND array_length(cs.image_urls, 1) >= 1
      THEN cs.image_urls[1]
      ELSE NULL
    END
  )
FROM public.consignment_submissions cs
WHERE mo.listing_id = cs.id
  AND (
    mo.listing_title IS NULL
    OR mo.listing_image_url IS NULL
    OR mo.listing_brand IS NULL
  );

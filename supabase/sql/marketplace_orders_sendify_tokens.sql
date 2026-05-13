-- Sendify booking token + service-point columns
-- ===============================================
-- Stores the rate-quote `booking_token` (valid ~30 min) so
-- `book-marketplace-shipping` can call `POST /shipments/book` directly.
-- For offers (where capture happens hours/days after the quote) the
-- token will be stale and `book-marketplace-shipping` re-fetches a
-- fresh one matching the saved carrier + product_name.
--
-- The `service_point_token` columns lock the buyer's chosen ombud
-- (PostNord agent / Budbee Box / Instabox locker / DHL Service Point)
-- so we book to exactly the one they picked.
--
-- Apply via:
--   psql "$DB_URL" -f supabase/sql/marketplace_orders_sendify_tokens.sql

ALTER TABLE marketplace_orders
  ADD COLUMN IF NOT EXISTS shipping_booking_token text,
  ADD COLUMN IF NOT EXISTS shipping_booking_token_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS shipping_service_point_token text,
  ADD COLUMN IF NOT EXISTS shipping_service_point_name text,
  ADD COLUMN IF NOT EXISTS shipping_service_point_address text,
  ADD COLUMN IF NOT EXISTS shipping_product_name text;

ALTER TABLE listing_offers
  ADD COLUMN IF NOT EXISTS shipping_booking_token text,
  ADD COLUMN IF NOT EXISTS shipping_booking_token_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS shipping_service_point_token text,
  ADD COLUMN IF NOT EXISTS shipping_service_point_name text,
  ADD COLUMN IF NOT EXISTS shipping_service_point_address text,
  ADD COLUMN IF NOT EXISTS shipping_product_name text;

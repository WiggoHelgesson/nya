-- =====================================================
-- NOLLSTART: COMMUNITY-ANNONSER (Mina annonser / feed)
-- =====================================================
-- ENDAST SQL — kör denna fil i Supabase SQL Editor.
-- Klistra INTE in empty_consignment_photos_bucket.ts här (det är terminal/Deno).
-- =====================================================
-- Kör i Supabase SQL Editor (roll med full DB-access, t.ex. postgres).
-- Detta är destruktivt och går inte att ångra utan backup.
--
-- Gör:
--   1) Sätter listing_id = NULL på DM-trådar (annars CASCADE på
--      consignment_submissions raderar hela listing-kopplade konversationer).
--   2) Raderar alla rader i public.consignment_submissions.
--      → listing_offers följer med (ON DELETE CASCADE).
--      → marketplace_orders.listing_id blir NULL om ni kört
--        supabase/sql/allow_delete_listing_with_orders.sql (rekommenderat).
--   3) Bilder i bucket consignment-photos: kan INTE raderas med SQL
--      (storage.protect_delete). Använd Storage API — se
--      supabase/scripts/empty_consignment_photos_bucket.ts
--
-- Raderar INTE: marketplace_orders, användare, seller_pickup_addresses,
-- eller DM utan listing-koppling.
--
-- Om DELETE FROM consignment_submissions misslyckas med FK-fel: kör först
-- allow_delete_listing_with_orders.sql, eller ta bort/uppdatera ordrar manuellt.
-- =====================================================

BEGIN;

UPDATE public.direct_conversations
SET listing_id = NULL
WHERE listing_id IS NOT NULL;

DELETE FROM public.consignment_submissions;

COMMIT;

-- Efter detta: töm bucket consignment-photos via Storage API (skript ovan),
-- annars ligger filer kvar i lagringen (DB-raderna för storage.metadata hanteras
-- av API:t vid radering).

-- =====================================================
-- VALFRITT: även tömma alla marknadsordrar (total marknads-nollstart)
-- =====================================================
-- Avkommentera ENDAST om du medvetet vill radera orderhistorik.
-- Stripe-avräkning / kundtjänst / chargebacks kan fortfarande behöva data
-- i Stripe Dashboard — detta är bara er Supabase-rad.
--
-- BEGIN;
-- DELETE FROM public.marketplace_orders;
-- COMMIT;
-- =====================================================

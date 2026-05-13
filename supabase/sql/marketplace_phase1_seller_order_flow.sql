-- Phase 1: seller sale UX — buyer_username snapshot, feed view, push title + listing_id in payload
-- Run in Supabase SQL Editor.

BEGIN;

ALTER TABLE public.marketplace_orders
  ADD COLUMN IF NOT EXISTS buyer_username TEXT;

COMMENT ON COLUMN public.marketplace_orders.buyer_username IS
  'Display name snapshot for buyer at purchase time (push / Mina annonser).';

-- Accepted listings not sold — used by iOS community feed (RLS on underlying table still applies).
CREATE OR REPLACE VIEW public.community_listings_feed AS
SELECT *
FROM public.consignment_submissions
WHERE admin_status = 'accepted'
  AND sold_at IS NULL;

GRANT SELECT ON public.community_listings_feed TO authenticated;

-- Push: UP&DOWN title for marketplace purchase/sale; include listing_id for deep link.
CREATE OR REPLACE FUNCTION public.on_notification_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_title TEXT;
    v_body  TEXT;
    v_row   JSONB := to_jsonb(NEW);
    v_listing_id TEXT;
BEGIN
    IF NEW.type IN ('marketplace_sale', 'marketplace_purchase') THEN
        v_title := 'UP&DOWN';
    ELSE
        v_title := 'Up&Down';
    END IF;

    v_body := NULLIF(TRIM(COALESCE(v_row ->> 'message', '')), '');

    IF v_body IS NULL AND (NEW.type IN ('comment', 'reply')) THEN
        v_body := NULLIF(TRIM(COALESCE(v_row ->> 'comment_text', '')), '');
    END IF;

    IF v_body IS NULL THEN
        CASE NEW.type
            WHEN 'like' THEN
                v_body := COALESCE(NEW.actor_username, 'Någon') || ' gillade ditt inlägg';
            WHEN 'comment' THEN
                v_body := COALESCE(NEW.actor_username, 'Någon') || ' kommenterade på ditt inlägg';
            WHEN 'follow' THEN
                v_body := COALESCE(NEW.actor_username, 'Någon') || ' började följa dig';
            WHEN 'new_workout' THEN
                v_body := COALESCE(NEW.actor_username, 'Någon') || ' har avslutat ett träningspass!';
            WHEN 'reply' THEN
                v_body := COALESCE(NEW.actor_username, 'Någon') || ' svarade på din kommentar';
            WHEN 'marketplace_purchase' THEN
                v_body := 'Köpet är klart — vi meddelar säljaren!';
            WHEN 'marketplace_sale' THEN
                v_body := 'Din annons är såld! Lämna in paketet inom 3 dagar.';
            WHEN 'marketplace_shipping_label' THEN
                v_body := 'Fraktsedeln är klar — paketet kan lämnas in.';
            WHEN 'marketplace_shipping_started' THEN
                v_body := 'Fraktbokningen är klar.';
            WHEN 'marketplace_picked_up' THEN
                v_body := 'Säljaren har lämnat in paketet — det är på väg!';
            WHEN 'marketplace_in_transit' THEN
                v_body := 'Paketet är på väg till dig.';
            WHEN 'marketplace_delivered' THEN
                v_body := 'Paketet är levererat.';
            WHEN 'marketplace_buyer_approved' THEN
                v_body := 'Köparen har godkänt — pengarna är på väg.';
            WHEN 'marketplace_payout_released' THEN
                v_body := 'Pengarna har skickats till ditt Stripe-konto.';
            WHEN 'marketplace_payout_auto_released' THEN
                v_body := '48h har gått — pengarna har frigjorts till säljaren.';
            WHEN 'marketplace_approved_pending_payout' THEN
                v_body := 'Köparen har godkänt — slutför Stripe-onboardingen för utbetalning.';
            WHEN 'marketplace_ship_reminder' THEN
                v_body := '1 dygn kvar att lämna in paketet — annars avbokas köpet automatiskt.';
            WHEN 'marketplace_auto_cancelled' THEN
                v_body := 'Din försäljning cancellerades eftersom paketet inte lämnades in i tid.';
            WHEN 'marketplace_auto_refund' THEN
                v_body := 'Säljaren skickade inte i tid — du har fått pengarna återbetalade.';
            WHEN 'marketplace_dispute_opened' THEN
                v_body := 'Köparen har anmält ett problem med ordern.';
            WHEN 'marketplace_dispute_received' THEN
                v_body := 'Vi har tagit emot din anmälan. Supporten kontaktar dig inom kort.';
            WHEN 'admin_marketplace_dispute' THEN
                v_body := 'Ny marketplace-tvist behöver granskas.';
            WHEN 'marketplace_dispute_refunded' THEN
                v_body := 'Tvisten är avgjord — beloppet har återbetalats.';
            WHEN 'marketplace_dispute_released' THEN
                v_body := 'Tvisten är avgjord — pengarna har skickats till säljaren.';
            WHEN 'marketplace_dispute_partial_refunded' THEN
                v_body := 'Tvisten är avgjord med partiell återbetalning.';
            WHEN 'marketplace_payout_failed_admin' THEN
                v_body := 'En Stripe-utbetalning misslyckades och behöver granskas.';
            WHEN 'marketplace_cancelled' THEN
                v_body := 'Köpet är avbokat och beloppet återbetalas.';
            ELSE
                v_body := 'Du har en ny notis';
        END CASE;
    END IF;

    v_listing_id := NULLIF(TRIM(COALESCE(v_row ->> 'related_id', '')), '');

    PERFORM public.send_push_notification(
        NEW.user_id,
        v_title,
        v_body,
        jsonb_build_object(
            'type', NEW.type,
            'post_id', COALESCE(NEW.post_id::text, ''),
            'actor_id', NEW.actor_id::text,
            'listing_id', COALESCE(v_listing_id, '')
        )
    );

    RETURN NEW;
END;
$$;

COMMIT;

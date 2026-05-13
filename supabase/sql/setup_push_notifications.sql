-- ============================================
-- PUSH NOTIFICATIONS SETUP
-- ============================================

-- 1. Ensure device_tokens table exists
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their tokens" ON public.device_tokens;
CREATE POLICY "Users can manage their tokens" ON public.device_tokens
    FOR ALL USING (auth.uid() = user_id);

GRANT ALL ON public.device_tokens TO authenticated;

-- 2. Create function to send push notification via Edge Function
CREATE OR REPLACE FUNCTION public.send_push_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_response JSONB;
BEGIN
    -- Call the Edge Function
    SELECT content::jsonb INTO v_response
    FROM http((
        'POST',
        current_setting('app.settings.supabase_url') || '/functions/v1/send-push-notification',
        ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))],
        'application/json',
        jsonb_build_object(
            'user_id', p_user_id::text,
            'title', p_title,
            'body', p_body,
            'data', p_data
        )::text
    ));
    
    -- Log result (optional)
    RAISE NOTICE 'Push notification sent: %', v_response;
EXCEPTION WHEN OTHERS THEN
    -- Don't fail the transaction if push fails
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
END;
$$;

-- 3. Create trigger function for new notifications
CREATE OR REPLACE FUNCTION public.on_notification_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_title TEXT;
    v_body  TEXT;
    v_row   JSONB := to_jsonb(NEW);
BEGIN
    -- Alla notiser har "Up&Down" som rubrik. Body bär hela kontexten.
    v_title := 'Up&Down';

    -- `message` kan saknas i äldre schema; läs via jsonb så vi inte kraschar.
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
            -- Marketplace-defaults (används bara om `message` saknas).
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

    -- Send push notification (async - won't block the insert)
    PERFORM public.send_push_notification(
        NEW.user_id,
        v_title,
        v_body,
        jsonb_build_object(
            'type', NEW.type,
            'post_id', COALESCE(NEW.post_id::text, ''),
            'actor_id', NEW.actor_id::text
        )
    );

    RETURN NEW;
END;
$$;

-- 4. Create trigger on notifications table
DROP TRIGGER IF EXISTS trigger_send_push_on_notification ON public.notifications;
CREATE TRIGGER trigger_send_push_on_notification
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.on_notification_created();

-- 5. Index for faster token lookups
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_platform ON public.device_tokens(platform);


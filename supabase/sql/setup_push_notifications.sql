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
    v_body TEXT;
BEGIN
    -- Build notification message based on type
    CASE NEW.type
        WHEN 'like' THEN
            v_title := '❤️ Nytt gillande';
            v_body := COALESCE(NEW.actor_username, 'Någon') || ' gillade ditt inlägg';
        WHEN 'comment' THEN
            v_title := '💬 Ny kommentar';
            v_body := COALESCE(NEW.actor_username, 'Någon') || ' kommenterade på ditt inlägg';
        WHEN 'follow' THEN
            v_title := '👤 Ny följare';
            v_body := COALESCE(NEW.actor_username, 'Någon') || ' började följa dig';
        WHEN 'new_workout' THEN
            v_title := '🏃 Nytt träningspass';
            v_body := COALESCE(NEW.actor_username, 'Någon') || ' har avslutat ett träningspass!';
        WHEN 'reply' THEN
            v_title := '↩️ Nytt svar';
            v_body := COALESCE(NEW.actor_username, 'Någon') || ' svarade på din kommentar';
        ELSE
            v_title := '🔔 Ny notis';
            v_body := 'Du har en ny notis';
    END CASE;

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


-- ============================================
-- Chat Push Notifications Setup
-- ============================================
-- This trigger sends a push notification whenever a new
-- chat message is inserted into trainer_chat_messages.
-- It uses pg_net to call the notify-chat-message Edge Function.
-- ============================================

-- STEP 1: Enable the pg_net extension (for HTTP calls from SQL)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- STEP 2: Create the trigger function
CREATE OR REPLACE FUNCTION public.notify_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  _supabase_url TEXT;
  _service_role_key TEXT;
  _edge_function_url TEXT;
BEGIN
  -- Get Supabase URL from the config
  -- NOTE: You need to replace YOUR_SUPABASE_URL with your actual Supabase URL
  -- e.g. 'https://xxxxx.supabase.co'
  _supabase_url := current_setting('app.settings.supabase_url', true);
  _service_role_key := current_setting('app.settings.service_role_key', true);
  
  -- Fallback: hardcode if settings are not available
  IF _supabase_url IS NULL OR _supabase_url = '' THEN
    -- Replace with your actual Supabase URL
    _supabase_url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url' LIMIT 1);
  END IF;
  
  IF _service_role_key IS NULL OR _service_role_key = '' THEN
    _service_role_key := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1);
  END IF;

  -- Call the Edge Function via pg_net
  PERFORM net.http_post(
    url := _supabase_url || '/functions/v1/notify-chat-message',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || _service_role_key
    ),
    body := jsonb_build_object(
      'conversation_id', NEW.conversation_id::text,
      'sender_id', NEW.sender_id::text,
      'message', NEW.message
    )
  );

  RETURN NEW;
END;
$$;

-- STEP 3: Create the trigger
DROP TRIGGER IF EXISTS on_new_chat_message_notify ON public.trainer_chat_messages;

CREATE TRIGGER on_new_chat_message_notify
  AFTER INSERT ON public.trainer_chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_chat_message();

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 'Trigger created successfully!' as status;

-- Check that trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'trainer_chat_messages'
ORDER BY trigger_name;

-- ============================================
-- ALTERNATIVE: If pg_net doesn't work, use a Supabase Database Webhook instead
-- ============================================
-- Go to Supabase Dashboard → Database → Webhooks
-- Create a new webhook:
--   Name: notify-chat-message
--   Table: trainer_chat_messages
--   Events: INSERT
--   Type: Supabase Edge Function
--   Edge Function: notify-chat-message
--
-- This is easier and doesn't require pg_net or vault secrets!
-- ============================================

-- ============================================
-- SIMPLEST APPROACH: Database Webhook (Recommended)
-- ============================================
-- If the above pg_net approach fails, just set up a 
-- Database Webhook in the Supabase Dashboard:
--
-- 1. Go to Database → Webhooks → Create Webhook
-- 2. Name: notify-chat-message  
-- 3. Table: trainer_chat_messages
-- 4. Events: INSERT
-- 5. Type: Supabase Edge Function
-- 6. Function: notify-chat-message
-- 7. Additional headers: none needed (service role is automatic)
--
-- This webhook will automatically call the edge function
-- every time a new message is inserted!
-- ============================================

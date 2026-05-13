-- =====================================================
-- SHIPMONDO TRACKING POLL — pg_cron schedule
-- =====================================================
-- Calls poll-shipmondo-tracking with the service-role key.
--
-- Before first run, create vault secrets (Supabase SQL editor):
--
--   select vault.create_secret(
--       'https://<project-ref>.supabase.co/functions/v1/poll-shipmondo-tracking',
--       'shipmondo_poll_url'
--   );
--   select vault.create_secret(
--       '<service-role-key>',
--       'shipmondo_poll_key'
--   );
-- =====================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

DO $$
BEGIN
  PERFORM cron.unschedule('sendify-tracking-poll');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

DO $$
BEGIN
  PERFORM cron.unschedule('shipmondo-tracking-poll');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

SELECT cron.schedule(
  'shipmondo-tracking-poll',
  '*/30 * * * *',
  $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'shipmondo_poll_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'shipmondo_poll_key')
    ),
    body := jsonb_build_object('limit', 200)
  );
  $$
);

COMMIT;

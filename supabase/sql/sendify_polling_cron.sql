-- =====================================================
-- SENDIFY TRACKING POLL — pg_cron schedule
-- =====================================================
-- Sendify doesn't expose self-serve webhooks on the Basic
-- plan, so we poll their tracking API every 30 minutes
-- via the `poll-sendify-tracking` edge function instead.
--
-- pg_cron + pg_net are both pre-installed on Supabase.
-- The job calls the function with the service-role bearer
-- token so it can read/write `marketplace_orders` rows
-- regardless of RLS.
--
-- Re-run this script whenever you need to update the
-- schedule or rotate the URL/token.
-- =====================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Drop any previous version so re-running is safe.
DO $$
BEGIN
    PERFORM cron.unschedule('sendify-tracking-poll');
EXCEPTION WHEN OTHERS THEN
    -- job didn't exist yet — fine.
    NULL;
END $$;

-- The function URL + service role key are stored as Supabase
-- "vault secrets" so we don't hard-code them in the migration.
-- Set these once via the SQL editor before running this script:
--
--   select vault.create_secret(
--       'https://<your-project-ref>.supabase.co/functions/v1/poll-sendify-tracking',
--       'sendify_poll_url'
--   );
--   select vault.create_secret(
--       '<your-service-role-key>',
--       'sendify_poll_key'
--   );
--
-- (Or update the secret if it already exists via vault.update_secret.)
--
-- The cron job below resolves them at runtime.

SELECT cron.schedule(
    'sendify-tracking-poll',
    '*/30 * * * *',
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'sendify_poll_url'),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'sendify_poll_key')
        ),
        body := jsonb_build_object('limit', 200)
    );
    $$
);

COMMIT;

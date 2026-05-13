-- =====================================================
-- MARKETPLACE HEALTHCHECK — pg_cron schedule
-- =====================================================
-- Skannar fastnade ordrar varje timme och postar till Slack
-- om något hittas. Kräver `SLACK_HEALTHCHECK_URL` som secret
-- på edge-funktionen. Vault-secret som driver schemat:
--
--   select vault.create_secret(
--       'https://<project-ref>.supabase.co/functions/v1/marketplace-healthcheck',
--       'marketplace_healthcheck_url'
--   );
-- =====================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

DO $$
BEGIN
    PERFORM cron.unschedule('marketplace-healthcheck-tick');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

SELECT cron.schedule(
    'marketplace-healthcheck-tick',
    '25 * * * *', -- 25 minuter över varje timme
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'marketplace_healthcheck_url'),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'sendify_poll_key')
        ),
        body := jsonb_build_object()
    );
    $$
);

COMMIT;

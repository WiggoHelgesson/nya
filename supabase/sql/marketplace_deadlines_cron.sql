-- =====================================================
-- MARKETPLACE DEADLINES — pg_cron schedule
-- =====================================================
-- Cron-driven motor för köparskyddet. Kör varje timme och
--   • auto-cancellar/refundar ordrar där säljaren inte lämnat in
--     paketet inom `ship_by_deadline`
--   • auto-releasar pengar till säljaren när
--     `buyer_approval_deadline` passerat utan godkännande/tvist
--
-- Förutsättning: vault-secret `marketplace_deadlines_url` med
-- function-URL:en för `process-marketplace-deadlines`. Den
-- service-role-key som redan finns för
-- `sendify-tracking-poll` återanvänds (`sendify_poll_key`).
-- =====================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

DO $$
BEGIN
    PERFORM cron.unschedule('marketplace-deadlines-tick');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Sätt secrets en gång (uppdatera om de redan finns):
--   select vault.create_secret(
--       'https://<project-ref>.supabase.co/functions/v1/process-marketplace-deadlines',
--       'marketplace_deadlines_url'
--   );

SELECT cron.schedule(
    'marketplace-deadlines-tick',
    '5 * * * *', -- 5 minuter över varje timme
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'marketplace_deadlines_url'),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'sendify_poll_key')
        ),
        body := jsonb_build_object('limit', 200)
    );
    $$
);

COMMIT;

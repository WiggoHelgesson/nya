-- =====================================================
-- MARKETPLACE PAYOUT RETRY — pg_cron schedule
-- =====================================================
-- Plockar upp ordrar där `stripe.transfers.create` failade
-- (markerade med `payout_failed_at`) och försöker igen var 30:e
-- minut. Backoff (1 h) hanteras inuti edge-funktionen så vi kan
-- köra schemat tätt utan att spamma Stripe.
--
-- Förutsättning: vault-secret `marketplace_payout_retry_url` med
-- function-URL:en för `process-pending-seller-payouts`. Vi
-- återanvänder samma service-role-key (`sendify_poll_key`).
-- =====================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

DO $$
BEGIN
    PERFORM cron.unschedule('marketplace-payout-retry-tick');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Sätt secret en gång:
--   select vault.create_secret(
--       'https://<project-ref>.supabase.co/functions/v1/process-pending-seller-payouts',
--       'marketplace_payout_retry_url'
--   );

SELECT cron.schedule(
    'marketplace-payout-retry-tick',
    '15,45 * * * *', -- var 30:e minut
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'marketplace_payout_retry_url'),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'sendify_poll_key')
        ),
        body := jsonb_build_object()
    );
    $$
);

COMMIT;

-- =====================================================
-- SNABB KOLL: NUVARANDE FORCE UPDATE INSTÄLLNINGAR
-- =====================================================
-- Kör detta INNAN du ändrar något!
-- Spara dessa värden så du kan återställa senare

SELECT 
    '📊 NUVARANDE INSTÄLLNINGAR' as status,
    id,
    min_version as "Min Version",
    force_update as "Force Update Aktiverad",
    update_message_sv as "Meddelande (Svenska)",
    app_store_url as "App Store URL",
    created_at as "Skapad",
    updated_at as "Senast Uppdaterad"
FROM public.app_config
WHERE id = 1;

-- =====================================================
-- SPARA DESSA VÄRDEN!
-- =====================================================
-- Du behöver dem för att återställa i RESTORE_force_update.sql
-- =====================================================













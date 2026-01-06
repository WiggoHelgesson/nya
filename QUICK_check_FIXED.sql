-- =====================================================
-- SNABB KOLL: NUVARANDE FORCE UPDATE INSTÄLLNINGAR (FIXED)
-- =====================================================
-- Visar ALLA rader (fungerar med UUID eller INT)

SELECT 
    '📊 NUVARANDE INSTÄLLNINGAR' as status,
    id,
    min_version as "Min Version",
    force_update as "Force Update Aktiverad",
    update_message_sv as "Meddelande (Svenska)",
    app_store_url as "App Store URL"
FROM public.app_config;

-- =====================================================
-- SPARA DESSA VÄRDEN!
-- =====================================================


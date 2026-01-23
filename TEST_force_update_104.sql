-- =====================================================
-- TEST: AKTIVERA FORCE UPDATE TILL 104 (TEMPORÄRT)
-- =====================================================
-- VIKTIGT: Detta är för TESTNING. Kör RESTORE-skriptet efteråt!

-- Steg 1: SPARA nuvarande inställningar (kör detta FÖRST!)
SELECT 
    '🔍 NUVARANDE INSTÄLLNINGAR (SPARA DESSA):' as info,
    min_version,
    force_update,
    update_message_sv
FROM public.app_config
WHERE id = 1;

-- Steg 2: Aktivera force update till 104 (för test)
UPDATE public.app_config
SET 
    min_version = '104.0',
    force_update = true,
    update_message_sv = 'TEST: En ny version av Up&Down finns tillgänglig. Uppdatera för att fortsätta använda appen! 💪',
    updated_at = NOW()
WHERE id = 1;

-- Steg 3: Verifiera att det fungerade
SELECT 
    '✅ EFTER UPPDATERING:' as info,
    min_version,
    force_update,
    update_message_sv,
    updated_at
FROM public.app_config
WHERE id = 1;

-- =====================================================
-- NÄSTA STEG:
-- =====================================================
-- 1. Testa appen i Xcode (version 103.0)
-- 2. När du är klar med testet, kör RESTORE_force_update.sql
-- 3. Detta återställer till ursprungliga inställningar
















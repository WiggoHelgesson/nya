-- =====================================================
-- TEST: AKTIVERA FORCE UPDATE TILL 104 (FIXED)
-- =====================================================
-- Fungerar med UUID eller INT som id

-- Steg 1: SPARA nuvarande inställningar
SELECT 
    '🔍 NUVARANDE INSTÄLLNINGAR (SPARA DESSA):' as info,
    id,
    min_version,
    force_update,
    update_message_sv
FROM public.app_config;

-- Steg 2: Aktivera force update till 104
-- Uppdaterar ALLA rader (förmodligen bara 1 rad)
UPDATE public.app_config
SET 
    min_version = '104.0',
    force_update = true,
    update_message_sv = 'TEST: En ny version av Up&Down finns tillgänglig. Uppdatera för att fortsätta använda appen! 💪';

-- Steg 3: Verifiera
SELECT 
    '✅ EFTER UPPDATERING:' as info,
    id,
    min_version,
    force_update,
    update_message_sv
FROM public.app_config;

-- =====================================================
-- NÄSTA STEG:
-- =====================================================
-- 1. Testa appen i Xcode (version 103.0)
-- 2. När du är klar, kör RESTORE_force_update_FIXED.sql


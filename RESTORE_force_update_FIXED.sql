-- =====================================================
-- ÅTERSTÄLL FORCE UPDATE (FIXED)
-- =====================================================
-- Fungerar med UUID eller INT som id

-- Steg 1: Visa nuvarande (test) inställningar
SELECT 
    '🔍 NUVARANDE (TEST) INSTÄLLNINGAR:' as info,
    id,
    min_version,
    force_update,
    update_message_sv
FROM public.app_config;

-- Steg 2: Återställ till ursprungliga inställningar
-- Uppdaterar ALLA rader (förmodligen bara 1 rad)
UPDATE public.app_config
SET 
    min_version = '103.0',
    force_update = false,
    update_message_sv = 'En ny version av appen finns tillgänglig. Vänligen uppdatera för att fortsätta använda appen.';

-- Steg 3: Verifiera återställning
SELECT 
    '✅ EFTER ÅTERSTÄLLNING:' as info,
    id,
    min_version,
    force_update,
    update_message_sv
FROM public.app_config;

-- =====================================================
-- RESULTAT:
-- =====================================================
-- min_version: 103.0
-- force_update: false (AVSTÄNGT)
-- Alla användare kan nu använda appen normalt
-- =====================================================


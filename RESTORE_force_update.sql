-- =====================================================
-- ÅTERSTÄLL FORCE UPDATE (EFTER TEST)
-- =====================================================
-- Kör detta EFTER att du testat force update systemet
-- Detta återställer till ursprungliga inställningar

-- Steg 1: Visa nuvarande (test) inställningar
SELECT 
    '🔍 NUVARANDE (TEST) INSTÄLLNINGAR:' as info,
    min_version,
    force_update,
    update_message_sv,
    updated_at
FROM public.app_config
WHERE id = 1;

-- Steg 2: Återställ till ursprungliga inställningar
-- (Anpassa dessa värden om dina ursprungliga var annorlunda!)
UPDATE public.app_config
SET 
    min_version = '103.0',  -- Återställ till 103
    force_update = false,    -- STÄNG AV force update
    update_message_sv = 'En ny version av appen finns tillgänglig. Vänligen uppdatera för att fortsätta använda appen.',
    updated_at = NOW()
WHERE id = 1;

-- Steg 3: Verifiera återställning
SELECT 
    '✅ EFTER ÅTERSTÄLLNING:' as info,
    min_version,
    force_update,
    update_message_sv,
    updated_at
FROM public.app_config
WHERE id = 1;

-- =====================================================
-- RESULTAT:
-- =====================================================
-- min_version: 103.0
-- force_update: false (AVSTÄNGT)
-- Alla användare kan nu använda appen normalt
-- =====================================================

-- =====================================================
-- OM DU HADE ANDRA URSPRUNGLIGA VÄRDEN:
-- =====================================================
-- Ändra raderna ovan till de värden du såg i steg 1
-- när du körde TEST_force_update_104.sql
-- =====================================================









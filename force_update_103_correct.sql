-- =====================================================
-- FORCE UPDATE TILL VERSION 103 (KORREKT STRUKTUR)
-- =====================================================
-- Uppdaterar till version 103 med din faktiska tabellstruktur

-- 1️⃣ UPPDATERA TILL VERSION 103
UPDATE public.app_versions
SET 
    minimum_required_version = '103.0',
    current_version = '103.0',
    is_active = true,
    force_update_message = 'En ny version finns tillgänglig med viktiga förbättringar. Uppdatera för att fortsätta använda appen.',
    updated_at = NOW()
WHERE id = '17d4d743-691f-4af6-804e-3b18398c295b';

-- 2️⃣ VERIFIERA ATT DET FUNKADE
SELECT 
    id,
    minimum_required_version,
    current_version,
    is_active,
    force_update_message,
    updated_at,
    CASE 
        WHEN minimum_required_version = '103.0' AND is_active = true
        THEN '✅ FORCE UPDATE TILL 103 AKTIVERAD'
        ELSE '❌ NÅGOT ÄR FEL'
    END as status
FROM public.app_versions
WHERE id = '17d4d743-691f-4af6-804e-3b18398c295b';

-- =====================================================
-- ✅ RESULTAT
-- =====================================================
-- Alla användare med version < 103.0 måste uppdatera!
-- 
-- De kommer att se meddelandet:
-- "En ny version finns tillgänglig med viktiga 
--  förbättringar. Uppdatera för att fortsätta använda appen."
-- 
-- Med en knapp som går till App Store














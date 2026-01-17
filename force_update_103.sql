-- =====================================================
-- FORCE UPDATE TILL VERSION 103
-- =====================================================
-- Tvingar alla användare att uppdatera till version 103

-- 1️⃣ UPPDATERA MINIMUM VERSION
UPDATE public.app_versions
SET 
    minimum_version = '103.0',
    latest_version = '103.0',
    force_update = true,
    updated_at = NOW()
WHERE platform = 'ios';

-- 2️⃣ VERIFIERA ATT DET FUNKADE
SELECT 
    platform,
    minimum_version,
    latest_version,
    force_update,
    updated_at,
    CASE 
        WHEN force_update = true AND minimum_version = '103.0' 
        THEN '✅ FORCE UPDATE AKTIVERAD'
        ELSE '❌ NÅGOT ÄR FEL'
    END as status
FROM public.app_versions
WHERE platform = 'ios';

-- =====================================================
-- ✅ RESULTAT
-- =====================================================
-- Alla användare med version < 103.0 måste uppdatera!
-- 
-- De kommer att se:
-- "En ny version av Up&Down är tillgänglig. 
--  Uppdatera för att fortsätta använda appen."
-- 
-- Med en knapp: "Uppdatera nu" → App Store














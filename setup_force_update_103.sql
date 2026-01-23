-- =====================================================
-- KOMPLETT SETUP: FORCE UPDATE TILL VERSION 103
-- =====================================================
-- Kör hela denna fil för att sätta upp force update

-- 1️⃣ SKAPA TABELL (om den inte finns)
CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL UNIQUE CHECK (platform IN ('ios', 'android')),
    minimum_version TEXT NOT NULL,
    latest_version TEXT NOT NULL,
    force_update BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2️⃣ SÄTT VERSION 103 MED FORCE UPDATE
INSERT INTO public.app_versions (platform, minimum_version, latest_version, force_update)
VALUES ('ios', '103.0', '103.0', true)
ON CONFLICT (platform) DO UPDATE 
SET 
    minimum_version = '103.0',
    latest_version = '103.0',
    force_update = true,
    updated_at = NOW();

-- 3️⃣ ENABLE RLS (om inte redan aktiverat)
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- 4️⃣ SKAPA POLICY (om den inte finns)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'app_versions' 
        AND policyname = 'app_versions_select_all'
    ) THEN
        CREATE POLICY app_versions_select_all ON public.app_versions
            FOR SELECT USING (true);
    END IF;
END $$;

-- 5️⃣ VERIFIERA SETUP
SELECT 
    platform,
    minimum_version,
    latest_version,
    force_update,
    updated_at,
    CASE 
        WHEN force_update = true AND minimum_version = '103.0' 
        THEN '✅ FORCE UPDATE AKTIVERAD FÖR VERSION 103'
        ELSE '❌ NÅGOT ÄR FEL'
    END as status
FROM public.app_versions
WHERE platform = 'ios';

-- =====================================================
-- ✅ KLART!
-- =====================================================
-- Alla användare med version < 103.0 MÅSTE uppdatera!
-- 
-- RESULTAT:
-- - Users med v102 eller lägre: "Uppdatera nu"-skärm
-- - Users med v103: Appen fungerar normalt
-- 
-- ATT INAKTIVERA FORCE UPDATE (när alla uppdaterat):
-- UPDATE public.app_versions 
-- SET force_update = false 
-- WHERE platform = 'ios';
















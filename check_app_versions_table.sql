-- =====================================================
-- KOLLA OM APP_VERSIONS TABELLEN FINNS
-- =====================================================

-- 1️⃣ KOLLA OM TABELLEN FINNS
SELECT 
    CASE 
        WHEN EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'app_versions')
        THEN '✅ Tabellen finns'
        ELSE '❌ Tabellen finns INTE - kör create-script!'
    END as table_status;

-- 2️⃣ OM TABELLEN FINNS - VISA INNEHÅLL
SELECT * FROM public.app_versions;

-- =====================================================
-- OM TABELLEN INTE FINNS - SKAPA DEN:
-- =====================================================
-- Avkommentera och kör detta om tabellen inte finns:

-- CREATE TABLE IF NOT EXISTS public.app_versions (
--     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--     platform TEXT NOT NULL UNIQUE CHECK (platform IN ('ios', 'android')),
--     minimum_version TEXT NOT NULL,
--     latest_version TEXT NOT NULL,
--     force_update BOOLEAN DEFAULT false,
--     created_at TIMESTAMPTZ DEFAULT NOW(),
--     updated_at TIMESTAMPTZ DEFAULT NOW()
-- );

-- -- Lägg till iOS rad
-- INSERT INTO public.app_versions (platform, minimum_version, latest_version, force_update)
-- VALUES ('ios', '103.0', '103.0', true)
-- ON CONFLICT (platform) DO UPDATE 
-- SET 
--     minimum_version = EXCLUDED.minimum_version,
--     latest_version = EXCLUDED.latest_version,
--     force_update = EXCLUDED.force_update,
--     updated_at = NOW();

-- -- Enable RLS
-- ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- -- Policy: Alla kan läsa
-- CREATE POLICY app_versions_select_all ON public.app_versions
--     FOR SELECT USING (true);













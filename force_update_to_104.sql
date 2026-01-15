-- =====================================================
-- FORCE UPDATE TO VERSION 104
-- =====================================================
-- Detta SQL-skript aktiverar force update till version 104.0
-- Alla användare med version 103.0 eller lägre måste uppdatera.

-- Steg 1: Kolla nuvarande inställningar
SELECT 
    id,
    min_version,
    force_update,
    update_message_sv,
    app_store_url,
    updated_at
FROM public.app_config
WHERE id = 1;

-- Steg 2: Aktivera force update till version 104.0
UPDATE public.app_config
SET 
    min_version = '104.0',
    force_update = true,
    update_message_sv = 'En ny version av Up&Down finns tillgänglig. Uppdatera för att fortsätta använda appen och få tillgång till nya funktioner! 💪',
    updated_at = NOW()
WHERE id = 1;

-- Steg 3: Verifiera att uppdateringen fungerade
SELECT 
    id,
    min_version,
    force_update,
    update_message_sv,
    app_store_url,
    updated_at
FROM public.app_config
WHERE id = 1;

-- =====================================================
-- FÖRVÄNTAD OUTPUT EFTER UPPDATERING:
-- =====================================================
-- id: 1
-- min_version: 104.0
-- force_update: true
-- update_message_sv: En ny version av Up&Down finns tillgänglig...
-- app_store_url: https://apps.apple.com/app/id6744919845
-- updated_at: (nuvarande tidsstämpel)

-- =====================================================
-- ATT STÄNGA AV FORCE UPDATE (efter alla har uppdaterat):
-- =====================================================
-- UPDATE public.app_config
-- SET 
--     force_update = false,
--     updated_at = NOW()
-- WHERE id = 1;

-- =====================================================
-- TROUBLESHOOTING:
-- =====================================================
-- Om tabellen inte finns, kör detta först:
-- 
-- CREATE TABLE IF NOT EXISTS public.app_config (
--     id INT PRIMARY KEY DEFAULT 1,
--     min_version TEXT NOT NULL DEFAULT '1.0',
--     recommended_version TEXT,
--     update_message_sv TEXT,
--     update_message_en TEXT,
--     force_update BOOLEAN DEFAULT false,
--     app_store_url TEXT DEFAULT 'https://apps.apple.com/app/id6744919845',
--     created_at TIMESTAMPTZ DEFAULT NOW(),
--     updated_at TIMESTAMPTZ DEFAULT NOW(),
--     CONSTRAINT single_row CHECK (id = 1)
-- );
-- 
-- INSERT INTO public.app_config (id, min_version, force_update)
-- VALUES (1, '1.0', false)
-- ON CONFLICT (id) DO NOTHING;
-- 
-- ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
-- 
-- CREATE POLICY "Anyone can read app config" ON public.app_config
--     FOR SELECT USING (true);
-- 
-- GRANT SELECT ON public.app_config TO anon;
-- GRANT SELECT ON public.app_config TO authenticated;













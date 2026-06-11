-- =====================================================
-- FORCE UPDATE TILL VERSION 192
-- =====================================================
-- Aktiverar force update: alla användare med version 191
-- eller lägre tvingas uppdatera till 192.

-- Steg 1: Kolla nuvarande inställningar (visar alla kolumner)
SELECT * FROM public.app_config;

-- Steg 2: Aktivera force update till version 192
UPDATE public.app_config
SET
    min_version = '192',
    force_update = true
WHERE id = (SELECT id FROM public.app_config LIMIT 1);

-- Steg 3: Verifiera
SELECT * FROM public.app_config;

-- =====================================================
-- ATT STÄNGA AV FORCE UPDATE (efter alla har uppdaterat):
-- =====================================================
-- UPDATE public.app_config
-- SET force_update = false
-- WHERE id = (SELECT id FROM public.app_config LIMIT 1);

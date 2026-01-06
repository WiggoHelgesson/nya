-- =====================================================
-- INAKTIVERA FORCE UPDATE
-- =====================================================
-- Använd denna när alla användare har uppdaterat till 103

-- INAKTIVERA FORCE UPDATE
UPDATE public.app_versions
SET 
    is_active = false,
    updated_at = NOW()
WHERE id = '17d4d743-691f-4af6-804e-3b18398c295b';

-- VERIFIERA
SELECT 
    minimum_required_version,
    current_version,
    is_active,
    CASE 
        WHEN is_active = false 
        THEN '✅ Force update INAKTIVERAD - användare kan använda äldre versioner'
        ELSE '⚠️ Force update fortfarande AKTIV'
    END as status
FROM public.app_versions
WHERE id = '17d4d743-691f-4af6-804e-3b18398c295b';

-- =====================================================
-- NOTERA:
-- =====================================================
-- minimum_required_version stannar på 103.0
-- Men is_active = false betyder att det inte längre är tvingande









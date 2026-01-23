-- =====================================================
-- ÅTERSTÄLL TILL VERSION 101 (FÖR TESTNING)
-- =====================================================
-- Använd denna om du vill testa force update-funktionen

-- ÅTERSTÄLL TILL 101
UPDATE public.app_versions
SET 
    minimum_required_version = '101.0',
    current_version = '101.0',
    is_active = true,
    updated_at = NOW()
WHERE id = '17d4d743-691f-4af6-804e-3b18398c295b';

-- VERIFIERA
SELECT 
    minimum_required_version,
    current_version,
    is_active,
    '✅ Återställd till 101' as status
FROM public.app_versions
WHERE id = '17d4d743-691f-4af6-804e-3b18398c295b';
















-- =====================================================
-- KOLLA APP_CONFIG STRUKTUR
-- =====================================================
-- Detta visar vad som faktiskt finns i tabellen

-- Steg 1: Visa alla rader (oavsett ID-typ)
SELECT * FROM public.app_config;

-- Steg 2: Visa tabellstruktur
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'app_config'
ORDER BY ordinal_position;

-- =====================================================
-- RESULTAT:
-- =====================================================
-- Kör detta och se vad id-kolumnen är för datatyp
-- (UUID eller INT)









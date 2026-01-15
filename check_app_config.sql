-- =====================================================
-- KOLLA APP CONFIG STATUS
-- =====================================================
-- Detta SQL-skript kollar status för force update-systemet

-- Steg 1: Kolla om tabellen finns
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'app_config'
) as table_exists;

-- Steg 2: Visa nuvarande konfiguration
SELECT 
    id,
    min_version,
    force_update,
    update_message_sv,
    app_store_url,
    created_at,
    updated_at
FROM public.app_config
WHERE id = 1;

-- Steg 3: Visa alla kolumner i tabellen (för felsökning)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'app_config'
ORDER BY ordinal_position;

-- =====================================================
-- FÖRVÄNTAD OUTPUT:
-- =====================================================
-- table_exists: true
-- id: 1
-- min_version: (nuvarande version, tex 103.0 eller 104.0)
-- force_update: (true eller false)
-- update_message_sv: (meddelande)
-- app_store_url: https://apps.apple.com/app/id6744919845

-- =====================================================
-- OM TABELLEN INTE FINNS:
-- =====================================================
-- Kör create_app_config.sql först för att skapa tabellen













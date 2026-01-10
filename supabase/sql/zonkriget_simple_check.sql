-- =====================================================
-- ZONKRIGET - ENKEL CHECK (SNABB VERSION)
-- =====================================================
-- Kör denna för att se status utan att ändra något

-- 1️⃣ KOLLA OM TABELLEN FINNS
SELECT 
    CASE 
        WHEN EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'territory_tiles')
        THEN '✅ Tabellen finns'
        ELSE '❌ Tabellen finns INTE'
    END as table_status;

-- 2️⃣ RÄKNA TILES OCH ÄGARE
SELECT 
    COUNT(*) as total_tiles,
    COUNT(DISTINCT owner_id) as unique_owners
FROM public.territory_tiles;

-- 3️⃣ KOLLA DUBBLETTER (SNABB VERSION)
SELECT COUNT(*) as duplicate_geometries
FROM (
    SELECT ST_AsText(geom), COUNT(*) as cnt
    FROM public.territory_tiles
    GROUP BY ST_AsText(geom)
    HAVING COUNT(*) > 1
) dups;

-- 4️⃣ KOLLA INDEX
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'territory_tiles'
ORDER BY indexname;












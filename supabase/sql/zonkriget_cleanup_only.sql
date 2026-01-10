-- =====================================================
-- ZONKRIGET - CLEANUP ONLY (SÄKER VERSION)
-- =====================================================
-- Kör denna för att bara rensa dubbletter utan att ändra struktur

-- 1️⃣ TA BORT DUBBLETTER
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Räkna dubbletter före cleanup
    SELECT COUNT(*) INTO deleted_count FROM (
        SELECT ST_AsText(geom), COUNT(*) as cnt
        FROM public.territory_tiles
        GROUP BY ST_AsText(geom)
        HAVING COUNT(*) > 1
    ) dups;
    
    RAISE NOTICE '📊 Found % duplicate geometries before cleanup', deleted_count;
    
    -- Ta bort tiles med samma geom (behåll senaste = högsta tile_id)
    DELETE FROM public.territory_tiles a
    WHERE a.tile_id NOT IN (
        SELECT MAX(b.tile_id)
        FROM public.territory_tiles b
        WHERE ST_Equals(a.geom, b.geom)
        GROUP BY ST_AsText(b.geom)
    );
    
    -- Räkna dubbletter efter cleanup
    SELECT COUNT(*) INTO deleted_count FROM (
        SELECT ST_AsText(geom), COUNT(*) as cnt
        FROM public.territory_tiles
        GROUP BY ST_AsText(geom)
        HAVING COUNT(*) > 1
    ) dups2;
    
    RAISE NOTICE '✅ Cleanup complete!';
    RAISE NOTICE '📊 Duplicates remaining: %', deleted_count;
END $$;

-- 2️⃣ VERIFIERA RESULTAT
SELECT 
    COUNT(*) as total_tiles,
    COUNT(DISTINCT owner_id) as unique_owners,
    (SELECT COUNT(*) FROM (
        SELECT ST_AsText(geom)
        FROM public.territory_tiles
        GROUP BY ST_AsText(geom)
        HAVING COUNT(*) > 1
    ) dups) as remaining_duplicates
FROM public.territory_tiles;












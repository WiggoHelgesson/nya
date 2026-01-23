-- =====================================================
-- ZONKRIGET - SNABB CLEANUP (OPTIMERAD VERSION)
-- =====================================================
-- Denna version är snabbare och hänger sig inte

-- 1️⃣ SKAPA INDEX (om de inte finns)
CREATE INDEX IF NOT EXISTS territory_tiles_owner_idx 
    ON public.territory_tiles(owner_id);

CREATE INDEX IF NOT EXISTS territory_tiles_geom_idx 
    ON public.territory_tiles USING GIST(geom);

CREATE INDEX IF NOT EXISTS territory_tiles_updated_idx 
    ON public.territory_tiles(last_updated_at DESC);

-- 2️⃣ RÄKNA FÖRE CLEANUP
SELECT 
    COUNT(*) as total_tiles_before,
    COUNT(DISTINCT owner_id) as unique_owners
FROM public.territory_tiles;

-- 3️⃣ ENKEL CLEANUP - TA BORT EXAKTA DUBBLETTER
-- Denna är mycket snabbare än ST_Equals-versionen
WITH duplicates AS (
    SELECT 
        tile_id,
        ROW_NUMBER() OVER (PARTITION BY ST_AsText(geom) ORDER BY last_updated_at DESC, tile_id DESC) as rn
    FROM public.territory_tiles
)
DELETE FROM public.territory_tiles
WHERE tile_id IN (
    SELECT tile_id 
    FROM duplicates 
    WHERE rn > 1
);

-- 4️⃣ RÄKNA EFTER CLEANUP
SELECT 
    COUNT(*) as total_tiles_after,
    COUNT(DISTINCT owner_id) as unique_owners,
    (SELECT COUNT(*) FROM (
        SELECT ST_AsText(geom)
        FROM public.territory_tiles
        GROUP BY ST_AsText(geom)
        HAVING COUNT(*) > 1
    ) dups) as remaining_duplicates
FROM public.territory_tiles;

-- =====================================================
-- ✅ CLEANUP COMPLETE!
-- =====================================================
















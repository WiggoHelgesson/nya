-- Create a function to fetch the leaderboard based on territory tiles
-- This ensures the leaderboard reflects the new grid-based system where overlaps are handled by tile ownership.
-- Now returns tile_count for ranking by number of tiles

DROP FUNCTION IF EXISTS public.get_leaderboard(integer);

CREATE OR REPLACE FUNCTION public.get_leaderboard(
    limit_count integer DEFAULT 20
)
RETURNS TABLE (
    owner_id uuid,
    area_m2 double precision,
    tile_count bigint,
    username text,
    avatar_url text,
    is_pro boolean
) AS $$
BEGIN
    RETURN QUERY
    WITH owner_stats AS (
        SELECT 
            t.owner_id, 
            COUNT(*)::bigint as tiles,
            SUM(ST_Area(t.geom::geography)) as total_area
        FROM public.territory_tiles t
        WHERE t.owner_id IS NOT NULL
        GROUP BY t.owner_id
    )
    SELECT 
        os.owner_id,
        os.total_area as area_m2,
        os.tiles as tile_count,
        p.username,
        p.avatar_url,
        COALESCE(p.is_pro, false) as is_pro
    FROM owner_stats os
    LEFT JOIN public.profiles p ON os.owner_id = p.id
    ORDER BY os.tiles DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_leaderboard(integer) TO authenticated;

-- Drop existing view to allow column changes
DROP VIEW IF EXISTS public.territory_owners;

-- Ensure the view for map display is correct and based on tiles
-- This ensures the map shows unified territories without overlaps
CREATE OR REPLACE VIEW public.territory_owners AS
SELECT 
    owner_id,
    SUM(ST_Area(geom::geography)) as area_m2,
    ST_Union(geom) as geom,
    MAX(last_updated_at) as last_claim
FROM public.territory_tiles
WHERE owner_id IS NOT NULL
GROUP BY owner_id;

GRANT SELECT ON public.territory_owners TO authenticated;

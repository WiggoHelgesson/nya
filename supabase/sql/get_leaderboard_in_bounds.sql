-- Get leaderboard for tiles within a specific bounding box (city/area)
-- This ensures correct profile data is joined with the correct owner
-- Returns tile_count instead of area for leaderboard ranking

DROP FUNCTION IF EXISTS public.get_leaderboard_in_bounds(double precision, double precision, double precision, double precision, integer);

CREATE OR REPLACE FUNCTION public.get_leaderboard_in_bounds(
    min_lat double precision,
    min_lon double precision,
    max_lat double precision,
    max_lon double precision,
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
        -- Calculate total tiles and area per owner ONLY for tiles within the bounding box
        SELECT 
            t.owner_id as oid, 
            COUNT(*)::bigint as tiles,
            SUM(ST_Area(t.geom::geography)) as total_area
        FROM public.territory_tiles t
        WHERE t.owner_id IS NOT NULL
          AND t.geom && ST_MakeEnvelope(min_lon, min_lat, max_lon, max_lat, 4326)
        GROUP BY t.owner_id
    )
    SELECT 
        os.oid as owner_id,
        os.total_area as area_m2,
        os.tiles as tile_count,
        p.username,
        p.avatar_url,
        COALESCE(p.is_pro, false) as is_pro
    FROM owner_stats os
    -- IMPORTANT: Join profiles on the OWNER ID, not any other column
    LEFT JOIN public.profiles p ON os.oid = p.id
    ORDER BY os.tiles DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION public.get_leaderboard_in_bounds(double precision, double precision, double precision, double precision, integer) TO authenticated;


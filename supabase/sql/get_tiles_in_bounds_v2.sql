-- Paged tiles fetch for Zonkriget (avoids PostgREST max-rows truncation)
-- Returns tiles within a bounding box, with LIMIT/OFFSET pagination.
--
-- Required because RPC results are often capped (e.g. 1000 rows) by the API layer.
-- Client will call this repeatedly with p_offset until all rows are fetched.

DROP FUNCTION IF EXISTS public.get_tiles_in_bounds_v2(
    double precision,
    double precision,
    double precision,
    double precision,
    integer,
    integer
);

CREATE OR REPLACE FUNCTION public.get_tiles_in_bounds_v2(
    p_min_lat double precision,
    p_min_lon double precision,
    p_max_lat double precision,
    p_max_lon double precision,
    p_limit integer DEFAULT 1000,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    tile_id bigint,
    owner_id uuid,
    activity_id uuid,
    distance_km double precision,
    duration_sec integer,
    pace text,
    geom jsonb,
    last_updated_at timestamptz
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.tile_id,
        t.owner_id,
        t.activity_id,
        t.distance_km,
        t.duration_sec,
        t.pace,
        ST_AsGeoJSON(t.geom)::jsonb AS geom,
        t.last_updated_at
    FROM public.territory_tiles t
    WHERE t.geom && ST_MakeEnvelope(p_min_lon, p_min_lat, p_max_lon, p_max_lat, 4326)
    ORDER BY t.tile_id
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_tiles_in_bounds_v2(
    double precision,
    double precision,
    double precision,
    double precision,
    integer,
    integer
) TO authenticated;

-- Helpful indices (safe to run multiple times)
CREATE INDEX IF NOT EXISTS idx_territory_tiles_geom ON public.territory_tiles USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_territory_tiles_tile_id ON public.territory_tiles (tile_id);



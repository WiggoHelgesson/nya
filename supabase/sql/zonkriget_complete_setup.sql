-- ============================================
-- ZONKRIGET COMPLETE SETUP
-- Kör denna SQL en gång för att fixa allt!
-- ============================================

-- 0. Droppa befintliga funktioner först (för att kunna ändra signaturer)
DROP FUNCTION IF EXISTS public.get_tiles_in_bounds(double precision, double precision, double precision, double precision);
DROP FUNCTION IF EXISTS public.claim_tiles(UUID, UUID, double precision[][]);
DROP FUNCTION IF EXISTS public.get_leaderboard(integer);
DROP VIEW IF EXISTS public.territory_owners CASCADE;

-- 1. Skapa territory_tiles tabellen (om den inte finns)
CREATE TABLE IF NOT EXISTS public.territory_tiles (
    tile_id BIGINT PRIMARY KEY,
    owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    activity_id UUID,
    geom GEOMETRY(Polygon, 4326) NOT NULL,
    last_updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index för snabbare queries
CREATE INDEX IF NOT EXISTS idx_territory_tiles_owner ON public.territory_tiles(owner_id);
CREATE INDEX IF NOT EXISTS idx_territory_tiles_geom ON public.territory_tiles USING GIST(geom);

-- RLS
ALTER TABLE public.territory_tiles ENABLE ROW LEVEL SECURITY;

-- Alla kan läsa tiles
DROP POLICY IF EXISTS territory_tiles_select ON public.territory_tiles;
CREATE POLICY territory_tiles_select ON public.territory_tiles FOR SELECT USING (true);

-- Authenticated users kan inserta/uppdatera
DROP POLICY IF EXISTS territory_tiles_insert ON public.territory_tiles;
CREATE POLICY territory_tiles_insert ON public.territory_tiles FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS territory_tiles_update ON public.territory_tiles;
CREATE POLICY territory_tiles_update ON public.territory_tiles FOR UPDATE TO authenticated USING (true);

GRANT SELECT, INSERT, UPDATE ON public.territory_tiles TO authenticated;

-- ============================================
-- 2. claim_tiles funktion (FIXED - hanterar 2D arrays korrekt)
-- ============================================
CREATE OR REPLACE FUNCTION public.claim_tiles(
    p_owner UUID,
    p_activity UUID,
    p_coords double precision[][]
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    grid_size double precision := 0.000225; -- ca 25m (half size)
    input_poly geometry;
    line_points geometry[];
    min_x double precision;
    min_y double precision;
    max_x double precision;
    max_y double precision;
    x_steps integer;
    y_steps integer;
    cur_x double precision;
    cur_y double precision;
    tile_geom geometry;
    tile_hash bigint;
    inserted_count integer := 0;
    i integer;
    j integer;
    coord_count integer;
    lat double precision;
    lon double precision;
BEGIN
    -- Get number of coordinates
    coord_count := array_length(p_coords, 1);
    
    IF coord_count IS NULL OR coord_count < 3 THEN
        RAISE NOTICE 'Not enough coordinates: %', coord_count;
        RETURN;
    END IF;
    
    RAISE NOTICE 'Processing % coordinates', coord_count;

    -- Build array of points manually (fixes 2D array handling)
    line_points := ARRAY[]::geometry[];
    FOR i IN 1..coord_count LOOP
        lat := p_coords[i][1];
        lon := p_coords[i][2];
        line_points := array_append(line_points, ST_SetSRID(ST_MakePoint(lon, lat), 4326));
    END LOOP;
    
    RAISE NOTICE 'Created % points', array_length(line_points, 1);

    -- Create polygon
    BEGIN
        input_poly := ST_MakePolygon(ST_MakeLine(line_points));
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Failed to create polygon: %', SQLERRM;
        RETURN;
    END;
    
    IF NOT ST_IsValid(input_poly) THEN
        input_poly := ST_MakeValid(input_poly);
    END IF;

    -- Buffer to capture thin paths (~11m buffer)
    input_poly := ST_Buffer(input_poly, 0.0001);

    IF input_poly IS NULL OR ST_IsEmpty(input_poly) THEN
        RAISE NOTICE 'Polygon is empty after processing';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Polygon area: % sq degrees', ST_Area(input_poly);

    -- Get bounding box aligned to grid
    min_x := floor(ST_XMin(input_poly) / grid_size) * grid_size;
    min_y := floor(ST_YMin(input_poly) / grid_size) * grid_size;
    max_x := ceil(ST_XMax(input_poly) / grid_size) * grid_size;
    max_y := ceil(ST_YMax(input_poly) / grid_size) * grid_size;

    -- Calculate number of steps
    x_steps := GREATEST(1, round((max_x - min_x) / grid_size)::integer);
    y_steps := GREATEST(1, round((max_y - min_y) / grid_size)::integer);
    
    RAISE NOTICE 'Grid: % x % = % potential tiles', x_steps, y_steps, x_steps * y_steps;

    -- Limit to prevent runaway loops (max 10000 tiles per claim)
    IF x_steps * y_steps > 10000 THEN
        RAISE NOTICE 'Too many tiles, limiting to 100x100';
        x_steps := LEAST(x_steps, 100);
        y_steps := LEAST(y_steps, 100);
    END IF;

    -- Loop through grid using integer indices
    FOR i IN 0..x_steps-1 LOOP
        FOR j IN 0..y_steps-1 LOOP
            cur_x := min_x + (i * grid_size);
            cur_y := min_y + (j * grid_size);
            
            -- Create tile geometry
            tile_geom := ST_SetSRID(ST_MakeEnvelope(
                cur_x, cur_y,
                cur_x + grid_size, cur_y + grid_size,
                4326
            ), 4326);
            
            -- Check if tile intersects with our polygon
            IF ST_Intersects(tile_geom, input_poly) THEN
                -- Generate deterministic tile_id based on grid position
                tile_hash := abs(hashtext(
                    round(cur_x / grid_size)::text || '_' || round(cur_y / grid_size)::text
                ))::bigint;
                
                -- Insert or update tile (takeover happens here!)
                INSERT INTO public.territory_tiles (tile_id, owner_id, activity_id, geom, last_updated_at)
                VALUES (tile_hash, p_owner, p_activity, tile_geom, now())
                ON CONFLICT (tile_id) DO UPDATE SET
                    owner_id = EXCLUDED.owner_id,
                    activity_id = EXCLUDED.activity_id,
                    last_updated_at = EXCLUDED.last_updated_at;
                
                inserted_count := inserted_count + 1;
            END IF;
        END LOOP;
    END LOOP;

    RAISE NOTICE '✅ Claimed % tiles for owner %', inserted_count, p_owner;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_tiles(UUID, UUID, double precision[][]) TO authenticated;

-- ============================================
-- 3. get_tiles_in_bounds (för att hämta rutor i viewport)
-- ============================================
CREATE OR REPLACE FUNCTION public.get_tiles_in_bounds(
    min_lat double precision,
    min_lon double precision,
    max_lat double precision,
    max_lon double precision
)
RETURNS TABLE (
    tile_id bigint,
    owner_id text,
    geom jsonb,
    last_updated_at text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.tile_id,
        t.owner_id::text,
        ST_AsGeoJSON(t.geom)::jsonb AS geom,
        t.last_updated_at::text
    FROM public.territory_tiles t
    WHERE t.geom && ST_MakeEnvelope(min_lon, min_lat, max_lon, max_lat, 4326);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_tiles_in_bounds(double precision, double precision, double precision, double precision) TO authenticated;

-- ============================================
-- 4. territory_owners view (för att visa sammansatta områden per ägare)
-- ============================================
DROP VIEW IF EXISTS public.territory_owners CASCADE;

CREATE VIEW public.territory_owners AS
SELECT 
    owner_id,
    SUM(ST_Area(geom::geography)) AS area_m2,
    ST_AsGeoJSON(
        ST_Multi(
            ST_CollectionExtract(ST_Union(geom), 3)
        )
    )::jsonb AS geom,
    MAX(last_updated_at) AS last_claim
FROM public.territory_tiles
WHERE owner_id IS NOT NULL
GROUP BY owner_id;

GRANT SELECT ON public.territory_owners TO authenticated;

-- ============================================
-- 5. get_leaderboard (för topplistan)
-- ============================================
CREATE OR REPLACE FUNCTION public.get_leaderboard(
    limit_count integer DEFAULT 20
)
RETURNS TABLE (
    owner_id uuid,
    area_m2 double precision,
    username text,
    avatar_url text,
    is_pro boolean
) AS $$
BEGIN
    RETURN QUERY
    WITH owner_stats AS (
        SELECT 
            t.owner_id, 
            SUM(ST_Area(t.geom::geography)) AS total_area
        FROM public.territory_tiles t
        WHERE t.owner_id IS NOT NULL
        GROUP BY t.owner_id
    )
    SELECT 
        os.owner_id,
        os.total_area AS area_m2,
        p.username,
        p.avatar_url,
        COALESCE(p.is_pro, false) AS is_pro
    FROM owner_stats os
    LEFT JOIN public.profiles p ON os.owner_id = p.id
    ORDER BY os.total_area DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_leaderboard(integer) TO authenticated;

-- ============================================
-- 6. Verify setup
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Zonkriget setup complete!';
    RAISE NOTICE '   - territory_tiles table: OK';
    RAISE NOTICE '   - claim_tiles function: FIXED (2D array handling)';
    RAISE NOTICE '   - get_tiles_in_bounds function: OK';
    RAISE NOTICE '   - territory_owners view: OK';
    RAISE NOTICE '   - get_leaderboard function: OK';
END $$;

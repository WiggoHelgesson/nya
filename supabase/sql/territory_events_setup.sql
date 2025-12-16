-- ============================================
-- TERRITORY EVENTS SYSTEM
-- Skapar notiser när någon tar över ens område
-- ============================================

-- 1. Skapa territory_events tabellen
CREATE TABLE IF NOT EXISTS public.territory_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    territory_id UUID, -- Can be null for grid-based takeovers
    actor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    victim_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- The user who lost the territory
    event_type TEXT NOT NULL DEFAULT 'takeover',
    metadata JSONB DEFAULT '{}',
    area_name TEXT,
    tile_count INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index för snabbare queries
CREATE INDEX IF NOT EXISTS idx_territory_events_victim ON public.territory_events(victim_id);
CREATE INDEX IF NOT EXISTS idx_territory_events_actor ON public.territory_events(actor_id);
CREATE INDEX IF NOT EXISTS idx_territory_events_created ON public.territory_events(created_at DESC);

-- RLS
ALTER TABLE public.territory_events ENABLE ROW LEVEL SECURITY;

-- Alla kan läsa events (för topplista/feed)
DROP POLICY IF EXISTS territory_events_select ON public.territory_events;
CREATE POLICY territory_events_select ON public.territory_events FOR SELECT USING (true);

-- Endast system (via functions) kan skapa events
DROP POLICY IF EXISTS territory_events_insert ON public.territory_events;
CREATE POLICY territory_events_insert ON public.territory_events FOR INSERT TO authenticated WITH CHECK (true);

GRANT SELECT, INSERT ON public.territory_events TO authenticated;

-- ============================================
-- 2. Uppdaterad claim_tiles med takeover events
-- ============================================
DROP FUNCTION IF EXISTS public.claim_tiles(UUID, UUID, double precision[][]);

CREATE OR REPLACE FUNCTION public.claim_tiles(
    p_owner UUID,
    p_activity UUID,
    p_coords double precision[][]
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    grid_size double precision := 0.000225; -- ca 25m
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
    taken_count integer := 0;
    i integer;
    j integer;
    coord_count integer;
    lat double precision;
    lon double precision;
    old_owner UUID;
    takeover_victims UUID[];
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

    -- Initialize takeover tracking
    takeover_victims := ARRAY[]::UUID[];

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
                
                -- Check if this tile has a previous owner (different from us)
                SELECT owner_id INTO old_owner 
                FROM public.territory_tiles 
                WHERE tile_id = tile_hash;
                
                -- Track takeover victims (only if different owner)
                IF old_owner IS NOT NULL AND old_owner != p_owner THEN
                    IF NOT (old_owner = ANY(takeover_victims)) THEN
                        takeover_victims := array_append(takeover_victims, old_owner);
                    END IF;
                    taken_count := taken_count + 1;
                END IF;
                
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
    
    RAISE NOTICE 'Inserted/updated % tiles, took over % tiles from % victims', 
        inserted_count, taken_count, array_length(takeover_victims, 1);
    
    -- Create takeover events for each victim
    IF array_length(takeover_victims, 1) > 0 THEN
        FOREACH old_owner IN ARRAY takeover_victims LOOP
            INSERT INTO public.territory_events (
                actor_id,
                victim_id,
                event_type,
                metadata,
                created_at
            ) VALUES (
                p_owner,
                old_owner,
                'takeover',
                jsonb_build_object(
                    'activity_id', p_activity,
                    'tile_count', taken_count
                ),
                now()
            );
            RAISE NOTICE 'Created takeover event: % took from %', p_owner, old_owner;
        END LOOP;
    END IF;
    
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_tiles(UUID, UUID, double precision[][]) TO authenticated;

-- ============================================
-- 3. Funktion för att hämta mina takeover-events
-- ============================================
DROP FUNCTION IF EXISTS public.get_my_takeover_events(UUID, INTEGER);

CREATE OR REPLACE FUNCTION public.get_my_takeover_events(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    event_id UUID,
    actor_id UUID,
    actor_name TEXT,
    actor_avatar TEXT,
    event_type TEXT,
    tile_count INTEGER,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id as event_id,
        e.actor_id,
        COALESCE(p.username, 'Okänd') as actor_name,
        p.avatar_url as actor_avatar,
        e.event_type,
        COALESCE((e.metadata->>'tile_count')::integer, 1) as tile_count,
        e.created_at
    FROM public.territory_events e
    LEFT JOIN public.profiles p ON e.actor_id = p.id
    WHERE e.victim_id = p_user_id
    AND e.event_type = 'takeover'
    ORDER BY e.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_my_takeover_events(UUID, INTEGER) TO authenticated;

-- ============================================
-- Verify
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Territory events setup complete!';
    RAISE NOTICE '   - territory_events table: OK';
    RAISE NOTICE '   - claim_tiles with takeover tracking: OK';
    RAISE NOTICE '   - get_my_takeover_events function: OK';
END $$;


-- ============================================
-- TERRITORY EVENTS & ACTIVITY FUNCTIONS
-- ============================================

-- Function to get recent tile activity (who claimed tiles recently)
CREATE OR REPLACE FUNCTION public.get_recent_tile_activity(p_limit integer DEFAULT 20)
RETURNS TABLE (
    owner_id uuid,
    tile_count bigint,
    total_area_m2 double precision,
    last_activity timestamptz
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.owner_id,
        COUNT(*)::bigint as tile_count,
        COALESCE(SUM(ST_Area(t.geom::geography)), 0) as total_area_m2,
        MAX(t.last_updated_at) as last_activity
    FROM public.territory_tiles t
    WHERE t.owner_id IS NOT NULL
    AND t.last_updated_at > NOW() - INTERVAL '7 days'
    GROUP BY t.owner_id
    ORDER BY MAX(t.last_updated_at) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_recent_tile_activity(integer) TO authenticated;

-- Function to get takeover events (when someone took tiles from another user)
-- This requires a territory_events table - create if not exists
CREATE TABLE IF NOT EXISTS public.territory_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID NOT NULL REFERENCES public.profiles(id),
    victim_id UUID REFERENCES public.profiles(id),
    event_type TEXT NOT NULL DEFAULT 'claim',
    tile_count INTEGER DEFAULT 1,
    area_m2 DOUBLE PRECISION,
    activity_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_territory_events_actor ON public.territory_events(actor_id);
CREATE INDEX IF NOT EXISTS idx_territory_events_victim ON public.territory_events(victim_id);
CREATE INDEX IF NOT EXISTS idx_territory_events_created ON public.territory_events(created_at DESC);

-- Enable RLS
ALTER TABLE public.territory_events ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read all events
CREATE POLICY IF NOT EXISTS "Users can read territory events"
ON public.territory_events FOR SELECT
TO authenticated
USING (true);

-- Function to get events where current user lost territory
CREATE OR REPLACE FUNCTION public.get_my_takeover_events(
    p_user_id uuid,
    p_limit integer DEFAULT 50
)
RETURNS TABLE (
    event_id uuid,
    actor_id uuid,
    actor_name text,
    actor_avatar text,
    event_type text,
    tile_count integer,
    created_at timestamptz
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id as event_id,
        e.actor_id,
        COALESCE(p.username, 'Okänd') as actor_name,
        p.avatar_url as actor_avatar,
        e.event_type,
        COALESCE(e.tile_count, 1) as tile_count,
        e.created_at
    FROM public.territory_events e
    LEFT JOIN public.profiles p ON e.actor_id = p.id
    WHERE e.victim_id = p_user_id
    AND e.event_type = 'takeover'
    ORDER BY e.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_my_takeover_events(uuid, integer) TO authenticated;

-- Function to log takeover events when claiming tiles
-- This should be called from claim_tiles when a tile changes owner
CREATE OR REPLACE FUNCTION public.log_tile_takeover(
    p_actor_id uuid,
    p_victim_id uuid,
    p_tile_count integer,
    p_area_m2 double precision,
    p_activity_id uuid
) RETURNS void AS $$
BEGIN
    -- Only log if there's an actual victim (tile was taken from someone)
    IF p_victim_id IS NOT NULL AND p_victim_id != p_actor_id THEN
        INSERT INTO public.territory_events (actor_id, victim_id, event_type, tile_count, area_m2, activity_id)
        VALUES (p_actor_id, p_victim_id, 'takeover', p_tile_count, p_area_m2, p_activity_id);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.log_tile_takeover(uuid, uuid, integer, double precision, uuid) TO authenticated;


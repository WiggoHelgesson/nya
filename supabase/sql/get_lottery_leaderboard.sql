-- ============================================
-- LOTTERY LEADERBOARD FUNCTION
-- Returns top users by lottery ticket count
-- Uses SAME calculation as get_lottery_stats
-- ============================================

DROP FUNCTION IF EXISTS public.get_lottery_leaderboard(integer);

CREATE OR REPLACE FUNCTION public.get_lottery_leaderboard(limit_count integer DEFAULT 20)
RETURNS TABLE (
    user_id text,
    name text,
    avatar_url text,
    ticket_count integer,
    is_pro boolean
) AS $$
BEGIN
    RETURN QUERY
    WITH user_tickets AS (
        SELECT 
            p.id as uid,
            COALESCE(p.username, 'Anonym') as user_name,
            p.avatar_url as user_avatar,
            COALESCE(p.is_pro_member, false) as user_is_pro,
            
            -- Territory tickets: calculate actual area in km² (1 km² = 1 ticket)
            COALESCE((
                SELECT SUM(ST_Area(t.geom::geography)) / 1000000.0
                FROM public.territory_tiles t
                WHERE t.owner_id = p.id
            ), 0) as territory_km2,
            
            -- Gym tickets: count gym sessions with >5000kg volume (same as get_lottery_stats)
            COALESCE((
                WITH gym_volumes AS (
                    SELECT 
                        wp.id,
                        COALESCE(
                            (
                                SELECT SUM(
                                    (e->>'sets')::integer * 
                                    COALESCE((
                                        SELECT AVG(val::numeric)
                                        FROM jsonb_array_elements_text(e->'kg') AS val
                                        WHERE val ~ '^[0-9.]+$'
                                    ), 0) *
                                    COALESCE((
                                        SELECT AVG(val::numeric)
                                        FROM jsonb_array_elements_text(e->'reps') AS val
                                        WHERE val ~ '^[0-9]+$'
                                    ), 0)
                                )
                                FROM jsonb_array_elements(wp.exercises_data) AS e
                            ), 0
                        ) as total_volume
                    FROM public.workout_posts wp
                    WHERE wp.user_id = p.id
                    AND wp.activity_type = 'Gympass'
                    AND wp.exercises_data IS NOT NULL
                )
                SELECT COUNT(*)
                FROM gym_volumes
                WHERE total_volume > 5000
            ), 0)::integer as gym_sessions,
            
            -- Booking tickets: 5 per confirmed/completed booking
            COALESCE((
                SELECT COUNT(*) * 5
                FROM public.trainer_bookings tb
                WHERE tb.student_id = p.id
                AND tb.status IN ('confirmed', 'completed')
            ), 0)::integer as booking_tix
            
        FROM public.profiles p
    )
    SELECT 
        ut.uid::text as user_id,
        ut.user_name as name,
        ut.user_avatar as avatar_url,
        (
            FLOOR(ut.territory_km2 * CASE WHEN ut.user_is_pro THEN 2.0 ELSE 1.0 END) +
            FLOOR(ut.gym_sessions * CASE WHEN ut.user_is_pro THEN 2.0 ELSE 1.0 END) +
            FLOOR(ut.booking_tix * CASE WHEN ut.user_is_pro THEN 2.0 ELSE 1.0 END)
        )::integer as ticket_count,
        ut.user_is_pro as is_pro
    FROM user_tickets ut
    WHERE (ut.territory_km2 + ut.gym_sessions + ut.booking_tix) > 0
    ORDER BY ticket_count DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_lottery_leaderboard(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_lottery_leaderboard(integer) TO anon;

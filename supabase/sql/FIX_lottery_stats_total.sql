-- =====================================================
-- FIX: get_lottery_stats - Räkna totala lotter KORREKT
-- =====================================================
-- Problem: Gym-lotter räknas FEL i global total (alla gympass istället av >5000kg)
-- Resultat: Visar 109 lotter men borde vara ~51

DROP FUNCTION IF EXISTS public.get_lottery_stats(uuid);

CREATE OR REPLACE FUNCTION public.get_lottery_stats(p_user_id uuid)
RETURNS TABLE (
    my_tickets integer,
    total_tickets integer,
    my_percentage double precision,
    territory_tickets integer,
    gym_tickets integer,
    booking_tickets integer
) AS $$
DECLARE
    user_is_pro boolean;
    multiplier double precision;
    
    user_territory_raw double precision;
    user_gym_raw integer;
    user_booking_raw integer;
    
    user_territory_tickets integer;
    user_gym_tickets integer;
    user_booking_tickets integer;
    user_total integer;
    
    global_total integer;
BEGIN
    -- Check if user is PRO
    SELECT COALESCE(is_pro_member, false) INTO user_is_pro
    FROM public.profiles
    WHERE id = p_user_id;
    
    multiplier := CASE WHEN user_is_pro THEN 2.0 ELSE 1.0 END;
    
    -- ============================================
    -- 1. USER'S TERRITORY TICKETS
    -- ============================================
    SELECT COALESCE(SUM(ST_Area(geom::geography)) / 1000000.0, 0)
    INTO user_territory_raw
    FROM public.territory_tiles
    WHERE owner_id = p_user_id;
    
    user_territory_tickets := FLOOR(user_territory_raw * multiplier)::integer;
    
    -- ============================================
    -- 2. USER'S GYM TICKETS (>5000kg only)
    -- ============================================
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
        WHERE wp.user_id = p_user_id
        AND wp.activity_type = 'Gympass'
        AND wp.exercises_data IS NOT NULL
    )
    SELECT COUNT(*)::integer INTO user_gym_raw
    FROM gym_volumes
    WHERE total_volume > 5000;
    
    user_gym_tickets := FLOOR(user_gym_raw * multiplier)::integer;
    
    -- ============================================
    -- 3. USER'S BOOKING TICKETS
    -- ============================================
    SELECT COALESCE(COUNT(*), 0)::integer * 5 INTO user_booking_raw
    FROM public.trainer_bookings
    WHERE student_id = p_user_id
    AND status IN ('confirmed', 'completed');
    
    user_booking_tickets := FLOOR(user_booking_raw * multiplier)::integer;
    
    user_total := user_territory_tickets + user_gym_tickets + user_booking_tickets;
    
    -- ============================================
    -- 4. GLOBAL TOTAL (FIXED!)
    -- ============================================
    -- FIX: Använd SAMMA logik som leaderboard (>5000kg check)
    WITH all_users_tickets AS (
        SELECT 
            p.id as user_id,
            COALESCE(p.is_pro_member, false) as is_pro,
            
            -- Territory tickets
            COALESCE((
                SELECT SUM(ST_Area(t.geom::geography)) / 1000000.0
                FROM public.territory_tiles t
                WHERE t.owner_id = p.id
            ), 0) as territory_km2,
            
            -- Gym tickets (FIXED: samma check som leaderboard)
            COALESCE((
                WITH gym_volumes AS (
                    SELECT 
                        COALESCE(
                            (
                                SELECT SUM(
                                    (e->>'sets')::integer * 
                                    COALESCE((SELECT AVG(val::numeric) FROM jsonb_array_elements_text(e->'kg') AS val WHERE val ~ '^[0-9.]+$'), 0) *
                                    COALESCE((SELECT AVG(val::numeric) FROM jsonb_array_elements_text(e->'reps') AS val WHERE val ~ '^[0-9]+$'), 0)
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
            ), 0) as gym_sessions,
            
            -- Booking tickets
            COALESCE((
                SELECT COUNT(*) * 5
                FROM public.trainer_bookings tb
                WHERE tb.student_id = p.id
                AND tb.status IN ('confirmed', 'completed')
            ), 0) as booking_tickets_raw
        FROM public.profiles p
    )
    SELECT COALESCE(SUM(
        FLOOR(territory_km2 * CASE WHEN is_pro THEN 2.0 ELSE 1.0 END) +
        FLOOR(gym_sessions * CASE WHEN is_pro THEN 2.0 ELSE 1.0 END) +
        FLOOR(booking_tickets_raw * CASE WHEN is_pro THEN 2.0 ELSE 1.0 END)
    ), 0)::integer INTO global_total
    FROM all_users_tickets;
    
    IF global_total < user_total THEN
        global_total := user_total;
    END IF;
    
    -- ============================================
    -- RETURN RESULTS
    -- ============================================
    RETURN QUERY SELECT 
        user_total as my_tickets,
        GREATEST(global_total, 1) as total_tickets,
        CASE 
            WHEN global_total > 0 THEN ROUND((user_total::numeric / global_total::numeric) * 100, 1)::double precision
            ELSE 0.0
        END as my_percentage,
        user_territory_tickets as territory_tickets,
        user_gym_tickets as gym_tickets,
        user_booking_tickets as booking_tickets;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_lottery_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_lottery_stats(uuid) TO anon;

-- =====================================================
-- TEST: Kolla att det funkar
-- =====================================================
-- SELECT * FROM get_lottery_stats('ditt-user-id-här');
-- Borde nu visa ~51 total_tickets istället för 109!












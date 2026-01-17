-- =====================================================
-- DEBUG: Varför matchar inte lotter på kort vs topplista?
-- =====================================================

-- Steg 1: Kolla vad get_lottery_stats säger (kortet: 109 totalt)
SELECT 
    '📊 LOTTERY STATS (KORTET)' as source,
    my_tickets,
    total_tickets,
    territory_tickets,
    gym_tickets,
    booking_tickets
FROM get_lottery_stats('02a5e37d-fa9c-4d6c-96b2-0de62919bd47'); -- Ersätt med ditt user_id

-- Steg 2: Kolla topp 20 från leaderboard
SELECT 
    '🏆 TOPPLISTAN' as source,
    user_id,
    name,
    ticket_count
FROM get_lottery_leaderboard(20)
ORDER BY ticket_count DESC;

-- Steg 3: SUMMA från topplistan
SELECT 
    '🧮 SUMMA TOPPLISTAN' as source,
    SUM(ticket_count) as total_from_leaderboard,
    COUNT(*) as antal_användare
FROM get_lottery_leaderboard(20);

-- Steg 4: Räkna ALLA användares lotter manuellt
WITH all_user_tickets AS (
    SELECT 
        p.id,
        p.username,
        COALESCE(p.is_pro_member, false) as is_pro,
        
        -- Territory (1 lott per km²)
        COALESCE((
            SELECT SUM(ST_Area(t.geom::geography)) / 1000000.0
            FROM public.territory_tiles t
            WHERE t.owner_id = p.id
        ), 0) as territory_km2,
        
        -- Gym (1 lott per >5000kg session)
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
            SELECT COUNT(*) FROM gym_volumes WHERE total_volume > 5000
        ), 0)::integer as gym_count,
        
        -- Bookings (5 lotter per bokning)
        COALESCE((
            SELECT COUNT(*) * 5
            FROM public.trainer_bookings tb
            WHERE tb.student_id = p.id
            AND tb.status IN ('confirmed', 'completed')
        ), 0)::integer as booking_count
        
    FROM public.profiles p
)
SELECT 
    '🔍 MANUELL RÄKNING' as source,
    COUNT(*) as antal_användare,
    SUM(
        FLOOR(territory_km2 * CASE WHEN is_pro THEN 2.0 ELSE 1.0 END) +
        FLOOR(gym_count * CASE WHEN is_pro THEN 2.0 ELSE 1.0 END) +
        FLOOR(booking_count * CASE WHEN is_pro THEN 2.0 ELSE 1.0 END)
    ) as totala_lotter,
    SUM(CASE WHEN (territory_km2 + gym_count + booking_count) > 0 THEN 1 ELSE 0 END) as användare_med_lotter
FROM all_user_tickets;

-- =====================================================
-- FÖRVÄNTAD OUTPUT:
-- =====================================================
-- LOTTERY STATS: total_tickets = 109
-- SUMMA TOPPLISTAN: Ska matcha om beräkningen är samma
-- MANUELL RÄKNING: Ska också vara 109
-- =====================================================














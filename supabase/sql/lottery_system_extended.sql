-- ============================================
-- ZONKRIGET LOTTERY SYSTEM - EXTENDED
-- Dragning: 1 April 2025
-- ============================================
-- Ticket sources:
-- 1. Territory: 1 km² = 1 ticket (Pro: 1.5x)
-- 2. Gym session: 1 ticket for >5000kg volume (max 1/day, Pro: 1.5x)
-- 3. Golf lesson booking: 5 tickets per booking (Pro: 1.5x)
-- ============================================

-- Create lottery_tickets table to track all ticket sources
CREATE TABLE IF NOT EXISTS public.lottery_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    source_type TEXT NOT NULL CHECK (source_type IN ('territory', 'gym', 'lesson')),
    source_id TEXT, -- Reference to the source (workout_post id, booking id, etc.)
    tickets INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(source_type, source_id) -- Prevent duplicate entries
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS lottery_tickets_user_id_idx ON public.lottery_tickets(user_id);
CREATE INDEX IF NOT EXISTS lottery_tickets_source_type_idx ON public.lottery_tickets(source_type);
CREATE INDEX IF NOT EXISTS lottery_tickets_created_at_idx ON public.lottery_tickets(created_at);

-- Enable RLS
ALTER TABLE public.lottery_tickets ENABLE ROW LEVEL SECURITY;

-- RLS policies
DROP POLICY IF EXISTS lottery_tickets_select ON public.lottery_tickets;
CREATE POLICY lottery_tickets_select ON public.lottery_tickets
    FOR SELECT USING (true);

DROP POLICY IF EXISTS lottery_tickets_insert ON public.lottery_tickets;
CREATE POLICY lottery_tickets_insert ON public.lottery_tickets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Grant access
GRANT SELECT, INSERT ON public.lottery_tickets TO authenticated;

-- ============================================
-- FUNCTION: Calculate total volume from exercises_data
-- ============================================
CREATE OR REPLACE FUNCTION calculate_workout_volume(exercises_data JSONB)
RETURNS NUMERIC AS $$
DECLARE
    exercise JSONB;
    kg_array JSONB;
    reps_array JSONB;
    i INTEGER;
    total_volume NUMERIC := 0;
BEGIN
    IF exercises_data IS NULL THEN
        RETURN 0;
    END IF;
    
    FOR exercise IN SELECT * FROM jsonb_array_elements(exercises_data)
    LOOP
        kg_array := exercise->'kg';
        reps_array := exercise->'reps';
        
        IF kg_array IS NOT NULL AND reps_array IS NOT NULL THEN
            FOR i IN 0..LEAST(jsonb_array_length(kg_array), jsonb_array_length(reps_array)) - 1
            LOOP
                total_volume := total_volume + 
                    (COALESCE((kg_array->i)::NUMERIC, 0) * COALESCE((reps_array->i)::INTEGER, 0));
            END LOOP;
        END IF;
    END LOOP;
    
    RETURN total_volume;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- FUNCTION: Award gym ticket (called when workout is saved)
-- ============================================
CREATE OR REPLACE FUNCTION award_gym_lottery_ticket()
RETURNS TRIGGER AS $$
DECLARE
    total_volume NUMERIC;
    is_pro BOOLEAN;
    tickets_to_award INTEGER;
    today_date DATE;
    existing_gym_ticket INTEGER;
BEGIN
    -- Only process gym sessions
    IF NEW.activity_type != 'Gympass' THEN
        RETURN NEW;
    END IF;
    
    -- Calculate total volume
    total_volume := calculate_workout_volume(NEW.exercises_data);
    
    -- Check if volume is over 5000kg
    IF total_volume < 5000 THEN
        RETURN NEW;
    END IF;
    
    -- Check if user already got a gym ticket today
    today_date := CURRENT_DATE;
    SELECT COUNT(*) INTO existing_gym_ticket
    FROM public.lottery_tickets
    WHERE user_id = NEW.user_id
      AND source_type = 'gym'
      AND DATE(created_at) = today_date;
    
    IF existing_gym_ticket > 0 THEN
        -- Already got a gym ticket today
        RETURN NEW;
    END IF;
    
    -- Check if user is Pro
    SELECT COALESCE(is_pro_member, false) INTO is_pro
    FROM public.profiles
    WHERE id = NEW.user_id;
    
    -- Calculate tickets (1 for regular, 1.5 rounded = 2 for Pro)
    IF is_pro THEN
        tickets_to_award := 2; -- 1 * 1.5 rounded up
    ELSE
        tickets_to_award := 1;
    END IF;
    
    -- Award ticket
    INSERT INTO public.lottery_tickets (user_id, source_type, source_id, tickets)
    VALUES (NEW.user_id, 'gym', NEW.id, tickets_to_award)
    ON CONFLICT (source_type, source_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for gym tickets
DROP TRIGGER IF EXISTS trg_award_gym_lottery_ticket ON public.workout_posts;
CREATE TRIGGER trg_award_gym_lottery_ticket
    AFTER INSERT ON public.workout_posts
    FOR EACH ROW
    EXECUTE FUNCTION award_gym_lottery_ticket();

-- ============================================
-- FUNCTION: Award lesson booking ticket (called when booking is confirmed)
-- ============================================
CREATE OR REPLACE FUNCTION award_lesson_lottery_ticket()
RETURNS TRIGGER AS $$
DECLARE
    is_pro BOOLEAN;
    tickets_to_award INTEGER;
BEGIN
    -- Only award when status changes to 'accepted'
    IF NEW.status != 'accepted' OR (OLD IS NOT NULL AND OLD.status = 'accepted') THEN
        RETURN NEW;
    END IF;
    
    -- Check if user is Pro
    SELECT COALESCE(is_pro_member, false) INTO is_pro
    FROM public.profiles
    WHERE id = NEW.student_id;
    
    -- Calculate tickets (5 for regular, 7.5 rounded = 8 for Pro)
    IF is_pro THEN
        tickets_to_award := 8; -- 5 * 1.5 rounded up
    ELSE
        tickets_to_award := 5;
    END IF;
    
    -- Award ticket
    INSERT INTO public.lottery_tickets (user_id, source_type, source_id, tickets)
    VALUES (NEW.student_id, 'lesson', NEW.id::TEXT, tickets_to_award)
    ON CONFLICT (source_type, source_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for lesson booking tickets
DROP TRIGGER IF EXISTS trg_award_lesson_lottery_ticket ON public.trainer_bookings;
CREATE TRIGGER trg_award_lesson_lottery_ticket
    AFTER INSERT OR UPDATE ON public.trainer_bookings
    FOR EACH ROW
    EXECUTE FUNCTION award_lesson_lottery_ticket();

-- ============================================
-- FUNCTION: Get lottery stats (includes all sources)
-- ============================================
CREATE OR REPLACE FUNCTION get_lottery_stats(p_user_id UUID)
RETURNS TABLE (
    my_tickets INTEGER,
    total_tickets INTEGER,
    my_percentage NUMERIC
) AS $$
DECLARE
    is_pro BOOLEAN;
    pro_multiplier NUMERIC;
    user_territory_tickets INTEGER;
    user_other_tickets INTEGER;
    all_territory_tickets INTEGER;
    all_other_tickets INTEGER;
    user_total INTEGER;
    total_all INTEGER;
BEGIN
    -- Check if user is Pro
    SELECT COALESCE(is_pro_member, false) INTO is_pro
    FROM public.profiles
    WHERE id = p_user_id;
    
    pro_multiplier := CASE WHEN is_pro THEN 1.5 ELSE 1.0 END;
    
    -- User's territory tickets (1 km² = 1 ticket, Pro gets 1.5x)
    SELECT FLOOR(COALESCE(SUM(area_m2) / 1000000, 0) * pro_multiplier)::INTEGER
    INTO user_territory_tickets
    FROM territories
    WHERE owner_id = p_user_id;
    
    -- User's other tickets (gym + lessons, already multiplied at creation)
    SELECT COALESCE(SUM(tickets), 0)::INTEGER
    INTO user_other_tickets
    FROM lottery_tickets
    WHERE user_id = p_user_id;
    
    -- Total territory tickets from all users (with Pro multipliers)
    SELECT COALESCE(SUM(
        FLOOR(t.area_m2 / 1000000) * 
        CASE WHEN COALESCE(p.is_pro_member, false) THEN 1.5 ELSE 1.0 END
    ), 0)::INTEGER
    INTO all_territory_tickets
    FROM territories t
    LEFT JOIN profiles p ON t.owner_id = p.id;
    
    -- Total other tickets from all users
    SELECT COALESCE(SUM(tickets), 0)::INTEGER
    INTO all_other_tickets
    FROM lottery_tickets;
    
    -- Calculate totals
    user_total := user_territory_tickets + user_other_tickets;
    total_all := all_territory_tickets + all_other_tickets;
    
    RETURN QUERY SELECT 
        user_total,
        total_all,
        CASE WHEN total_all > 0 
            THEN ROUND((user_total::NUMERIC / total_all) * 100, 2)
            ELSE 0::NUMERIC
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access
GRANT EXECUTE ON FUNCTION get_lottery_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_workout_volume(JSONB) TO authenticated;

-- ============================================
-- FUNCTION: Get detailed ticket breakdown
-- ============================================
CREATE OR REPLACE FUNCTION get_lottery_ticket_breakdown(p_user_id UUID)
RETURNS TABLE (
    territory_tickets INTEGER,
    gym_tickets INTEGER,
    lesson_tickets INTEGER,
    total_tickets INTEGER,
    is_pro BOOLEAN
) AS $$
DECLARE
    v_is_pro BOOLEAN;
    pro_multiplier NUMERIC;
    v_territory_tickets INTEGER;
    v_gym_tickets INTEGER;
    v_lesson_tickets INTEGER;
BEGIN
    -- Check if user is Pro
    SELECT COALESCE(is_pro_member, false) INTO v_is_pro
    FROM public.profiles
    WHERE id = p_user_id;
    
    pro_multiplier := CASE WHEN v_is_pro THEN 1.5 ELSE 1.0 END;
    
    -- Territory tickets
    SELECT FLOOR(COALESCE(SUM(area_m2) / 1000000, 0) * pro_multiplier)::INTEGER
    INTO v_territory_tickets
    FROM territories
    WHERE owner_id = p_user_id;
    
    -- Gym tickets
    SELECT COALESCE(SUM(tickets), 0)::INTEGER
    INTO v_gym_tickets
    FROM lottery_tickets
    WHERE user_id = p_user_id AND source_type = 'gym';
    
    -- Lesson tickets
    SELECT COALESCE(SUM(tickets), 0)::INTEGER
    INTO v_lesson_tickets
    FROM lottery_tickets
    WHERE user_id = p_user_id AND source_type = 'lesson';
    
    RETURN QUERY SELECT 
        v_territory_tickets,
        v_gym_tickets,
        v_lesson_tickets,
        v_territory_tickets + v_gym_tickets + v_lesson_tickets,
        v_is_pro;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_lottery_ticket_breakdown(UUID) TO authenticated;

-- ============================================
-- Test queries
-- ============================================
-- SELECT * FROM get_lottery_stats('00000000-0000-0000-0000-000000000000');
-- SELECT * FROM get_lottery_ticket_breakdown('00000000-0000-0000-0000-000000000000');


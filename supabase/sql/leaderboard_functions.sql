-- ============================================
-- LEADERBOARD RPC FUNCTIONS
-- Monthly leaderboards for workout count, running distance, and gym volume
-- ============================================

-- Drop existing functions first to allow return type changes
DROP FUNCTION IF EXISTS get_monthly_workout_count_leaderboard(TEXT, TEXT[]);
DROP FUNCTION IF EXISTS get_monthly_running_distance_leaderboard(TEXT, TEXT[]);
DROP FUNCTION IF EXISTS get_monthly_gym_volume_leaderboard(TEXT, TEXT[]);

-- 1. Most workouts this month
CREATE OR REPLACE FUNCTION get_monthly_workout_count_leaderboard(
    p_month TEXT,
    p_user_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE(user_id TEXT, workout_count BIGINT, username TEXT, avatar_url TEXT, is_pro_member BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        CAST(wp.user_id AS TEXT),
        COUNT(*)::BIGINT,
        CAST(p.username AS TEXT),
        CAST(p.avatar_url AS TEXT),
        COALESCE(p.is_pro_member, false)
    FROM workout_posts wp
    JOIN profiles p ON CAST(p.id AS TEXT) = CAST(wp.user_id AS TEXT)
    WHERE to_char(wp.created_at::timestamptz, 'YYYY-MM') = p_month
      AND (p_user_ids IS NULL OR CAST(wp.user_id AS TEXT) = ANY(p_user_ids))
    GROUP BY wp.user_id, p.username, p.avatar_url, p.is_pro_member
    ORDER BY COUNT(*) DESC
    LIMIT 20;
END;
$$;

-- 2. Most running distance this month (in km)
CREATE OR REPLACE FUNCTION get_monthly_running_distance_leaderboard(
    p_month TEXT,
    p_user_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE(user_id TEXT, total_distance DOUBLE PRECISION, username TEXT, avatar_url TEXT, is_pro_member BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        CAST(wp.user_id AS TEXT),
        COALESCE(SUM(wp.distance), 0)::DOUBLE PRECISION,
        CAST(p.username AS TEXT),
        CAST(p.avatar_url AS TEXT),
        COALESCE(p.is_pro_member, false)
    FROM workout_posts wp
    JOIN profiles p ON CAST(p.id AS TEXT) = CAST(wp.user_id AS TEXT)
    WHERE to_char(wp.created_at::timestamptz, 'YYYY-MM') = p_month
      AND LOWER(wp.activity_type) IN ('löppass', 'löpning', 'running')
      AND wp.distance IS NOT NULL
      AND wp.distance > 0
      AND (p_user_ids IS NULL OR CAST(wp.user_id AS TEXT) = ANY(p_user_ids))
    GROUP BY wp.user_id, p.username, p.avatar_url, p.is_pro_member
    ORDER BY SUM(wp.distance) DESC
    LIMIT 20;
END;
$$;

-- 3. Most total gym volume this month (sets x reps x kg)
CREATE OR REPLACE FUNCTION get_monthly_gym_volume_leaderboard(
    p_month TEXT,
    p_user_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE(user_id TEXT, total_volume NUMERIC, username TEXT, avatar_url TEXT, is_pro_member BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        CAST(wp.user_id AS TEXT),
        COALESCE(SUM(calculate_workout_volume(wp.exercises_data)), 0)::NUMERIC,
        CAST(p.username AS TEXT),
        CAST(p.avatar_url AS TEXT),
        COALESCE(p.is_pro_member, false)
    FROM workout_posts wp
    JOIN profiles p ON CAST(p.id AS TEXT) = CAST(wp.user_id AS TEXT)
    WHERE to_char(wp.created_at::timestamptz, 'YYYY-MM') = p_month
      AND LOWER(wp.activity_type) IN ('gympass', 'gym', 'strength', 'walking')
      AND wp.exercises_data IS NOT NULL
      AND (p_user_ids IS NULL OR CAST(wp.user_id AS TEXT) = ANY(p_user_ids))
    GROUP BY wp.user_id, p.username, p.avatar_url, p.is_pro_member
    ORDER BY SUM(calculate_workout_volume(wp.exercises_data)) DESC
    LIMIT 20;
END;
$$;

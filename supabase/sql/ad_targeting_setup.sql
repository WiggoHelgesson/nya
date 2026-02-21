-- ============================================
-- AD TARGETING: User Profile View + Campaign Targeting Columns
-- Kör hela detta script i Supabase SQL Editor
-- ============================================

-- ============================================
-- PART 0: Ensure all needed columns exist on profiles
-- ============================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS birth_date DATE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS weight_kg DOUBLE PRECISION;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS height_cm INT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS target_weight DOUBLE PRECISION;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fitness_goal TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS workouts_per_week TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS daily_calories_goal INT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS daily_protein_goal INT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS daily_carbs_goal INT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS daily_fat_goal INT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS golf_hcp INT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS daily_step_goal INT;

-- ============================================
-- PART 1: User Ad Profile View
-- Aggregates all valuable targeting data per user
-- ============================================

DROP VIEW IF EXISTS public.user_ad_profile;

CREATE OR REPLACE VIEW public.user_ad_profile AS
SELECT
  p.id AS user_id,
  p.gender,
  p.birth_date,
  CASE
    WHEN p.birth_date IS NOT NULL
    THEN EXTRACT(YEAR FROM age(now(), p.birth_date))::INT
    ELSE NULL
  END AS age,
  p.is_pro_member,
  p.current_level,
  p.current_xp,
  p.fitness_goal,
  p.workouts_per_week,
  p.weight_kg,
  p.height_cm,
  p.target_weight,
  p.golf_hcp,

  -- Sports derived from workout history (distinct activity types)
  COALESCE(wp_stats.sports, ARRAY[]::TEXT[]) AS sports,

  -- Workout engagement metrics
  COALESCE(wp_stats.total_workouts, 0) AS total_workouts,
  COALESCE(wp_stats.workouts_last_30d, 0) AS workouts_last_30d,
  wp_stats.last_workout_at,
  COALESCE(wp_stats.total_distance_km, 0) AS total_distance_km,

  -- Social engagement
  COALESCE(social.follower_count, 0) AS follower_count,
  COALESCE(social.following_count, 0) AS following_count,

  -- Wearable devices
  COALESCE(devices.providers, ARRAY[]::TEXT[]) AS connected_devices,

  -- Nutrition engagement
  COALESCE(nutrition.food_logs_last_7d, 0) AS food_logs_last_7d,
  COALESCE(nutrition.is_active_food_logger, false) AS is_active_food_logger,

  -- Purchase history
  COALESCE(purchases.total_purchases, 0) AS total_purchases

FROM public.profiles p

-- Workout stats
LEFT JOIN LATERAL (
  SELECT
    array_agg(DISTINCT w.activity_type) FILTER (WHERE w.activity_type IS NOT NULL) AS sports,
    COUNT(*)::INT AS total_workouts,
    COUNT(*) FILTER (WHERE w.created_at >= now() - INTERVAL '30 days')::INT AS workouts_last_30d,
    MAX(w.created_at) AS last_workout_at,
    ROUND(COALESCE(SUM(w.distance), 0)::NUMERIC, 1)::DOUBLE PRECISION AS total_distance_km
  FROM public.workout_posts w
  WHERE w.user_id = p.id
) wp_stats ON true

-- Social stats
LEFT JOIN LATERAL (
  SELECT
    (SELECT COUNT(*)::INT FROM public.user_follows WHERE following_id = p.id) AS follower_count,
    (SELECT COUNT(*)::INT FROM public.user_follows WHERE follower_id = p.id) AS following_count
) social ON true

-- Connected devices
LEFT JOIN LATERAL (
  SELECT
    array_agg(DISTINCT tc.provider) FILTER (WHERE tc.provider IS NOT NULL) AS providers
  FROM public.terra_connections tc
  WHERE tc.user_id = p.id AND tc.is_active = true
) devices ON true

-- Nutrition engagement
LEFT JOIN LATERAL (
  SELECT
    COUNT(*)::INT AS food_logs_last_7d,
    COUNT(*) > 0 AS is_active_food_logger
  FROM public.food_logs fl
  WHERE fl.user_id = p.id AND fl.logged_at >= now() - INTERVAL '7 days'
) nutrition ON true

-- Purchase history
LEFT JOIN LATERAL (
  SELECT COUNT(*)::INT AS total_purchases
  FROM public.purchases pu
  WHERE pu.user_id = p.id
) purchases ON true;

-- Grant read access
GRANT SELECT ON public.user_ad_profile TO authenticated;
GRANT SELECT ON public.user_ad_profile TO service_role;


-- ============================================
-- PART 2: Add targeting columns to ad_campaigns
-- ============================================

ALTER TABLE public.ad_campaigns
  ADD COLUMN IF NOT EXISTS target_genders TEXT[],
  ADD COLUMN IF NOT EXISTS target_age_min INT,
  ADD COLUMN IF NOT EXISTS target_age_max INT,
  ADD COLUMN IF NOT EXISTS target_sports TEXT[],
  ADD COLUMN IF NOT EXISTS target_is_pro BOOLEAN,
  ADD COLUMN IF NOT EXISTS target_fitness_goals TEXT[],
  ADD COLUMN IF NOT EXISTS target_min_level INT,
  ADD COLUMN IF NOT EXISTS target_max_level INT;

COMMENT ON COLUMN public.ad_campaigns.target_genders IS 'NULL = all genders. Array of: male, female, other';
COMMENT ON COLUMN public.ad_campaigns.target_age_min IS 'NULL = no minimum age';
COMMENT ON COLUMN public.ad_campaigns.target_age_max IS 'NULL = no maximum age';
COMMENT ON COLUMN public.ad_campaigns.target_sports IS 'NULL = all sports. Array of activity types: Gympass, Löppass, Golfrunda, etc.';
COMMENT ON COLUMN public.ad_campaigns.target_is_pro IS 'NULL = all users, true = pro only, false = free only';
COMMENT ON COLUMN public.ad_campaigns.target_fitness_goals IS 'NULL = all goals. Array of fitness_goal values';
COMMENT ON COLUMN public.ad_campaigns.target_min_level IS 'NULL = no minimum level';
COMMENT ON COLUMN public.ad_campaigns.target_max_level IS 'NULL = no maximum level';


-- ============================================
-- PART 3: RPC to get targeted ads for a user
-- Used by get-active-ads Edge Function
-- ============================================

CREATE OR REPLACE FUNCTION public.get_targeted_ads(
  p_format TEXT,
  p_user_id UUID DEFAULT NULL
)
RETURNS SETOF public.ad_campaigns
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_gender TEXT;
  v_age INT;
  v_is_pro BOOLEAN;
  v_level INT;
  v_sports TEXT[];
  v_fitness_goal TEXT;
BEGIN
  -- If no user_id provided, return all active ads for the format (no targeting)
  IF p_user_id IS NULL THEN
    RETURN QUERY
      SELECT * FROM public.ad_campaigns
      WHERE format = p_format
        AND status = 'active'
        AND start_date <= now()
        AND (end_date IS NULL OR end_date > now())
      ORDER BY daily_bid DESC;
    RETURN;
  END IF;

  -- Fetch user targeting profile (from cached table, falls back to view)
  SELECT
    uap.gender, uap.age, uap.is_pro_member, uap.current_level, uap.sports, uap.fitness_goal
  INTO
    v_gender, v_age, v_is_pro, v_level, v_sports, v_fitness_goal
  FROM public.user_ad_profiles uap
  WHERE uap.user_id = p_user_id;

  -- Return ads matching user profile
  RETURN QUERY
    SELECT c.* FROM public.ad_campaigns c
    WHERE c.format = p_format
      AND c.status = 'active'
      AND c.start_date <= now()
      AND (c.end_date IS NULL OR c.end_date > now())
      -- Gender targeting: NULL means all genders match
      AND (c.target_genders IS NULL OR v_gender = ANY(c.target_genders))
      -- Age targeting: NULL min/max means no bound
      AND (c.target_age_min IS NULL OR v_age >= c.target_age_min)
      AND (c.target_age_max IS NULL OR v_age <= c.target_age_max)
      -- Pro targeting: NULL means all users
      AND (c.target_is_pro IS NULL OR c.target_is_pro = v_is_pro)
      -- Level targeting: NULL min/max means no bound
      AND (c.target_min_level IS NULL OR v_level >= c.target_min_level)
      AND (c.target_max_level IS NULL OR v_level <= c.target_max_level)
      -- Sports targeting: NULL means all, otherwise at least one overlap
      AND (c.target_sports IS NULL OR c.target_sports && v_sports)
      -- Fitness goal targeting: NULL means all
      AND (c.target_fitness_goals IS NULL OR v_fitness_goal = ANY(c.target_fitness_goals))
    ORDER BY c.daily_bid DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_targeted_ads(TEXT, UUID) TO service_role;

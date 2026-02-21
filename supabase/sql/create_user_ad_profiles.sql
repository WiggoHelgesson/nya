-- ============================================
-- USER AD PROFILES: Cached targeting data per user
-- Kör hela detta script i Supabase SQL Editor
-- ============================================

-- 1. Skapa tabellen
CREATE TABLE IF NOT EXISTS public.user_ad_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  gender TEXT,
  age INT,
  is_pro_member BOOLEAN DEFAULT false,
  current_level INT DEFAULT 0,
  fitness_goal TEXT,
  sports TEXT[] DEFAULT '{}',
  workouts_per_week NUMERIC(4,1) DEFAULT 0,
  total_workouts INT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Index för snabba targeting-queries
CREATE INDEX IF NOT EXISTS idx_uap_gender ON public.user_ad_profiles (gender);
CREATE INDEX IF NOT EXISTS idx_uap_age ON public.user_ad_profiles (age);
CREATE INDEX IF NOT EXISTS idx_uap_sports ON public.user_ad_profiles USING GIN (sports);
CREATE INDEX IF NOT EXISTS idx_uap_pro ON public.user_ad_profiles (is_pro_member);
CREATE INDEX IF NOT EXISTS idx_uap_fitness_goal ON public.user_ad_profiles (fitness_goal);

-- 3. RLS
ALTER TABLE public.user_ad_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access" ON public.user_ad_profiles
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Users can read own ad profile" ON public.user_ad_profiles
  FOR SELECT USING (auth.uid() = user_id);

-- 4. Refresh-funktion: populerar/uppdaterar hela tabellen
CREATE OR REPLACE FUNCTION public.refresh_user_ad_profiles()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.user_ad_profiles (
    user_id, gender, age, is_pro_member, current_level,
    fitness_goal, sports, workouts_per_week, total_workouts, updated_at
  )
  SELECT
    p.id,
    p.gender,
    CASE
      WHEN p.birth_date IS NOT NULL
      THEN EXTRACT(YEAR FROM age(now(), p.birth_date))::INT
      ELSE NULL
    END,
    COALESCE(p.is_pro_member, false),
    COALESCE(p.current_level, 0),
    p.fitness_goal,
    COALESCE(ws.sports, ARRAY[]::TEXT[]),
    COALESCE(ws.workouts_per_week, 0),
    COALESCE(ws.total_workouts, 0),
    now()
  FROM public.profiles p
  LEFT JOIN LATERAL (
    SELECT
      array_agg(DISTINCT w.activity_type) FILTER (WHERE w.activity_type IS NOT NULL) AS sports,
      COUNT(*)::INT AS total_workouts,
      ROUND(
        COUNT(*) FILTER (WHERE w.created_at >= now() - INTERVAL '30 days')::NUMERIC / 4.3,
        1
      ) AS workouts_per_week
    FROM public.workout_posts w
    WHERE w.user_id = p.id
  ) ws ON true
  ON CONFLICT (user_id) DO UPDATE SET
    gender = EXCLUDED.gender,
    age = EXCLUDED.age,
    is_pro_member = EXCLUDED.is_pro_member,
    current_level = EXCLUDED.current_level,
    fitness_goal = EXCLUDED.fitness_goal,
    sports = EXCLUDED.sports,
    workouts_per_week = EXCLUDED.workouts_per_week,
    total_workouts = EXCLUDED.total_workouts,
    updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_user_ad_profiles() TO service_role;

-- 5. Kör första refresh direkt
SELECT public.refresh_user_ad_profiles();

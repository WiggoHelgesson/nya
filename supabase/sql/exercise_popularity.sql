-- Exercise Popularity Tracking System
-- Tracks how many times each exercise is used globally to show most popular first

-- ============================================
-- 1. Exercise Popularity Table
-- ============================================
CREATE TABLE IF NOT EXISTS exercise_popularity (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    exercise_id TEXT NOT NULL,
    exercise_name TEXT NOT NULL,
    body_part TEXT NOT NULL, -- chest, back, upper legs, etc.
    usage_count INTEGER NOT NULL DEFAULT 1,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(exercise_id)
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_exercise_popularity_body_part ON exercise_popularity(body_part);
CREATE INDEX IF NOT EXISTS idx_exercise_popularity_usage ON exercise_popularity(usage_count DESC);
CREATE INDEX IF NOT EXISTS idx_exercise_popularity_exercise_id ON exercise_popularity(exercise_id);

-- Enable RLS
ALTER TABLE exercise_popularity ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read popularity data
CREATE POLICY "Anyone can read exercise popularity" ON exercise_popularity
    FOR SELECT USING (true);

-- Policy: Authenticated users can insert/update (we'll use upsert)
CREATE POLICY "Authenticated users can track exercise usage" ON exercise_popularity
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update exercise usage" ON exercise_popularity
    FOR UPDATE USING (auth.uid() IS NOT NULL);

-- ============================================
-- 2. Function to increment exercise usage
-- ============================================
CREATE OR REPLACE FUNCTION increment_exercise_usage(
    p_exercise_id TEXT,
    p_exercise_name TEXT,
    p_body_part TEXT
)
RETURNS void AS $$
BEGIN
    INSERT INTO exercise_popularity (exercise_id, exercise_name, body_part, usage_count, last_used_at)
    VALUES (p_exercise_id, p_exercise_name, p_body_part, 1, NOW())
    ON CONFLICT (exercise_id) 
    DO UPDATE SET 
        usage_count = exercise_popularity.usage_count + 1,
        last_used_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 3. Function to get popular exercises by body part
-- ============================================
CREATE OR REPLACE FUNCTION get_popular_exercises(
    p_body_part TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    exercise_id TEXT,
    exercise_name TEXT,
    body_part TEXT,
    usage_count INTEGER
) AS $$
BEGIN
    IF p_body_part IS NULL OR p_body_part = 'all' THEN
        RETURN QUERY
        SELECT 
            ep.exercise_id,
            ep.exercise_name,
            ep.body_part,
            ep.usage_count
        FROM exercise_popularity ep
        ORDER BY ep.usage_count DESC
        LIMIT p_limit;
    ELSE
        RETURN QUERY
        SELECT 
            ep.exercise_id,
            ep.exercise_name,
            ep.body_part,
            ep.usage_count
        FROM exercise_popularity ep
        WHERE ep.body_part = p_body_part
        ORDER BY ep.usage_count DESC
        LIMIT p_limit;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 4. Function to batch increment multiple exercises
-- ============================================
CREATE OR REPLACE FUNCTION increment_exercises_batch(
    p_exercises JSONB -- Array of {exercise_id, exercise_name, body_part}
)
RETURNS void AS $$
DECLARE
    exercise_record JSONB;
BEGIN
    FOR exercise_record IN SELECT * FROM jsonb_array_elements(p_exercises)
    LOOP
        PERFORM increment_exercise_usage(
            exercise_record->>'exercise_id',
            exercise_record->>'exercise_name',
            exercise_record->>'body_part'
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comment
COMMENT ON TABLE exercise_popularity IS 'Tracks global exercise usage to show most popular exercises first';
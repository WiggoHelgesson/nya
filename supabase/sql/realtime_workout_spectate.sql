-- Realtime Workout Spectate Feature
-- Allows friends to watch each other's workouts in real-time

-- ============================================
-- 1. Active Session Exercises (Real-time sync)
-- ============================================
CREATE TABLE IF NOT EXISTS active_session_exercises (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES active_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    exercise_id TEXT, -- Optional: reference to exercise database
    muscle_group TEXT,
    sets JSONB NOT NULL DEFAULT '[]', -- Array of {kg: number, reps: number, completed: boolean}
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    order_index INTEGER NOT NULL DEFAULT 0
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_active_session_exercises_session ON active_session_exercises(session_id);
CREATE INDEX IF NOT EXISTS idx_active_session_exercises_user ON active_session_exercises(user_id);

-- Enable RLS
ALTER TABLE active_session_exercises ENABLE ROW LEVEL SECURITY;

-- Policy: Users can manage their own exercises
CREATE POLICY "Users can insert own exercises" ON active_session_exercises
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update own exercises" ON active_session_exercises
    FOR UPDATE USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can delete own exercises" ON active_session_exercises
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Policy: Friends can view exercises (via follows)
CREATE POLICY "Friends can view exercises" ON active_session_exercises
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM follows
            WHERE follows.follower_id::text = auth.uid()::text
            AND follows.following_id = active_session_exercises.user_id
        )
        OR auth.uid()::text = user_id::text
    );

-- ============================================
-- 2. Session Spectators (Track who's watching)
-- ============================================
CREATE TABLE IF NOT EXISTS session_spectators (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES active_sessions(id) ON DELETE CASCADE,
    spectator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    started_watching_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_ping_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(session_id, spectator_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_session_spectators_session ON session_spectators(session_id);
CREATE INDEX IF NOT EXISTS idx_session_spectators_spectator ON session_spectators(spectator_id);

-- Enable RLS
ALTER TABLE session_spectators ENABLE ROW LEVEL SECURITY;

-- Policy: Users can add themselves as spectator
CREATE POLICY "Users can spectate" ON session_spectators
    FOR INSERT WITH CHECK (auth.uid()::text = spectator_id::text);

-- Policy: Users can update their own spectator entry (ping)
CREATE POLICY "Users can update own spectator entry" ON session_spectators
    FOR UPDATE USING (auth.uid()::text = spectator_id::text);

-- Policy: Users can remove themselves
CREATE POLICY "Users can stop spectating" ON session_spectators
    FOR DELETE USING (auth.uid()::text = spectator_id::text);

-- Policy: Session owner can see who's watching, spectators can see entry exists
CREATE POLICY "View spectators" ON session_spectators
    FOR SELECT USING (
        -- Session owner can see all spectators
        EXISTS (
            SELECT 1 FROM active_sessions
            WHERE active_sessions.id = session_spectators.session_id
            AND active_sessions.user_id::text = auth.uid()::text
        )
        -- Spectators can see their own entry
        OR auth.uid()::text = spectator_id::text
    );

-- ============================================
-- 3. Workout Cheers (Emoji reactions)
-- ============================================
CREATE TABLE IF NOT EXISTS workout_cheers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES active_sessions(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL DEFAULT '💪',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_workout_cheers_session ON workout_cheers(session_id);
CREATE INDEX IF NOT EXISTS idx_workout_cheers_to_user ON workout_cheers(to_user_id);
CREATE INDEX IF NOT EXISTS idx_workout_cheers_created ON workout_cheers(created_at);

-- Enable RLS
ALTER TABLE workout_cheers ENABLE ROW LEVEL SECURITY;

-- Policy: Users can send cheers to friends they follow
CREATE POLICY "Users can send cheers" ON workout_cheers
    FOR INSERT WITH CHECK (
        auth.uid()::text = from_user_id::text
        AND EXISTS (
            SELECT 1 FROM follows
            WHERE follows.follower_id::text = auth.uid()::text
            AND follows.following_id = workout_cheers.to_user_id
        )
    );

-- Policy: Users can see cheers sent to them or cheers they sent
CREATE POLICY "Users can view own cheers" ON workout_cheers
    FOR SELECT USING (
        auth.uid()::text = to_user_id::text
        OR auth.uid()::text = from_user_id::text
    );

-- ============================================
-- 4. Function to get spectator count
-- ============================================
CREATE OR REPLACE FUNCTION get_spectator_count(p_session_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM session_spectators
        WHERE session_id = p_session_id
        AND last_ping_at > NOW() - INTERVAL '2 minutes'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. Function to get recent cheers for a session
-- ============================================
CREATE OR REPLACE FUNCTION get_recent_cheers(p_session_id UUID, p_since TIMESTAMPTZ DEFAULT NOW() - INTERVAL '5 minutes')
RETURNS TABLE (
    id UUID,
    emoji TEXT,
    from_username TEXT,
    from_avatar_url TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wc.id,
        wc.emoji,
        p.username,
        p.avatar_url,
        wc.created_at
    FROM workout_cheers wc
    JOIN profiles p ON p.id = wc.from_user_id
    WHERE wc.session_id = p_session_id
    AND wc.created_at > p_since
    ORDER BY wc.created_at DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. Enable Realtime for tables
-- ============================================
-- Note: Run these in Supabase Dashboard > Database > Replication
-- ALTER PUBLICATION supabase_realtime ADD TABLE active_session_exercises;
-- ALTER PUBLICATION supabase_realtime ADD TABLE session_spectators;
-- ALTER PUBLICATION supabase_realtime ADD TABLE workout_cheers;

-- ============================================
-- 7. Cleanup function for stale spectators
-- ============================================
CREATE OR REPLACE FUNCTION cleanup_stale_spectators()
RETURNS void AS $$
BEGIN
    DELETE FROM session_spectators
    WHERE last_ping_at < NOW() - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql;

-- Comment
COMMENT ON TABLE active_session_exercises IS 'Stores exercises for active workout sessions in real-time';
COMMENT ON TABLE session_spectators IS 'Tracks users watching an active workout session';
COMMENT ON TABLE workout_cheers IS 'Emoji reactions sent to motivate friends during workouts';

-- Create active_sessions table to track users with ongoing workout sessions
-- This enables the "Active Friends" map feature

CREATE TABLE IF NOT EXISTS active_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL DEFAULT 'gym',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(user_id) -- One active session per user
);

-- Create index for fast lookup of active sessions
CREATE INDEX IF NOT EXISTS idx_active_sessions_user_id ON active_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_active_sessions_is_active ON active_sessions(is_active) WHERE is_active = TRUE;

-- Enable RLS
ALTER TABLE active_sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own sessions
CREATE POLICY "Users can insert own active session" ON active_sessions
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

-- Policy: Users can update their own sessions
CREATE POLICY "Users can update own active session" ON active_sessions
    FOR UPDATE USING (auth.uid()::text = user_id::text);

-- Policy: Users can delete their own sessions
CREATE POLICY "Users can delete own active session" ON active_sessions
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Policy: Users can view active sessions of users they follow
CREATE POLICY "Users can view followed users active sessions" ON active_sessions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM follows
            WHERE follows.follower_id::text = auth.uid()::text
            AND follows.following_id = active_sessions.user_id
        )
        OR auth.uid()::text = user_id::text
    );

-- Function to automatically clean up stale sessions (older than 6 hours)
CREATE OR REPLACE FUNCTION cleanup_stale_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM active_sessions
    WHERE updated_at < NOW() - INTERVAL '6 hours'
       OR started_at < NOW() - INTERVAL '12 hours';
END;
$$ LANGUAGE plpgsql;

-- Comment
COMMENT ON TABLE active_sessions IS 'Tracks active workout sessions for the Active Friends map feature';

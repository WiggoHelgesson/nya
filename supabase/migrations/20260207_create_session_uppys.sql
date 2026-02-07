-- Create session_uppys table for tracking motivation sent to friends during workouts
CREATE TABLE IF NOT EXISTS public.session_uppys (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES public.active_sessions(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    from_user_name TEXT NOT NULL,
    from_user_avatar TEXT,
    to_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one user can only send one uppy per session
    UNIQUE(session_id, from_user_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_session_uppys_session_id ON public.session_uppys(session_id);
CREATE INDEX IF NOT EXISTS idx_session_uppys_to_user_id ON public.session_uppys(to_user_id);
CREATE INDEX IF NOT EXISTS idx_session_uppys_created_at ON public.session_uppys(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.session_uppys ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read uppys for their own sessions
CREATE POLICY "Users can read uppys for their sessions"
    ON public.session_uppys
    FOR SELECT
    USING (
        to_user_id = auth.uid()
        OR from_user_id = auth.uid()
    );

-- Policy: Users can send uppys to friends
CREATE POLICY "Users can send uppys"
    ON public.session_uppys
    FOR INSERT
    WITH CHECK (from_user_id = auth.uid());

-- Policy: Users cannot update or delete uppys
-- (Uppys are permanent once sent)

-- Grant permissions
GRANT SELECT, INSERT ON public.session_uppys TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Comment on table
COMMENT ON TABLE public.session_uppys IS 'Stores motivation (Uppys) sent from friends to active workout sessions';

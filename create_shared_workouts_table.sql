-- Create shared_workouts table for sharing workout routines between friends
CREATE TABLE IF NOT EXISTS shared_workouts (
    id TEXT PRIMARY KEY,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_name TEXT NOT NULL,
    exercises_data JSONB NOT NULL,
    message TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_shared_workouts_sender_id ON shared_workouts(sender_id);
CREATE INDEX IF NOT EXISTS idx_shared_workouts_receiver_id ON shared_workouts(receiver_id);
CREATE INDEX IF NOT EXISTS idx_shared_workouts_created_at ON shared_workouts(created_at DESC);

-- Enable RLS
ALTER TABLE shared_workouts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read their shared workouts" ON shared_workouts;
DROP POLICY IF EXISTS "Users can send workouts" ON shared_workouts;
DROP POLICY IF EXISTS "Users can update received workouts" ON shared_workouts;
DROP POLICY IF EXISTS "Users can delete their shared workouts" ON shared_workouts;

-- Policy: Users can read workouts where they are sender or receiver
CREATE POLICY "Users can read their shared workouts"
    ON shared_workouts
    FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Policy: Users can insert workouts they send
CREATE POLICY "Users can send workouts"
    ON shared_workouts
    FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- Policy: Users can update workouts they received (for marking as read)
CREATE POLICY "Users can update received workouts"
    ON shared_workouts
    FOR UPDATE
    USING (auth.uid() = receiver_id);

-- Policy: Users can delete workouts they sent or received
CREATE POLICY "Users can delete their shared workouts"
    ON shared_workouts
    FOR DELETE
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

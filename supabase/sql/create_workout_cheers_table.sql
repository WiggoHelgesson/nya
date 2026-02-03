-- Create workout_cheers table for sending emojis to friends during workouts
-- Run this in Supabase SQL Editor

BEGIN;

-- Create the table if it doesn't exist
CREATE TABLE IF NOT EXISTS workout_cheers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    from_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    from_user_name TEXT NOT NULL DEFAULT '',
    to_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add from_user_name column if it doesn't exist (for existing tables)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'workout_cheers' AND column_name = 'from_user_name'
    ) THEN
        ALTER TABLE workout_cheers ADD COLUMN from_user_name TEXT NOT NULL DEFAULT '';
    END IF;
END $$;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_workout_cheers_to_user ON workout_cheers(to_user_id);
CREATE INDEX IF NOT EXISTS idx_workout_cheers_from_user ON workout_cheers(from_user_id);
CREATE INDEX IF NOT EXISTS idx_workout_cheers_created_at ON workout_cheers(created_at DESC);

-- Enable RLS
ALTER TABLE workout_cheers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read their own cheers" ON workout_cheers;
DROP POLICY IF EXISTS "Users can send cheers" ON workout_cheers;

-- Policy: Users can read cheers sent TO them
CREATE POLICY "Users can read their own cheers" ON workout_cheers
FOR SELECT TO authenticated
USING (auth.uid() = to_user_id OR auth.uid() = from_user_id);

-- Policy: Authenticated users can insert cheers (send to anyone)
CREATE POLICY "Users can send cheers" ON workout_cheers
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = from_user_id);

COMMIT;

-- Verify the table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'workout_cheers';

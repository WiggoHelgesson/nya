-- Add sharing toggle column to progress_photos
-- Run this in Supabase SQL Editor

ALTER TABLE progress_photos ADD COLUMN IF NOT EXISTS shared_on_profile BOOLEAN DEFAULT false;

-- Allow authenticated users to read other users' shared progress photos
DROP POLICY IF EXISTS "Users can read shared progress photos" ON progress_photos;
CREATE POLICY "Users can read shared progress photos"
ON progress_photos FOR SELECT TO authenticated
USING (shared_on_profile = true);

-- Allow users to update their own progress photos (for toggling sharing)
DROP POLICY IF EXISTS "Users can update their own progress photos" ON progress_photos;
CREATE POLICY "Users can update their own progress photos"
ON progress_photos FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

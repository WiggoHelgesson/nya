-- Create progress_photos table for storing user progress photos
-- Run this in Supabase SQL Editor

BEGIN;

-- Create the table
CREATE TABLE IF NOT EXISTS progress_photos (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    weight_kg DECIMAL(5,2) NOT NULL,
    photo_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_progress_photos_user_id ON progress_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_progress_photos_date ON progress_photos(photo_date DESC);

-- Enable RLS
ALTER TABLE progress_photos ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read their own progress photos" ON progress_photos;
DROP POLICY IF EXISTS "Users can insert their own progress photos" ON progress_photos;
DROP POLICY IF EXISTS "Users can delete their own progress photos" ON progress_photos;

-- Policy: Users can only read their own progress photos
CREATE POLICY "Users can read their own progress photos" ON progress_photos
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- Policy: Users can insert their own progress photos
CREATE POLICY "Users can insert their own progress photos" ON progress_photos
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own progress photos
CREATE POLICY "Users can delete their own progress photos" ON progress_photos
FOR DELETE TO authenticated
USING (auth.uid() = user_id);

COMMIT;

-- ============================================
-- STORAGE BUCKET SETUP (Run this separately!)
-- ============================================

-- First, create the storage bucket (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public)
VALUES ('progress-photos', 'progress-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Users can upload their own progress photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can read progress photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own progress photos storage" ON storage.objects;

-- Policy: Allow authenticated users to upload to their own folder
CREATE POLICY "Users can upload their own progress photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'progress-photos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow public read access to all progress photos
CREATE POLICY "Users can read progress photos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'progress-photos');

-- Policy: Allow users to delete their own photos
CREATE POLICY "Users can delete their own progress photos storage"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'progress-photos' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Verify storage bucket exists
SELECT * FROM storage.buckets WHERE id = 'progress-photos';

-- Add banner_url column to profiles table
-- This allows users to set a custom banner image for their profile

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS banner_url TEXT;

-- Add comment for documentation
COMMENT ON COLUMN profiles.banner_url IS 'URL path to user custom banner image stored in avatars bucket';

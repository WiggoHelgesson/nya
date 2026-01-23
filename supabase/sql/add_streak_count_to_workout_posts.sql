-- Add streak_count column to workout_posts table
-- This stores the user's streak count when the workout was posted
-- Used for displaying achievement banners in the social feed

ALTER TABLE workout_posts
ADD COLUMN IF NOT EXISTS streak_count INTEGER DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN workout_posts.streak_count IS 'User streak count when workout was posted, for achievement banners';

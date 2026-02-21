-- Add is_public column to workout_posts (default true for backwards compatibility)
ALTER TABLE public.workout_posts ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true;

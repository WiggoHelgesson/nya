-- PRODUCTION: run this in Supabase SQL Editor (Dashboard → SQL) on the live project if not already applied.
-- Pair with workout_images_bucket_public_read.sql for full workout image fix.
--
-- Ensure workout post image URL columns can store full signed URLs (long ?token= query).
-- Run in Supabase SQL Editor after backup if needed.

ALTER TABLE public.workout_posts
  ALTER COLUMN image_url TYPE text USING image_url::text;

ALTER TABLE public.workout_posts
  ALTER COLUMN user_image_url TYPE text USING user_image_url::text;

COMMENT ON COLUMN public.workout_posts.image_url IS 'Route/workout image URL; use TEXT so signed URLs are not truncated.';
COMMENT ON COLUMN public.workout_posts.user_image_url IS 'User-uploaded workout image URL(s); TEXT supports long signed URLs or JSON array of URLs.';

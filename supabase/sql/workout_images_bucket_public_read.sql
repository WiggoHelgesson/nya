-- PRODUCTION: run this in Supabase SQL Editor on the live project if not already applied.
-- Pair with workout_posts_image_urls_text.sql so DB URLs are not truncated.
--
-- Preferens A from workout image fix: public read for workout-images bucket so feeds use
-- /storage/v1/object/public/... URLs without expiring tokens.
--
-- INFRA: Custom domain (e.g. api.upanddownapp.com) must forward all /storage/v1/* paths to Supabase
-- without stripping query strings on signed-URL routes.

UPDATE storage.buckets
SET public = true
WHERE id = 'workout-images';

DROP POLICY IF EXISTS "workout_images_public_select" ON storage.objects;
CREATE POLICY "workout_images_public_select" ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'workout-images');

-- Authenticated users can still upload (adjust if you use stricter ownership policies).
DROP POLICY IF EXISTS "workout_images_authenticated_insert" ON storage.objects;
CREATE POLICY "workout_images_authenticated_insert" ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'workout-images');

DROP POLICY IF EXISTS "workout_images_authenticated_update" ON storage.objects;
CREATE POLICY "workout_images_authenticated_update" ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'workout-images')
WITH CHECK (bucket_id = 'workout-images');

DROP POLICY IF EXISTS "workout_images_authenticated_delete" ON storage.objects;
CREATE POLICY "workout_images_authenticated_delete" ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'workout-images');

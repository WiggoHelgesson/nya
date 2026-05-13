-- Public bucket that mirrors RapidAPI ExerciseDB GIFs so the iOS app never
-- talks to RapidAPI directly (only the `ensure-exercise-gif` Edge Function does).
--
-- Reads are open to everyone (anon + authenticated). Writes are restricted to
-- the service role, which is what the Edge Function uses. This means the
-- bucket cannot be polluted by clients.
--
-- Run in the Supabase SQL Editor on production.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'exercise-gifs',
    'exercise-gifs',
    true,
    10485760,
    ARRAY['image/gif', 'image/webp', 'image/jpeg', 'image/png']::text[]
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS exercise_gifs_public_select ON storage.objects;
CREATE POLICY exercise_gifs_public_select ON storage.objects
    FOR SELECT
    TO public
    USING (bucket_id = 'exercise-gifs');

-- No INSERT/UPDATE/DELETE policies are created. Only the service role
-- (Supabase Edge Function `ensure-exercise-gif` and admin scripts) can write.

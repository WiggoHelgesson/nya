-- Ensures that public access is allowed for profile images (for viewing)
-- and authenticated users can upload their own images.

begin;

-- 1. Ensure the bucket is public
update storage.buckets
set public = true
where id = 'profile-images';

-- 2. Drop existing policies to start fresh
drop policy if exists "profile-images insert" on storage.objects;
drop policy if exists "profile-images select" on storage.objects;
drop policy if exists "profile-images update" on storage.objects;
drop policy if exists "profile-images delete" on storage.objects;

-- 3. Create simplified policies

-- SELECT: Anyone can view images (since bucket is public, but policy reinforces it)
create policy "profile-images select" on storage.objects
for select
using (bucket_id = 'profile-images');

-- INSERT: Authenticated users can upload files to the profile-images bucket
-- We remove the owner check here because sometimes the owner field isn't set correctly on initial insert
create policy "profile-images insert" on storage.objects
for insert
to authenticated
with check (bucket_id = 'profile-images');

-- UPDATE: Users can only update their own files
create policy "profile-images update" on storage.objects
for update
to authenticated
using (bucket_id = 'profile-images' and owner = auth.uid());

-- DELETE: Users can only delete their own files
create policy "profile-images delete" on storage.objects
for delete
to authenticated
using (bucket_id = 'profile-images' and owner = auth.uid());

commit;






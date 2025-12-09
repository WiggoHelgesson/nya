-- ULTIMATE FIX: Profile Image Upload
-- This script completely resets the profile-images bucket and policies
-- Run this in Supabase SQL Editor

begin;

-- 1. Drop the bucket entirely if it exists (to start completely fresh)
delete from storage.objects where bucket_id = 'profile-images';
delete from storage.buckets where id = 'profile-images';

-- 2. Create the bucket as public
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-images',
  'profile-images',
  true,
  5242880, -- 5MB limit
  array['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
);

-- 3. Create the simplest possible policies (authenticated users can do ANYTHING)
create policy "Allow authenticated users full access to profile-images"
on storage.objects
for all
to authenticated
using (bucket_id = 'profile-images')
with check (bucket_id = 'profile-images');

-- 4. Allow public to view
create policy "Allow public to view profile-images"
on storage.objects
for select
to public
using (bucket_id = 'profile-images');

commit;






-- FIX ALL SOCIAL FEATURES (Profile Images + Comments)
-- Run this entire script in Supabase SQL Editor to fix both issues at once.

begin;

-- ---------------------------------------------------------
-- 1. FIX PROFILE IMAGES (Allow all authenticated uploads)
-- ---------------------------------------------------------
update storage.buckets set public = true where id = 'profile-images';

-- Drop old strict policies to avoid conflicts
drop policy if exists "profile-images insert" on storage.objects;
drop policy if exists "profile-images select" on storage.objects;
drop policy if exists "profile-images update" on storage.objects;
drop policy if exists "profile-images delete" on storage.objects;
drop policy if exists "Give users access to own folder" on storage.objects;
drop policy if exists "profile_images_allow_all_auth" on storage.objects;
drop policy if exists "profile_images_allow_public_select" on storage.objects;

-- Create permissive policies
-- Allow authenticated users to do ANYTHING in the profile-images bucket (simplest fix)
create policy "profile_images_allow_all_auth" on storage.objects
for all
to authenticated
using (bucket_id = 'profile-images')
with check (bucket_id = 'profile-images');

-- Allow everyone (public) to VIEW images
create policy "profile_images_allow_public_select" on storage.objects
for select
to public
using (bucket_id = 'profile-images');


-- ---------------------------------------------------------
-- 2. FIX COMMENTS (Add missing columns and tables)
-- ---------------------------------------------------------

-- Add parent_comment_id for replies if it doesn't exist
do $$ 
begin 
    if not exists (select 1 from information_schema.columns where table_name = 'workout_post_comments' and column_name = 'parent_comment_id') then
        alter table workout_post_comments add column parent_comment_id uuid references workout_post_comments(id) on delete cascade;
    end if;
end $$;

-- Create table for comment likes if it doesn't exist
create table if not exists comment_likes (
    id uuid primary key default uuid_generate_v4(),
    comment_id uuid references workout_post_comments(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    created_at timestamp with time zone default now(),
    unique(comment_id, user_id)
);

alter table comment_likes enable row level security;

-- Policies for comment likes
drop policy if exists "comment_likes insert" on comment_likes;
create policy "comment_likes insert" on comment_likes for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "comment_likes delete" on comment_likes;
create policy "comment_likes delete" on comment_likes for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "comment_likes select" on comment_likes;
create policy "comment_likes select" on comment_likes for select to authenticated using (true);

commit;






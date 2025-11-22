-- Fix social features: Ensure likes and comments persist correctly
-- Run this in Supabase SQL Editor

begin;

-- 1. Ensure RLS policies exist for workout_post_likes
drop policy if exists "Users can insert their own likes" on workout_post_likes;
create policy "Users can insert their own likes" on workout_post_likes
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own likes" on workout_post_likes;
create policy "Users can delete their own likes" on workout_post_likes
for delete to authenticated
using (auth.uid() = user_id);

drop policy if exists "Anyone can view likes" on workout_post_likes;
create policy "Anyone can view likes" on workout_post_likes
for select to authenticated
using (true);

-- 2. Ensure RLS policies exist for workout_post_comments
drop policy if exists "Users can insert comments" on workout_post_comments;
create policy "Users can insert comments" on workout_post_comments
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own comments" on workout_post_comments;
create policy "Users can delete their own comments" on workout_post_comments
for delete to authenticated
using (auth.uid() = user_id);

drop policy if exists "Anyone can view comments" on workout_post_comments;
create policy "Anyone can view comments" on workout_post_comments
for select to authenticated
using (true);

-- 3. Create indexes for better performance (if they don't exist)
create index if not exists idx_workout_post_likes_post_id on workout_post_likes(workout_post_id);
create index if not exists idx_workout_post_likes_user_id on workout_post_likes(user_id);
create index if not exists idx_workout_post_comments_post_id on workout_post_comments(workout_post_id);
create index if not exists idx_workout_post_comments_parent on workout_post_comments(parent_comment_id);
create index if not exists idx_comment_likes_comment_id on comment_likes(comment_id);

commit;



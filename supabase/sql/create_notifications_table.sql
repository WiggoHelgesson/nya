-- Create notifications table and setup RLS policies
-- Run this in Supabase SQL Editor

begin;

-- Create notifications table if it doesn't exist
create table if not exists notifications (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id) on delete cascade not null,
    actor_id uuid references auth.users(id) on delete cascade not null,
    actor_username text,
    actor_avatar_url text,
    type text not null check (type in ('like', 'comment', 'follow')),
    post_id uuid references workout_posts(id) on delete cascade,
    comment_text text,
    is_read boolean default false,
    created_at timestamp with time zone default now()
);

-- Enable RLS
alter table notifications enable row level security;

-- Policies: Users can only see their own notifications
drop policy if exists "Users can view their own notifications" on notifications;
create policy "Users can view their own notifications" on notifications
for select to authenticated
using (auth.uid() = user_id);

-- Users can update their own notifications (mark as read)
drop policy if exists "Users can update their own notifications" on notifications;
create policy "Users can update their own notifications" on notifications
for update to authenticated
using (auth.uid() = user_id);

-- Anyone can insert notifications (when they like/comment/follow)
drop policy if exists "Users can create notifications" on notifications;
create policy "Users can create notifications" on notifications
for insert to authenticated
with check (true);

-- Create indexes for performance
create index if not exists idx_notifications_user_id on notifications(user_id);
create index if not exists idx_notifications_actor_id on notifications(actor_id);
create index if not exists idx_notifications_created_at on notifications(created_at desc);
create index if not exists idx_notifications_is_read on notifications(is_read) where not is_read;

commit;






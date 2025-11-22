-- Database cleanup + bucket policies. Run this whole file in Supabase SQL Editor.

begin;

-- Remove all server-side push notification plumbing
drop trigger if exists trig_notify_notifications on notifications;
drop trigger if exists trig_completed_session on completed_training_sessions;
drop function if exists notify_on_notification_insert() cascade;
drop function if exists notify_on_completed_session() cascade;
drop table if exists user_devices;

-- ---------------------------------------------------------------------------
-- Profile image bucket (storage.objects) policies (kept for avatar uploads)
-- ---------------------------------------------------------------------------

drop policy if exists "profile-images insert" on storage.objects;
drop policy if exists "profile-images update" on storage.objects;
drop policy if exists "profile-images delete" on storage.objects;
drop policy if exists "profile-images select" on storage.objects;

create policy "profile-images insert" on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-images'
  and auth.uid() = coalesce(owner, auth.uid())
);

create policy "profile-images update" on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-images'
  and owner = auth.uid()
)
with check (
  bucket_id = 'profile-images'
  and owner = auth.uid()
);

create policy "profile-images delete" on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-images'
  and owner = auth.uid()
);

create policy "profile-images select" on storage.objects
for select
using (bucket_id = 'profile-images');

commit;


-- Allow listing owners to update and delete their own consignment_submissions
-- rows. Previously only admins could update, and nobody could delete via RLS.
-- Admins still retain full access through public.is_admin().

begin;

drop policy if exists consignment_update_admin on public.consignment_submissions;
drop policy if exists consignment_update_own_or_admin on public.consignment_submissions;

create policy consignment_update_own_or_admin on public.consignment_submissions
    for update to authenticated
    using (auth.uid() = user_id or public.is_admin())
    with check (auth.uid() = user_id or public.is_admin());

drop policy if exists consignment_delete_own_or_admin on public.consignment_submissions;

create policy consignment_delete_own_or_admin on public.consignment_submissions
    for delete to authenticated
    using (auth.uid() = user_id or public.is_admin());

commit;

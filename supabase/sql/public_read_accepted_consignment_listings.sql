-- Allow any authenticated user to read accepted consignment listings so they
-- can appear in the marketplace/product feed. Pending / rejected rows stay
-- private to the owner + admins.

drop policy if exists consignment_select_own on public.consignment_submissions;

create policy consignment_select_own on public.consignment_submissions
    for select to authenticated
    using (
        auth.uid() = user_id
        or public.is_admin()
        or admin_status = 'accepted'
    );

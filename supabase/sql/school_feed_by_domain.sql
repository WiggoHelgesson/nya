-- =============================================
-- School Feed by Domain
-- Returns user IDs for a specific school/university domain
-- Run this in the Supabase SQL Editor
-- =============================================

CREATE OR REPLACE FUNCTION get_school_user_ids(p_domain TEXT)
RETURNS TABLE (user_id TEXT)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT CAST(u.id AS TEXT) AS user_id
    FROM auth.users u
    WHERE u.email LIKE '%' || p_domain
    UNION
    SELECT CAST(p.id AS TEXT) AS user_id
    FROM public.profiles p
    WHERE p.verified_school_email LIKE '%' || p_domain;
$$;

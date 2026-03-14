-- =============================================
-- RPC: Get user ID + profile by email
-- Run this in the Supabase SQL Editor
-- =============================================

CREATE OR REPLACE FUNCTION get_user_id_by_email(user_email TEXT)
RETURNS TABLE (id TEXT, username TEXT, avatar_url TEXT)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    p.id,
    p.username,
    p.avatar_url
  FROM auth.users u
  JOIN public.profiles p ON CAST(p.id AS TEXT) = CAST(u.id AS TEXT)
  WHERE u.email = user_email
  LIMIT 1;
$$;

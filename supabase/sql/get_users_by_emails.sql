-- Function to get users by their email addresses
-- This joins auth.users (which has email) with public.profiles (which has username/avatar)

CREATE OR REPLACE FUNCTION get_users_by_emails(emails text[])
RETURNS TABLE (
    id text,
    username text,
    avatar_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        au.id::text,
        p.username,
        p.avatar_url
    FROM auth.users au
    JOIN public.profiles p ON au.id = p.id
    WHERE au.email = ANY(emails)
    AND p.username IS NOT NULL;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_users_by_emails(text[]) TO authenticated;







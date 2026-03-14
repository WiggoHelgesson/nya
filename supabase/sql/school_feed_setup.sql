-- =============================================
-- School Feed Setup
-- Run this in the Supabase SQL Editor
-- =============================================

-- 1. Add verified_school_email column to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS verified_school_email TEXT DEFAULT NULL;

-- 2. Create school_email_verifications table
CREATE TABLE IF NOT EXISTS school_email_verifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    code TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN DEFAULT FALSE
);

ALTER TABLE school_email_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own verifications"
    ON school_email_verifications FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Service role can insert verifications"
    ON school_email_verifications FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Service role can update verifications"
    ON school_email_verifications FOR UPDATE
    TO service_role
    USING (true);

-- 3. RPC: Get all Danderyds Gymnasium user IDs
--    Combines auth email check + verified_school_email from profiles
CREATE OR REPLACE FUNCTION get_danderyd_user_ids()
RETURNS TABLE (user_id TEXT)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT CAST(u.id AS TEXT) AS user_id
    FROM auth.users u
    WHERE u.email LIKE '%@elev.danderyd.se'
    UNION
    SELECT CAST(p.id AS TEXT) AS user_id
    FROM public.profiles p
    WHERE p.verified_school_email IS NOT NULL;
$$;

-- 4. RPC: Verify a school email code
--    Checks the code, marks it used, updates profiles
CREATE OR REPLACE FUNCTION verify_school_code(
    p_user_id TEXT,
    p_email TEXT,
    p_code TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_verification_id UUID;
BEGIN
    -- Find a matching, unused, non-expired verification
    SELECT id INTO v_verification_id
    FROM school_email_verifications
    WHERE user_id = p_user_id::UUID
      AND email = LOWER(p_email)
      AND code = p_code
      AND used = FALSE
      AND expires_at > now()
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_verification_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invalid or expired code');
    END IF;

    -- Mark code as used
    UPDATE school_email_verifications
    SET used = TRUE
    WHERE id = v_verification_id;

    -- Save verified school email to profile
    UPDATE profiles
    SET verified_school_email = LOWER(p_email)
    WHERE CAST(id AS TEXT) = p_user_id;

    RETURN json_build_object('success', true);
END;
$$;

-- 5. Auto-fill verified_school_email for existing users whose auth email is @elev.danderyd.se
UPDATE profiles p
SET verified_school_email = LOWER(u.email)
FROM auth.users u
WHERE CAST(p.id AS TEXT) = CAST(u.id AS TEXT)
  AND u.email LIKE '%@elev.danderyd.se'
  AND p.verified_school_email IS NULL;

-- 6. Index for faster school feed lookups
CREATE INDEX IF NOT EXISTS idx_profiles_verified_school_email
    ON profiles (verified_school_email)
    WHERE verified_school_email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_school_verifications_lookup
    ON school_email_verifications (user_id, email, code, used, expires_at);

-- ============================================================
-- Invite Codes System for Danderyd-exclusive signup
-- ============================================================

-- 1. Create the invite_codes table
CREATE TABLE IF NOT EXISTS invite_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    used_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invite_codes_owner ON invite_codes(owner_id);
CREATE INDEX IF NOT EXISTS idx_invite_codes_code ON invite_codes(code);

-- 2. Enable RLS
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read all invite codes (own invites + validate others' codes)
CREATE POLICY "Authenticated can read invite codes"
    ON invite_codes FOR SELECT
    TO authenticated
    USING (true);

-- Anon can validate codes (needed before the user has an account)
CREATE POLICY "Anon can validate invite codes"
    ON invite_codes FOR SELECT
    TO anon
    USING (true);

-- 3. RPC to redeem an invite code (SECURITY DEFINER bypasses RLS)
CREATE OR REPLACE FUNCTION redeem_invite_code(p_code TEXT, p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invite invite_codes%ROWTYPE;
BEGIN
    SELECT * INTO v_invite
    FROM invite_codes
    WHERE code = upper(p_code)
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Invite code not found');
    END IF;

    IF v_invite.used_by IS NOT NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invite code already used');
    END IF;

    UPDATE invite_codes
    SET used_by = p_user_id,
        used_at = now()
    WHERE id = v_invite.id;

    RETURN json_build_object('success', true);
END;
$$;

-- 4. Seed: give every existing user 2 invite codes
-- First invite per user
INSERT INTO invite_codes (id, code, owner_id)
SELECT
    gen_random_uuid(),
    upper(substr(md5(random()::text || id::text || '1'), 1, 8)),
    id
FROM profiles
ON CONFLICT (code) DO NOTHING;

-- Second invite per user
INSERT INTO invite_codes (id, code, owner_id)
SELECT
    gen_random_uuid(),
    upper(substr(md5(random()::text || id::text || '2'), 1, 8)),
    id
FROM profiles
ON CONFLICT (code) DO NOTHING;

-- 5. Function to auto-generate 2 invite codes for newly created profiles
CREATE OR REPLACE FUNCTION generate_invite_codes_for_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO invite_codes (id, code, owner_id)
    VALUES
        (gen_random_uuid(), upper(substr(md5(random()::text || NEW.id::text || clock_timestamp()::text), 1, 8)), NEW.id),
        (gen_random_uuid(), upper(substr(md5(random()::text || NEW.id::text || clock_timestamp()::text || '2'), 1, 8)), NEW.id);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_generate_invite_codes
    AFTER INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION generate_invite_codes_for_new_user();

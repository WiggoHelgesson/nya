-- RPC function to change which referral code a user is supporting
-- Uses SECURITY DEFINER to bypass RLS issues with update/delete on referral_usages
-- Run this in the Supabase SQL Editor

-- Drop old version first to avoid argument-type conflicts
DROP FUNCTION IF EXISTS change_support_code(text, text);

CREATE OR REPLACE FUNCTION change_support_code(
  p_user_id text,
  p_new_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_normalized_code text;
  v_code_id uuid;
  v_code_owner_id uuid;
  v_existing_usage_id uuid;
  v_existing_code_id uuid;
  v_user_uuid uuid;
BEGIN
  -- Cast user ID to uuid once
  v_user_uuid := p_user_id::uuid;

  -- Normalize the code
  v_normalized_code := upper(trim(p_new_code));

  -- Validate format
  IF length(v_normalized_code) < 3 OR length(v_normalized_code) > 12 THEN
    RETURN json_build_object('success', false, 'error', 'Code must be 3-12 characters');
  END IF;

  -- Find the referral code
  SELECT id, user_id INTO v_code_id, v_code_owner_id
  FROM referral_codes
  WHERE upper(code) = v_normalized_code
  LIMIT 1;

  IF v_code_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Code not found');
  END IF;

  -- Prevent using own code
  IF v_code_owner_id = v_user_uuid THEN
    RETURN json_build_object('success', false, 'error', 'Cannot use own code');
  END IF;

  -- Check for existing usage
  SELECT id, referral_code_id INTO v_existing_usage_id, v_existing_code_id
  FROM referral_usages
  WHERE referred_user_id = v_user_uuid
  LIMIT 1;

  IF v_existing_usage_id IS NOT NULL THEN
    -- Already supporting same code
    IF v_existing_code_id = v_code_id THEN
      RETURN json_build_object('success', true, 'message', 'Already supporting this code');
    END IF;

    -- Update to new code
    UPDATE referral_usages
    SET referral_code_id = v_code_id
    WHERE id = v_existing_usage_id;
  ELSE
    -- No existing usage, insert new
    INSERT INTO referral_usages (id, referral_code_id, referred_user_id)
    VALUES (gen_random_uuid(), v_code_id, v_user_uuid);
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- RPC function to update a user's referral code
-- Uses SECURITY DEFINER to bypass RLS issues with the update
-- Run this in the Supabase SQL Editor

CREATE OR REPLACE FUNCTION update_referral_code(
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
  v_existing_owner text;
  v_updated_count int;
BEGIN
  -- Normalize the code
  v_normalized_code := upper(trim(p_new_code));
  
  -- Validate format (3-12 alphanumeric characters)
  IF length(v_normalized_code) < 3 OR length(v_normalized_code) > 12 THEN
    RETURN json_build_object('success', false, 'error', 'Code must be 3-12 characters');
  END IF;
  
  IF v_normalized_code !~ '^[A-Z0-9]+$' THEN
    RETURN json_build_object('success', false, 'error', 'Code must be alphanumeric');
  END IF;
  
  -- Check if the code is already taken by someone else (case-insensitive)
  SELECT user_id INTO v_existing_owner
  FROM referral_codes
  WHERE upper(code) = v_normalized_code
  AND user_id::text != p_user_id
  LIMIT 1;
  
  IF v_existing_owner IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'Code already taken');
  END IF;
  
  -- Perform the update
  UPDATE referral_codes
  SET code = v_normalized_code,
      last_code_edited_at = now()
  WHERE user_id::text = p_user_id;
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  IF v_updated_count = 0 THEN
    RETURN json_build_object('success', false, 'error', 'No referral code found for user');
  END IF;
  
  RETURN json_build_object('success', true, 'code', v_normalized_code);
END;
$$;

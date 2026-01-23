-- Add last_code_edited_at column to referral_codes table
-- This tracks when the user last edited their referral code (allowed every 6 days)

ALTER TABLE referral_codes
ADD COLUMN IF NOT EXISTS last_code_edited_at TIMESTAMPTZ DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN referral_codes.last_code_edited_at IS 'Timestamp of when the user last edited their referral code. Users can edit every 6 days.';

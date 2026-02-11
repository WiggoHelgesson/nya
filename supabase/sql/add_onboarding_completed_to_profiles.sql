-- Add onboarding_completed flag to profiles table
-- This tracks whether the user has completed the initial onboarding flow.
-- Default is false so existing users who already completed onboarding 
-- need to be backfilled (see UPDATE below).

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;

-- Backfill: mark ALL existing profiles as onboarding completed
-- (they already went through onboarding or are existing active users)
UPDATE public.profiles
SET onboarding_completed = true
WHERE onboarding_completed IS NULL OR onboarding_completed = false;

-- Comment for documentation
COMMENT ON COLUMN public.profiles.onboarding_completed IS 'Whether the user has completed the initial onboarding flow';

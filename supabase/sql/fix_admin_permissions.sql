-- Fix Admin Permissions for Trainer Profiles

-- 1. Create a secure function to check if the current user is an admin
-- This matches the hardcoded list in SettingsView.swift
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
DECLARE
  current_email TEXT;
BEGIN
  -- Get email from JWT claim
  current_email := lower(auth.jwt() ->> 'email');
  
  -- Check against allowed admin emails
  IF current_email = 'admin@updown.app' OR 
     current_email = 'wiggohelgesson@gmail.com' OR 
     current_email = 'info@wiggio.se' OR 
     current_email = 'info@bylito.se' THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update RLS Policies for trainer_profiles

-- Allow admins to VIEW ALL profiles (including inactive/pending ones)
DROP POLICY IF EXISTS trainer_profiles_select ON public.trainer_profiles;
CREATE POLICY trainer_profiles_select ON public.trainer_profiles
    FOR SELECT
    USING (
        is_active = true                 -- Public sees active
        OR auth.uid() = user_id          -- User sees own
        OR public.is_admin()             -- Admin sees all
    );

-- Allow admins to UPDATE ALL profiles (to approve/reject)
DROP POLICY IF EXISTS trainer_profiles_update ON public.trainer_profiles;
CREATE POLICY trainer_profiles_update ON public.trainer_profiles
    FOR UPDATE
    USING (
        auth.uid() = user_id 
        OR public.is_admin()
    )
    WITH CHECK (
        auth.uid() = user_id 
        OR public.is_admin()
    );

-- Allow admins to DELETE profiles if necessary
DROP POLICY IF EXISTS trainer_profiles_delete ON public.trainer_profiles;
CREATE POLICY trainer_profiles_delete ON public.trainer_profiles
    FOR DELETE
    USING (
        auth.uid() = user_id 
        OR public.is_admin()
    );


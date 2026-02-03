-- Fix RLS policies for profiles table to allow users to update their own profile
-- Run this in Supabase SQL Editor

BEGIN;

-- Check if UPDATE policy exists, if not create it
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

CREATE POLICY "Users can update own profile" ON profiles
FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Also ensure SELECT policy exists
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;

CREATE POLICY "Public profiles are viewable by everyone" ON profiles
FOR SELECT TO authenticated
USING (true);

COMMIT;

-- Verify policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'profiles';

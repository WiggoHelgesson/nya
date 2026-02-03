-- Fix RLS policies for referral_codes table
-- Run this in Supabase SQL Editor to allow users to update their own referral codes

begin;

-- Enable RLS if not already enabled
alter table referral_codes enable row level security;

-- Drop existing policies if they exist (to avoid conflicts)
drop policy if exists "Users can view all referral codes" on referral_codes;
drop policy if exists "Users can insert their own referral code" on referral_codes;
drop policy if exists "Users can update their own referral code" on referral_codes;

-- SELECT: Anyone authenticated can view referral codes (needed to check if code is taken)
create policy "Users can view all referral codes" on referral_codes
for select to authenticated
using (true);

-- INSERT: Users can only insert their own referral code
create policy "Users can insert their own referral code" on referral_codes
for insert to authenticated
with check (auth.uid()::text = user_id);

-- UPDATE: Users can only update their own referral code (THIS IS THE CRITICAL FIX)
create policy "Users can update their own referral code" on referral_codes
for update to authenticated
using (auth.uid()::text = user_id)
with check (auth.uid()::text = user_id);

commit;

-- Verify the policies were created
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check 
from pg_policies 
where tablename = 'referral_codes';

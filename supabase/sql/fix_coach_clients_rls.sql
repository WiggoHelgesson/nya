-- Fix RLS policies for coach_clients table to allow client to create and update their own relations

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their coach relationships" ON coach_clients;
DROP POLICY IF EXISTS "Coaches can view their client relationships" ON coach_clients;
DROP POLICY IF EXISTS "Allow coach-client relation creation" ON coach_clients;
DROP POLICY IF EXISTS "Allow client to activate their coach relationship" ON coach_clients;

-- Policy 1: Users (clients) can view their own coach relationships
CREATE POLICY "Users can view their coach relationships"
ON coach_clients
FOR SELECT
TO authenticated
USING (
  auth.uid() = client_id::uuid
  OR auth.uid() = coach_id::uuid
);

-- Policy 2: Service role or client can create their own coach relationship
CREATE POLICY "Allow coach-client relation creation"
ON coach_clients
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = client_id::uuid
);

-- Policy 3: Client can update their own coach relationship (e.g., activate it)
CREATE POLICY "Allow client to update their coach relationship"
ON coach_clients
FOR UPDATE
TO authenticated
USING (auth.uid() = client_id::uuid)
WITH CHECK (auth.uid() = client_id::uuid);

-- Policy 4: Coach can update their client relationships
CREATE POLICY "Allow coach to update client relationships"
ON coach_clients
FOR UPDATE
TO authenticated
USING (auth.uid() = coach_id::uuid)
WITH CHECK (auth.uid() = coach_id::uuid);

-- Verify policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'coach_clients'
ORDER BY policyname;

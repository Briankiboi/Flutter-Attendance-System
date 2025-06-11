-- Temporarily disable RLS for development
ALTER TABLE schedule_messages DISABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to perform operations during development
GRANT ALL ON schedule_messages TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Create a permissive policy for development
DROP POLICY IF EXISTS "Allow all during development" ON schedule_messages;
CREATE POLICY "Allow all during development"
ON schedule_messages
AS PERMISSIVE
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Re-enable RLS with permissive policy
ALTER TABLE schedule_messages ENABLE ROW LEVEL SECURITY; 
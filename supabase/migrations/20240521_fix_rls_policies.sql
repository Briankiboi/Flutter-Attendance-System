-- First, completely disable RLS
ALTER TABLE "public"."student_registered_units" DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON "public"."student_registered_units";

-- Grant all privileges to authenticated users
GRANT ALL ON "public"."student_registered_units" TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Create a single permissive policy
CREATE POLICY "Enable all operations for authenticated users"
ON "public"."student_registered_units"
AS PERMISSIVE
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Re-enable RLS with the new policy
ALTER TABLE "public"."student_registered_units" FORCE ROW LEVEL SECURITY; 
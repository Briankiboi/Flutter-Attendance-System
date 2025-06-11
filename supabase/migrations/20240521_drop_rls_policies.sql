-- Drop existing RLS policies for student_registered_units table
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON "public"."student_registered_units";

-- Temporarily disable RLS for the table
ALTER TABLE "public"."student_registered_units" DISABLE ROW LEVEL SECURITY;

-- Create a basic policy that allows all operations for authenticated users
CREATE POLICY "Enable all access for authenticated users"
ON "public"."student_registered_units"
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Re-enable RLS with the new permissive policy
ALTER TABLE "public"."student_registered_units" ENABLE ROW LEVEL SECURITY; 
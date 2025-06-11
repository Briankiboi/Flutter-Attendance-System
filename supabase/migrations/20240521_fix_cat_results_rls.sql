-- First, disable RLS for cat_results
ALTER TABLE "public"."cat_results" DISABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON "public"."cat_results";

-- Grant necessary privileges
GRANT ALL ON "public"."cat_results" TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Create policies for cat_results table
CREATE POLICY "Enable all operations for lecturers"
ON "public"."cat_results"
AS PERMISSIVE
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Re-enable RLS
ALTER TABLE "public"."cat_results" ENABLE ROW LEVEL SECURITY; 
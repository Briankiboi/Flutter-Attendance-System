-- ============= CAT Results Table Policies =============
-- First, disable RLS for cat_results
ALTER TABLE "public"."cat_results" DISABLE ROW LEVEL SECURITY;

-- Drop existing policies for cat_results
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable lecturer operations" ON "public"."cat_results";
DROP POLICY IF EXISTS "Enable student read" ON "public"."cat_results";

-- Create lecturer policies for cat_results
CREATE POLICY "Enable lecturer operations"
ON "public"."cat_results"
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM lecturers 
    WHERE lecturers.id = auth.uid() 
    AND lecturers.id = cat_results.lecturer_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM lecturers 
    WHERE lecturers.id = auth.uid() 
    AND lecturers.id = cat_results.lecturer_id
  )
);

-- Create student read-only policy for cat_results
CREATE POLICY "Enable student read"
ON "public"."cat_results"
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM students 
    WHERE students.id = auth.uid() 
    AND students.id = cat_results.student_id
  )
);

-- ============= Student Registered Units Table Policies =============
-- Disable RLS for student_registered_units
ALTER TABLE "public"."student_registered_units" DISABLE ROW LEVEL SECURITY;

-- Drop existing policies for student_registered_units
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable lecturer operations" ON "public"."student_registered_units";
DROP POLICY IF EXISTS "Enable student read" ON "public"."student_registered_units";

-- Create lecturer policies for student_registered_units
CREATE POLICY "Enable lecturer operations"
ON "public"."student_registered_units"
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM lecturer_units 
    WHERE lecturer_units.lecturer_id = auth.uid() 
    AND lecturer_units.unit_id = student_registered_units.unit_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM lecturer_units 
    WHERE lecturer_units.lecturer_id = auth.uid() 
    AND lecturer_units.unit_id = student_registered_units.unit_id
  )
);

-- Create student read-only policy for student_registered_units
CREATE POLICY "Enable student read"
ON "public"."student_registered_units"
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM students 
    WHERE students.id = auth.uid() 
    AND students.id = student_registered_units.student_id
  )
);

-- Grant necessary privileges
GRANT ALL ON "public"."cat_results" TO authenticated;
GRANT ALL ON "public"."student_registered_units" TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Re-enable RLS for both tables
ALTER TABLE "public"."cat_results" FORCE ROW LEVEL SECURITY;
ALTER TABLE "public"."student_registered_units" FORCE ROW LEVEL SECURITY; 
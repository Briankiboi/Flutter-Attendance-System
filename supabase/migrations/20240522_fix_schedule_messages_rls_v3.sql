-- First, disable RLS
ALTER TABLE schedule_messages DISABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "Lecturers can view their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can create messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can update their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can delete their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Enable all operations for lecturers" ON schedule_messages;

-- Grant necessary privileges
GRANT ALL ON schedule_messages TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Create a single permissive policy for lecturers
CREATE POLICY "Enable all operations for lecturers"
ON schedule_messages
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM lecturers 
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM lecturers 
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

-- Create a permissive read policy for students
CREATE POLICY "Enable student read access"
ON schedule_messages
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM student_units su
    WHERE su.unit_id = schedule_messages.unit_id
    AND EXISTS (
      SELECT 1 FROM students s
      WHERE s.id = su.student_id
      AND s.user_id = auth.uid()
    )
  )
);

-- Re-enable RLS
ALTER TABLE schedule_messages ENABLE ROW LEVEL SECURITY; 
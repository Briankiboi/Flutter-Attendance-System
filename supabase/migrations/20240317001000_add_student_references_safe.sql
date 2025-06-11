-- Add new foreign key columns to students table without removing existing ones
ALTER TABLE students 
ADD COLUMN IF NOT EXISTS course_id UUID REFERENCES courses(id),
ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id);

-- Create function to safely migrate existing data
CREATE OR REPLACE FUNCTION migrate_student_references_safe() 
RETURNS void AS $$
DECLARE
  student_rec RECORD;
  new_dept_id UUID;
  new_course_id UUID;
BEGIN
  FOR student_rec IN SELECT * FROM students LOOP
    -- Find matching department ID
    SELECT id INTO new_dept_id 
    FROM departments 
    WHERE name = student_rec.department;

    IF new_dept_id IS NOT NULL THEN
      -- Find matching course ID
      SELECT id INTO new_course_id 
      FROM courses 
      WHERE name = student_rec.course 
      AND department_id = new_dept_id;
      
      -- Update only the new reference columns
      UPDATE students
      SET 
        department_id = new_dept_id,
        course_id = new_course_id
      WHERE id = student_rec.id;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the safe migration function
SELECT migrate_student_references_safe();

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_students_course_id ON students(course_id);
CREATE INDEX IF NOT EXISTS idx_students_department_id ON students(department_id);

-- Add new RLS policies without modifying existing ones
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'courses' 
    AND policyname = 'Students can view their own course details via FK'
  ) THEN
    CREATE POLICY "Students can view their own course details via FK" ON courses
    FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM students
        WHERE students.course_id = courses.id
        AND students.user_id = auth.uid()
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'departments' 
    AND policyname = 'Students can view their own department details via FK'
  ) THEN
    CREATE POLICY "Students can view their own department details via FK" ON departments
    FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM students
        WHERE students.department_id = departments.id
        AND students.user_id = auth.uid()
      )
    );
  END IF;
END $$; 
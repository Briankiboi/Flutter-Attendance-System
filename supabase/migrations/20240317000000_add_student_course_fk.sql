-- Add foreign key columns to students table
ALTER TABLE students 
ADD COLUMN IF NOT EXISTS course_id UUID REFERENCES courses(id),
ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id);

-- Create function to migrate existing data
CREATE OR REPLACE FUNCTION migrate_student_references() 
RETURNS void AS $$
DECLARE
  student_rec RECORD;
  dept_id UUID;
  course_id UUID;
BEGIN
  FOR student_rec IN SELECT * FROM students LOOP
    -- Find matching department ID
    SELECT id INTO dept_id 
    FROM departments 
    WHERE name = student_rec.department;

    -- Find matching course ID
    SELECT id INTO course_id 
    FROM courses 
    WHERE name = student_rec.course 
    AND department_id = dept_id;
    
    -- Update the student with reference IDs
    UPDATE students 
    SET 
      department_id = dept_id,
      course_id = course_id,
      updated_at = NOW()
    WHERE id = student_rec.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the migration function
SELECT migrate_student_references();

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_students_course_id ON students(course_id);
CREATE INDEX IF NOT EXISTS idx_students_department_id ON students(department_id);

-- Update RLS policies to use new foreign key columns
CREATE POLICY "Students can view their own course details" ON courses
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM students
    WHERE students.course_id = courses.id
    AND students.user_id = auth.uid()
  )
);

CREATE POLICY "Students can view their own department details" ON departments
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM students
    WHERE students.department_id = departments.id
    AND students.user_id = auth.uid()
  )
); 
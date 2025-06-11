-- Drop existing functions first
DROP FUNCTION IF EXISTS get_available_units(uuid, text, text);
DROP FUNCTION IF EXISTS register_student_units(uuid, uuid[], text, text);

-- Create student_units table if it doesn't exist
CREATE TABLE IF NOT EXISTS student_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL,
  unit_id UUID REFERENCES units(id) NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  registration_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(student_id, unit_id, year, semester)
);

-- Enable RLS on student_units if not already enabled
ALTER TABLE student_units ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Students can view their own registered units" ON student_units;
DROP POLICY IF EXISTS "Students can register units" ON student_units;

-- Create policies for student_units
CREATE POLICY "Students can view their own registered units"
ON student_units
FOR SELECT
USING (
  auth.uid() IN (
    SELECT user_id FROM students WHERE id = student_id
  )
);

CREATE POLICY "Students can register units"
ON student_units
FOR INSERT
WITH CHECK (
  auth.uid() IN (
    SELECT user_id FROM students WHERE id = student_id
  )
);

-- Create a function to get available units for a student
CREATE OR REPLACE FUNCTION get_available_units(
  p_student_id UUID,
  p_year TEXT,
  p_semester TEXT
)
RETURNS TABLE (
  unit_id UUID,
  unit_code TEXT,
  unit_name TEXT,
  course_name TEXT,
  department_name TEXT,
  year TEXT,
  semester TEXT
) AS $$
DECLARE
  v_course_id UUID;
  v_course_name TEXT;
  v_dept_name TEXT;
BEGIN
  -- Get student's course info
  SELECT 
    c.id, c.name, d.name 
  INTO 
    v_course_id, v_course_name, v_dept_name
  FROM students s
  JOIN courses c ON s.course_id = c.id
  JOIN departments d ON c.department_id = d.id
  WHERE s.id = p_student_id;

  -- Return available units
  RETURN QUERY
  SELECT 
    u.id as unit_id,
    u.code as unit_code,
    u.name as unit_name,
    v_course_name as course_name,
    v_dept_name as department_name,
    u.year,
    u.semester
  FROM units u
  WHERE u.course_id = v_course_id
    AND u.year = p_year
    AND u.semester = p_semester
    AND NOT EXISTS (
      SELECT 1 
      FROM student_units su 
      WHERE su.unit_id = u.id 
        AND su.student_id = p_student_id
        AND su.year = p_year
        AND su.semester = p_semester
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to register units for a student
CREATE OR REPLACE FUNCTION register_student_units(
  p_student_id UUID,
  p_unit_ids UUID[],
  p_year TEXT,
  p_semester TEXT
)
RETURNS SETOF student_units AS $$
BEGIN
  -- Insert units and return the inserted records
  RETURN QUERY
  INSERT INTO student_units (
    student_id,
    unit_id,
    year,
    semester
  )
  SELECT 
    p_student_id,
    unit_id,
    p_year,
    p_semester
  FROM unnest(p_unit_ids) AS unit_id
  RETURNING *;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON TABLE student_units TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_units TO authenticated;
GRANT EXECUTE ON FUNCTION register_student_units TO authenticated; 
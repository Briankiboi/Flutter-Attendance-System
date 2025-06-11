-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop dependent functions first
DROP FUNCTION IF EXISTS get_units_by_department(uuid);
DROP FUNCTION IF EXISTS get_units_by_course(uuid);

-- Drop tables in correct order with CASCADE to handle dependencies
DROP TABLE IF EXISTS student_units CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS lecturer_assigned_units CASCADE;
DROP TABLE IF EXISTS units CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS lecturers CASCADE;

-- Create departments table
CREATE TABLE departments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create courses table
CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  department_id UUID REFERENCES departments(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(name, department_id)
);

-- Create units table
CREATE TABLE units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  course_id UUID REFERENCES courses(id),
  department_id UUID REFERENCES departments(id),
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(code)
);

-- Create student_units table
CREATE TABLE student_units (
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

-- Enable RLS on student_units
ALTER TABLE student_units ENABLE ROW LEVEL SECURITY;

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

-- Create lecturers table with proper user_id reference
CREATE TABLE lecturers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE,  -- Remove NOT NULL constraint temporarily
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  department TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create lecturer_assigned_units table
CREATE TABLE lecturer_assigned_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  unit_code TEXT REFERENCES units(code) NOT NULL,
  unit_name TEXT NOT NULL,
  department TEXT NOT NULL,
  course_name TEXT NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(lecturer_id, unit_code)
);

-- Enable RLS
ALTER TABLE lecturer_assigned_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Lecturers can view their own assigned units" ON lecturer_assigned_units;
DROP POLICY IF EXISTS "Lecturers can insert their own assigned units" ON lecturer_assigned_units;
DROP POLICY IF EXISTS "Lecturers can update their own assigned units" ON lecturer_assigned_units;
DROP POLICY IF EXISTS "Lecturers can delete their own assigned units" ON lecturer_assigned_units;
DROP POLICY IF EXISTS "Lecturers can view their own profile" ON lecturers;
DROP POLICY IF EXISTS "Lecturers can update their own profile" ON lecturers;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON lecturers;
DROP POLICY IF EXISTS "Allow anonymous lecturer creation" ON lecturers;

-- Create policies for lecturers table
CREATE POLICY "Allow anonymous lecturer creation"
ON lecturers 
FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Lecturers can view their own profile"
ON lecturers
FOR SELECT
USING (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE users.id = lecturers.user_id
  )
);

CREATE POLICY "Lecturers can update their own profile"
ON lecturers
FOR UPDATE
USING (
  auth.uid() = user_id
);

-- Allow new lecturers to sign up
CREATE POLICY "Enable insert for authenticated users only"
ON lecturers
FOR INSERT
WITH CHECK (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM auth.users
    WHERE users.id = user_id
  )
);

-- Create new simplified policies
CREATE POLICY "Lecturers can insert their own assigned units"
ON lecturer_assigned_units
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = lecturer_assigned_units.lecturer_id
  )
);

CREATE POLICY "Lecturers can view their own assigned units"
ON lecturer_assigned_units
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = lecturer_assigned_units.lecturer_id
  )
);

CREATE POLICY "Lecturers can delete their own assigned units"
ON lecturer_assigned_units
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = lecturer_assigned_units.lecturer_id
  )
);

-- First ensure departments exist
INSERT INTO departments (name) VALUES
('Engineering'),
('Computer Science'),
('Business'),
('Education')
ON CONFLICT (name) DO NOTHING;

-- Insert lecturer records for existing users
INSERT INTO lecturers (name, email, department)
VALUES 
('Paul nganga', 'paulnganga@tharaka.ac.ke', 'Education'),
('Harriet Tsinaye', 'harriettsinaye@tharaka.ac.ke', 'Computer Science'),
('Kevin Tuwei', 'kelvintuwei@tharaka.ac.ke', 'Engineering'),
('Esther Waithera', 'estherwaithera@tharaka.ac.ke', 'Business'),
('Yvonne Nkatha', 'Yvonnenkatha@tharaka.ac.ke', 'Education'),
('peter njuki', 'peternjuki@tharaka.ac.ke', 'Computer Science'),
('Martin Kinyua', 'martinkinyua@tharaka.ac.ke', 'Engineering'),
('Fidel Castro', 'Fidelcastro@tharaka.ac.ke', 'Business'),
('Ian wahome', 'ianwahome@tharaka.ac.ke', 'Education'),
('John. Njagi', 'johnnjagi@tharaka.ac.ke', 'Computer Science'),
('Dr Faith Kabiru', 'faithkabiru@tharaka.ac.ke', 'Engineering'),
('Mercy Wangui', 'mercywangui@tharaka.ac.ke', 'Business'),
('Lucy Wakio', 'lucywakio@tharaka.ac.ke', 'Education'),
('Brian kiboi', 'briankiboi@tharaka.ac.ke', 'Computer Science')
ON CONFLICT (email) DO UPDATE SET
    name = EXCLUDED.name,
    department = EXCLUDED.department,
    updated_at = NOW();

-- Insert courses with correct department references
INSERT INTO courses (name, department_id) VALUES
('Computer Science', (SELECT id FROM departments WHERE name = 'Computer Science')),
('Civil Engineering', (SELECT id FROM departments WHERE name = 'Engineering')),
('Business Administration', (SELECT id FROM departments WHERE name = 'Business')),
('Math/bio', (SELECT id FROM departments WHERE name = 'Education'))
ON CONFLICT (name, department_id) DO NOTHING;

-- Now insert units with correct course relationships and year/semester info
INSERT INTO units (code, name, course_id, year, semester) VALUES
-- Computer Science Units - Year 1
('CS111', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science'), '1', '1'),
('CS112', 'Computer Organization', (SELECT id FROM courses WHERE name = 'Computer Science'), '1', '1'),
('CS121', 'Data Structures and Algorithms', (SELECT id FROM courses WHERE name = 'Computer Science'), '1', '2'),
('CS122', 'Discrete Mathematics', (SELECT id FROM courses WHERE name = 'Computer Science'), '1', '2'),

-- Computer Science Units - Year 2
('CS211', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Computer Science'), '2', '1'),
('CS212', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science'), '2', '1'),
('CS221', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science'), '2', '2'),
('CS222', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science'), '2', '2'),

-- Computer Science Units - Year 3
('CS311', 'Software Engineering', (SELECT id FROM courses WHERE name = 'Computer Science'), '3', '1'),
('CS312', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science'), '3', '1'),
('CS321', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science'), '3', '2'),
('CS322', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science'), '3', '2'),

-- Computer Science Units - Year 4
('CS411', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science'), '4', '1'),
('CS412', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science'), '4', '1'),
('CS421', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science'), '4', '2'),
('CS422', 'Project Management', (SELECT id FROM courses WHERE name = 'Computer Science'), '4', '2'),

-- Civil Engineering Units - Year 1
('CE111', 'Engineering Mathematics I', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '1', '1'),
('CE112', 'Engineering Drawing', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '1', '1'),
('CE121', 'Engineering Mathematics II', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '1', '2'),
('CE122', 'Structural Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '1', '2'),

-- Civil Engineering Units - Year 2
('CE211', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '2', '1'),
('CE212', 'Construction Materials', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '2', '1'),
('CE221', 'Soil Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '2', '2'),
('CE222', 'Surveying', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '2', '2'),

-- Civil Engineering Units - Year 3
('CE311', 'Structural Analysis', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '3', '1'),
('CE312', 'Transportation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '3', '1'),
('CE321', 'Foundation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '3', '2'),
('CE322', 'Environmental Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '3', '2'),

-- Civil Engineering Units - Year 4
('CE411', 'Construction Management', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '4', '1'),
('CE412', 'Steel Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '4', '1'),
('CE421', 'Concrete Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '4', '2'),
('CE422', 'Highway Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '4', '2'),

-- Business Administration Units - Year 1
('BA111', 'Principles of Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '1', '1'),
('BA112', 'Business Mathematics', (SELECT id FROM courses WHERE name = 'Business Administration'), '1', '1'),
('BA121', 'Financial Accounting', (SELECT id FROM courses WHERE name = 'Business Administration'), '1', '2'),
('BA122', 'Business Communication', (SELECT id FROM courses WHERE name = 'Business Administration'), '1', '2'),

-- Business Administration Units - Year 2
('BA211', 'Marketing Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '2', '1'),
('BA212', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '2', '1'),
('BA221', 'Business Law', (SELECT id FROM courses WHERE name = 'Business Administration'), '2', '2'),
('BA222', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '2', '2'),

-- Business Administration Units - Year 4
('BA311', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '3', '1'),
('BA312', 'International Business', (SELECT id FROM courses WHERE name = 'Business Administration'), '3', '1'),
('BA321', 'Entrepreneurship', (SELECT id FROM courses WHERE name = 'Business Administration'), '3', '2'),
('BA322', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business Administration'), '3', '2'),

-- Business Administration Units - Year 4
('BA411', 'Project Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '4', '1'),
('BA412', 'Risk Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '4', '1'),
('BA421', 'Business Analytics', (SELECT id FROM courses WHERE name = 'Business Administration'), '4', '2'),
('BA422', 'Digital Business', (SELECT id FROM courses WHERE name = 'Business Administration'), '4', '2'),

-- Math/Bio Units - Year 1
('MB111', 'Calculus I', (SELECT id FROM courses WHERE name = 'Math/bio'), '1', '1'),
('MB112', 'General Biology', (SELECT id FROM courses WHERE name = 'Math/bio'), '1', '1'),
('MB121', 'Calculus II', (SELECT id FROM courses WHERE name = 'Math/bio'), '1', '2'),
('MB122', 'Cell Biology', (SELECT id FROM courses WHERE name = 'Math/bio'), '1', '2'),

-- Math/Bio Units - Year 2
('MB211', 'Linear Algebra', (SELECT id FROM courses WHERE name = 'Math/bio'), '2', '1'),
('MB212', 'Genetics', (SELECT id FROM courses WHERE name = 'Math/bio'), '2', '1'),
('MB221', 'Differential Equations', (SELECT id FROM courses WHERE name = 'Math/bio'), '2', '2'),
('MB222', 'Molecular Biology', (SELECT id FROM courses WHERE name = 'Math/bio'), '2', '2'),

-- Math/Bio Units - Year 3
('MB311', 'Statistics', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '1'),
('MB312', 'Ecology', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '1'),
('MB321', 'Complex Analysis', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '2'),
('MB322', 'Evolution', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '2'),

-- Math/Bio Units - Year 4
('MB411', 'Abstract Algebra', (SELECT id FROM courses WHERE name = 'Math/bio'), '5', '1'),
('MB412', 'Biotechnology', (SELECT id FROM courses WHERE name = 'Math/bio'), '4', '1'),
('MB421', 'Number Theory', (SELECT id FROM courses WHERE name = 'Math/bio'), '4', '2'),
('MB422', 'Bioinformatics', (SELECT id FROM courses WHERE name = 'Math/bio'), '4', '2')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    year = EXCLUDED.year,
    semester = EXCLUDED.semester,
    updated_at = NOW();

-- Recreate the functions
CREATE OR REPLACE FUNCTION get_units_by_department(department_uuid UUID)
RETURNS TABLE (
  id UUID,
  code TEXT,
  name TEXT,
  course_id UUID,
  department_id UUID,
  year TEXT,
  semester TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.code,
    u.name,
    u.course_id,
    u.department_id,
    u.year,
    u.semester
  FROM units u
  WHERE u.department_id = department_uuid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_units_by_course(course_uuid UUID)
RETURNS TABLE (
  code TEXT,
  name TEXT,
  year TEXT,
  semester TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.code, u.name, u.year, u.semester
  FROM units u
  WHERE u.course_id = course_uuid;
END;
$$ LANGUAGE plpgsql;

-- Create a function to handle lecturer signup
CREATE OR REPLACE FUNCTION handle_lecturer_signup()
RETURNS TRIGGER AS $$
BEGIN
  -- Create user record if it doesn't exist
  INSERT INTO users (id, email, name, password, user_type)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.raw_app_meta_data->>'password',
    'lecturer'
  )
  ON CONFLICT (id) DO NOTHING;

  -- Create lecturer record
  INSERT INTO lecturers (
    user_id,
    name,
    email,
    department,
    occupation,
    employment_type,
    gender
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'department', 'Education'),
    COALESCE(NEW.raw_user_meta_data->>'occupation', 'Lecturer'),
    COALESCE(NEW.raw_user_meta_data->>'employment_type', 'Full Time'),
    COALESCE(NEW.raw_user_meta_data->>'gender', 'Not Specified')
  );

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- Log the error but don't fail
    RAISE NOTICE 'Error in handle_lecturer_signup: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger for automatic lecturer creation on auth.users insert
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_lecturer_signup();

-- Update lecturer records with their auth user IDs
UPDATE lecturers l
SET user_id = u.id
FROM auth.users u
WHERE l.email = u.email
AND l.user_id IS NULL;

-- After all records are updated, we can add back the NOT NULL constraint
ALTER TABLE lecturers 
  ALTER COLUMN user_id SET NOT NULL;

-- Add some test units for Education/Math/bio course
INSERT INTO units (code, name, course_id, year, semester) VALUES
('EDU321', 'Educational Psychology', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '2'),
('EDU322', 'Teaching Methods', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '2'),
('EDU323', 'Curriculum Development', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '2'),
('EDU324', 'Educational Assessment', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '2')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    year = EXCLUDED.year,
    semester = EXCLUDED.semester,
    updated_at = NOW();

-- Drop the trigger if it exists
DROP TRIGGER IF EXISTS before_unit_changes ON units;

-- Drop the trigger function if it exists
DROP FUNCTION IF EXISTS set_unit_department();

-- Add department_id column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'units' 
        AND column_name = 'department_id'
    ) THEN
        ALTER TABLE units 
        ADD COLUMN department_id UUID REFERENCES departments(id);
    END IF;
END $$;

-- Create or replace the trigger function
CREATE OR REPLACE FUNCTION set_unit_department()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.course_id IS NOT NULL THEN
        NEW.department_id := (
            SELECT department_id 
            FROM courses 
            WHERE id = NEW.course_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER before_unit_changes
    BEFORE INSERT OR UPDATE ON units
    FOR EACH ROW
    EXECUTE FUNCTION set_unit_department();

-- Update existing units with their department_ids
UPDATE units u
SET department_id = (
    SELECT c.department_id
    FROM courses c
    WHERE c.id = u.course_id
)
WHERE u.course_id IS NOT NULL;

-- Update or create the get_units_by_department function
CREATE OR REPLACE FUNCTION get_units_by_department(department_uuid UUID)
RETURNS TABLE (
    id UUID,
    code TEXT,
    name TEXT,
    course_id UUID,
    department_id UUID,
    year TEXT,
    semester TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.code,
        u.name,
        u.course_id,
        u.department_id,
        u.year,
        u.semester
    FROM units u
    WHERE u.department_id = department_uuid;
END;
$$ LANGUAGE plpgsql; 
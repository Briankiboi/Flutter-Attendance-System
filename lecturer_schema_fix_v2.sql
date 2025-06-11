-- First ensure UUID extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop ALL existing policies first to avoid conflicts
DROP POLICY IF EXISTS "Anyone can view departments" ON departments;
DROP POLICY IF EXISTS "Anyone can insert departments" ON departments;
DROP POLICY IF EXISTS "Anyone can view courses" ON courses;
DROP POLICY IF EXISTS "Anyone can view units" ON units;
DROP POLICY IF EXISTS "Allow lecturer read access" ON lecturers;
DROP POLICY IF EXISTS "Allow lecturer update" ON lecturers;
DROP POLICY IF EXISTS "Allow lecturer insert" ON lecturers;
DROP POLICY IF EXISTS "Allow system to manage lecturers" ON lecturers;
DROP POLICY IF EXISTS "Lecturers can view their assigned units" ON lecturer_assigned_units;
DROP POLICY IF EXISTS "Lecturers can manage their assigned units" ON lecturer_assigned_units;
DROP POLICY IF EXISTS "Allow lecturer preferences read" ON user_preferences;
DROP POLICY IF EXISTS "Allow lecturer preferences update" ON user_preferences;
DROP POLICY IF EXISTS "Allow lecturer preferences insert" ON user_preferences;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_lecturer_signup();

-- Create or update tables
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  department_id UUID REFERENCES departments(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(name, department_id)
);

CREATE TABLE IF NOT EXISTS units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  course_id UUID REFERENCES courses(id),
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(code)
);

CREATE TABLE IF NOT EXISTS lecturers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  department TEXT NOT NULL,
  occupation TEXT NOT NULL DEFAULT 'Lecturer',
  employment_type TEXT NOT NULL DEFAULT 'Full Time',
  gender TEXT NOT NULL DEFAULT 'Not Specified',
  profile_image_path TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lecturer_assigned_units (
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
  UNIQUE(lecturer_id, unit_code, year, semester)
);

CREATE TABLE IF NOT EXISTS user_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL,
  dark_mode_enabled BOOLEAN DEFAULT false,
  has_completed_onboarding BOOLEAN DEFAULT false,
  language TEXT DEFAULT 'en',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create lecturer signup function
CREATE OR REPLACE FUNCTION handle_lecturer_signup()
RETURNS TRIGGER AS $$
BEGIN
  -- Create lecturer record
  INSERT INTO lecturers (
    user_id,
    name,
    email,
    department,
    occupation,
    employment_type,
    gender,
    profile_image_path
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'department', 'Education'),
    COALESCE(NEW.raw_user_meta_data->>'occupation', 'Lecturer'),
    COALESCE(NEW.raw_user_meta_data->>'employment_type', 'Full Time'),
    COALESCE(NEW.raw_user_meta_data->>'gender', 'Not Specified'),
    null
  );

  -- Create default preferences
  INSERT INTO user_preferences (
    user_id,
    dark_mode_enabled,
    has_completed_onboarding,
    language
  ) VALUES (
    NEW.id,
    false,
    false,
    'en'
  );

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    RAISE LOG 'Error in handle_lecturer_signup: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  WHEN (NEW.raw_user_meta_data->>'user_type' = 'lecturer')
  EXECUTE FUNCTION handle_lecturer_signup();

-- Enable RLS on all tables
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY;
ALTER TABLE lecturer_assigned_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Create policies for departments
CREATE POLICY "Anyone can view departments"
ON departments FOR SELECT
USING (true);

CREATE POLICY "Anyone can insert departments"
ON departments FOR INSERT
WITH CHECK (true);

-- Create policies for courses
CREATE POLICY "Anyone can view courses"
ON courses FOR SELECT
USING (true);

-- Create policies for units
CREATE POLICY "Anyone can view units"
ON units FOR SELECT
USING (true);

-- Create policies for lecturers
CREATE POLICY "Allow lecturer read access"
ON lecturers FOR SELECT
USING (true);

CREATE POLICY "Allow lecturer update"
ON lecturers FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow lecturer insert"
ON lecturers FOR INSERT
WITH CHECK (true);

-- Create policies for lecturer_assigned_units
CREATE POLICY "Lecturers can view their assigned units"
ON lecturer_assigned_units FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = lecturer_assigned_units.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

CREATE POLICY "Lecturers can manage their assigned units"
ON lecturer_assigned_units FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = lecturer_assigned_units.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

-- Create policies for user_preferences
CREATE POLICY "Allow lecturer preferences read"
ON user_preferences FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Allow lecturer preferences update"
ON user_preferences FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow lecturer preferences insert"
ON user_preferences FOR INSERT
WITH CHECK (true);

-- Insert default departments if they don't exist
INSERT INTO departments (name) VALUES
('Engineering'),
('Computer Science'),
('Business'),
('Education')
ON CONFLICT (name) DO NOTHING; 
-- Check for uuid extension and create if not exists
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create storage buckets
CREATE SCHEMA IF NOT EXISTS storage;

-- Create bucket for user uploads
INSERT INTO storage.buckets (id, name, owner, created_at, updated_at, public) 
VALUES ('user_uploads', 'user_uploads', null, now(), now(), true)
ON CONFLICT (id) DO NOTHING;

-- Create bucket for lecturer uploads
INSERT INTO storage.buckets (id, name, owner, created_at, updated_at, public) 
VALUES ('lecturer_uploads', 'lecturer_uploads', null, now(), now(), true)
ON CONFLICT (id) DO NOTHING;

-- Set up storage policies for profile images
-- Policy for authenticated users to upload their profile images
CREATE POLICY "Authenticated users can upload their own profile images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'user_uploads' AND
  (path LIKE 'profile_images/%')
);

-- Policy for users to update their own profile images
CREATE POLICY "Users can update their own profile images"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'user_uploads' AND
  (path LIKE 'profile_images/%')
);

-- Policy for public access to profile images
CREATE POLICY "Public can view profile images"
ON storage.objects FOR SELECT TO public
USING (
  bucket_id = 'user_uploads' AND
  (path LIKE 'profile_images/%')
);

-- Set up storage policies for lecturer profile images
-- Policy for authenticated users to upload their own profile images
CREATE POLICY "Authenticated users can upload their own profile images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'lecturer_uploads' AND
  (path LIKE 'profile_images/%')
);

-- Policy for users to update their own profile images
CREATE POLICY "Users can update their own profile images"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'lecturer_uploads' AND
  (path LIKE 'profile_images/%')
);

-- Policy for public access to profile images
CREATE POLICY "Public can view profile images"
ON storage.objects FOR SELECT TO public
USING (
  bucket_id = 'lecturer_uploads' AND
  (path LIKE 'profile_images/%')
);

-- Anonymous users can upload during development/testing
CREATE POLICY "Anonymous users can upload files during development"
ON storage.objects FOR INSERT TO anon
WITH CHECK (
  bucket_id = 'user_uploads'
);

CREATE POLICY "Anonymous users can read files during development"
ON storage.objects FOR SELECT TO anon
USING (
  bucket_id = 'user_uploads'
);

-- Users table (will store both students and lecturers)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  user_type TEXT NOT NULL, -- 'student' or 'lecturer'
  name TEXT,
  password TEXT NOT NULL, -- For local app auth before migrating to Supabase Auth
  password_reset_token TEXT,
  password_reset_expires TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE
);

-- Student-specific data
CREATE TABLE IF NOT EXISTS students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) NOT NULL,
  department TEXT,
  course TEXT,
  year TEXT,
  semester TEXT,
  profile_image_path TEXT,
  current_location TEXT,
  location_latitude DOUBLE PRECISION,
  location_longitude DOUBLE PRECISION,
  location_updated_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Lecturer-specific data
CREATE TABLE IF NOT EXISTS lecturers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) NOT NULL,
  lecture_number TEXT UNIQUE NOT NULL, -- LC number
  department TEXT,
  occupation TEXT,
  employment_type TEXT,
  gender TEXT,
  profile_image_path TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sessions/Attendance
CREATE TABLE IF NOT EXISTS attendance_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  unit_id UUID NOT NULL,
  qr_code_url TEXT NOT NULL,
  qr_code_data JSONB NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  session_data JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Attendance records linking students to sessions
CREATE TABLE IF NOT EXISTS attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES attendance_sessions(id) NOT NULL,
  student_id UUID REFERENCES students(id) NOT NULL,
  time_scanned TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(session_id, student_id)
);

-- User preferences (dark mode, language, etc)
CREATE TABLE IF NOT EXISTS user_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) NOT NULL,
  dark_mode_enabled BOOLEAN DEFAULT FALSE,
  language TEXT DEFAULT 'en',
  has_completed_onboarding BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- QR codes generated by lecturers
CREATE TABLE IF NOT EXISTS qr_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  unit_code TEXT NOT NULL,
  unit_name TEXT,
  date TEXT NOT NULL,
  qr_data TEXT NOT NULL, -- Data encoded in the QR code
  qr_image_path TEXT, -- Path to the QR code image in storage
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create a new table for tracking student location history
CREATE TABLE IF NOT EXISTS student_location_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES students(id) NOT NULL,
  location TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on the location history table
ALTER TABLE student_location_history ENABLE ROW LEVEL SECURITY;

-- Location history table policies
DROP POLICY IF EXISTS "Students can view their own location history" ON student_location_history;
DROP POLICY IF EXISTS "Students can add to their location history" ON student_location_history;
DROP POLICY IF EXISTS "Lecturers can view all location history" ON student_location_history;

CREATE POLICY "Students can view their own location history"
ON student_location_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM students
    WHERE students.id = student_location_history.student_id
    AND students.user_id = auth.uid()
  )
);

CREATE POLICY "Students can add to their location history"
ON student_location_history
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM students
    WHERE students.id = student_location_history.student_id
    AND students.user_id = auth.uid()
  )
);

CREATE POLICY "Lecturers can view all location history"
ON student_location_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.user_id = auth.uid()
  )
);

-- Create a function to update the updated_at timestamp whenever a student's location is updated
CREATE OR REPLACE FUNCTION update_student_location_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop the trigger if it already exists
DROP TRIGGER IF EXISTS update_student_location_timestamp_trigger ON students;

-- Create a trigger to update the timestamp when location changes
CREATE TRIGGER update_student_location_timestamp_trigger
BEFORE UPDATE OF current_location ON students
FOR EACH ROW
EXECUTE FUNCTION update_student_location_timestamp();

-- Add RLS policy to ensure students can update their own location
DROP POLICY IF EXISTS "Students can update their own location" ON students;
CREATE POLICY "Students can update their own location" 
ON students 
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Add an additional policy for students to insert their own location history
DROP POLICY IF EXISTS "Students can insert their own location history" ON student_location_history;
CREATE POLICY "Students can insert their own location history"
ON student_location_history
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM students
    WHERE students.id = student_location_history.student_id
    AND students.user_id = auth.uid()
  )
);

-- Row-Level Security Policies

-- Users table policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create a more permissive policy for the users table
DROP POLICY IF EXISTS "Allow anonymous signups" ON users;
DROP POLICY IF EXISTS "Users can view their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;

CREATE POLICY "Allow anonymous signups"
ON users 
FOR ALL
USING (true)
WITH CHECK (true);

-- Students table policies
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- Create a more permissive policy for the students table
DROP POLICY IF EXISTS "Allow anonymous student creation" ON students;
DROP POLICY IF EXISTS "Students can view their own data" ON students;
DROP POLICY IF EXISTS "Students can update their own data" ON students;

CREATE POLICY "Allow anonymous student creation"
ON students 
FOR ALL
USING (true)
WITH CHECK (true);

-- Lecturers table policies
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY;

-- Create a more permissive policy for the lecturers table
DROP POLICY IF EXISTS "Allow anonymous lecturer creation" ON lecturers;
DROP POLICY IF EXISTS "Lecturers can view their own data" ON lecturers;
DROP POLICY IF EXISTS "Lecturers can update their own data" ON lecturers;

CREATE POLICY "Allow anonymous lecturer creation"
ON lecturers 
FOR ALL
USING (true)
WITH CHECK (true);

-- Sessions table policies
ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lecturers can view their sessions" ON attendance_sessions;
DROP POLICY IF EXISTS "Lecturers can create sessions" ON attendance_sessions;
DROP POLICY IF EXISTS "Students can view all sessions" ON attendance_sessions;

CREATE POLICY "Allow all operations on attendance_sessions"
ON attendance_sessions FOR ALL USING (true) WITH CHECK (true);

-- Attendance table policies
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- Make attendance table more permissive
DROP POLICY IF EXISTS "Allow anonymous attendance marking" ON attendance;
DROP POLICY IF EXISTS "Students can view their own attendance" ON attendance;
DROP POLICY IF EXISTS "Lecturers can view attendance for their sessions" ON attendance;

CREATE POLICY "Allow anonymous attendance marking"
ON attendance 
FOR ALL
USING (true)
WITH CHECK (true);

-- User preferences policies
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Make user_preferences more permissive
DROP POLICY IF EXISTS "Allow anonymous preferences creation" ON user_preferences;
DROP POLICY IF EXISTS "Users can view their own preferences" ON user_preferences;
DROP POLICY IF EXISTS "Users can update their own preferences" ON user_preferences;

CREATE POLICY "Allow anonymous preferences creation"
ON user_preferences 
FOR ALL
USING (true)
WITH CHECK (true);

-- QR codes policies
ALTER TABLE qr_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lecturers can view their own QR codes" ON qr_codes;
DROP POLICY IF EXISTS "Lecturers can create QR codes" ON qr_codes;
DROP POLICY IF EXISTS "Students can view active QR codes" ON qr_codes;

CREATE POLICY "Lecturers can view their own QR codes" 
ON qr_codes FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM lecturers 
    WHERE lecturers.id = qr_codes.lecturer_id 
    AND lecturers.user_id = auth.uid()
  )
);

CREATE POLICY "Lecturers can create QR codes"
ON qr_codes FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM lecturers 
    WHERE lecturers.id = qr_codes.lecturer_id 
    AND lecturers.user_id = auth.uid()
  )
);

CREATE POLICY "Students can view active QR codes" 
ON qr_codes FOR SELECT USING (
  qr_codes.is_active = true AND
  EXISTS (
    SELECT 1 FROM students 
    WHERE students.user_id = auth.uid()
  )
);

-- Function to get student by credentials, avoiding duplicates
CREATE OR REPLACE FUNCTION get_student_by_credentials(p_email TEXT, p_password TEXT)
RETURNS SETOF json AS $$
BEGIN
  RETURN QUERY
  SELECT json_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'password', u.password,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path,
    'student_id', s.id
  )
  FROM users u
  JOIN students s ON u.id = s.user_id
  WHERE u.email = p_email
  AND u.password = p_password
  AND u.user_type = 'student'
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Tables for dropdown options

-- Departments
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Courses (linked to departments)
CREATE TABLE IF NOT EXISTS courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  department_id UUID REFERENCES departments(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(name, department_id)
);

-- Academic years
CREATE TABLE IF NOT EXISTS academic_years (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  year TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Semesters
CREATE TABLE IF NOT EXISTS semesters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Units (for storing unit codes and names)
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

-- Admins table
CREATE TABLE IF NOT EXISTS admins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on dropdown tables
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE semesters ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- RLS policies for dropdown options tables

-- Departments policies
CREATE POLICY "Anyone can view departments"
ON departments FOR SELECT
USING (true);

CREATE POLICY "Only admins can insert departments"
ON departments FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can update departments"
ON departments FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can delete departments"
ON departments FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

-- Courses policies
CREATE POLICY "Anyone can view courses"
ON courses FOR SELECT
USING (true);

CREATE POLICY "Only admins can insert courses"
ON courses FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can update courses"
ON courses FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can delete courses"
ON courses FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

-- Academic years policies
CREATE POLICY "Anyone can view academic years"
ON academic_years FOR SELECT
USING (true);

CREATE POLICY "Only admins can insert academic years"
ON academic_years FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can update academic years"
ON academic_years FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can delete academic years"
ON academic_years FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

-- Semesters policies
CREATE POLICY "Anyone can view semesters"
ON semesters FOR SELECT
USING (true);

CREATE POLICY "Only admins can insert semesters"
ON semesters FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can update semesters"
ON semesters FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can delete semesters"
ON semesters FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

-- Units policies
CREATE POLICY "Anyone can view units"
ON units FOR SELECT
USING (true);

CREATE POLICY "Only admins can insert units"
ON units FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can update units"
ON units FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Only admins can delete units"
ON units FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

-- Admins policies
CREATE POLICY "Admins can view admin list"
ON admins FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

CREATE POLICY "Super admins can insert admins"
ON admins FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM admins
    WHERE admins.user_id = auth.uid()
  )
);

-- Insert initial data for departments
INSERT INTO departments (name) VALUES
('Computer Science'),
('Engineering'),
('Business'),
('Education')
ON CONFLICT (name) DO NOTHING;

-- Insert initial data for academic years
INSERT INTO academic_years (year) VALUES
('Year 1'),
('Year 2'),
('Year 3'),
('Year 4')
ON CONFLICT (year) DO NOTHING;

-- Insert initial data for semesters
INSERT INTO semesters (name) VALUES
('Semester 1'),
('Semester 2')
ON CONFLICT (name) DO NOTHING;

-- Insert all Computer Science courses
INSERT INTO courses (name, department_id)
SELECT 'Computer Science', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Software Engineering', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Data Science', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Programming Fundamentals', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Data Structures', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Algorithms', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Database Systems', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Operating Systems', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Computer Networks', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Computer Architecture', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Advanced Programming', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Machine Learning', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Artificial Intelligence', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Web Development', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Mobile Development', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Cloud Computing', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Cyber Security', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Data Mining', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Big Data', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Computer Vision', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Natural Language Processing', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Human-Computer Interaction', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Distributed Systems', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Capstone Project', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Research Methods', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Professional Practice', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Ethics in Computing', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Project Management', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Entrepreneurship', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Innovation', id FROM departments WHERE name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert all Engineering courses
INSERT INTO courses (name, department_id)
SELECT 'Mechanical Engineering', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Electrical Engineering', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Civil Engineering', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Engineering Mathematics', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Physics for Engineers', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Chemistry for Engineers', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Engineering Mechanics', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Thermodynamics', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Fluid Mechanics', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Solid Mechanics', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Materials Science', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Dynamics', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Control Systems', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Engineering Design', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Electrical Circuits', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Electronics', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Digital Systems', id FROM departments WHERE name = 'Engineering'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert all Business courses
INSERT INTO courses (name, department_id)
SELECT 'Business Administration', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Marketing', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Finance', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Principles of Marketing', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Corporate Finance', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Organizational Behavior', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Business Law', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Strategic Management', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Operations Management', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Business Ethics', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Human Resource Management', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'International Business', id FROM departments WHERE name = 'Business'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert all Education courses
INSERT INTO courses (name, department_id)
SELECT 'Math/bio', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'phys/chem', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'kiswa/hisory', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Educational Psychology', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Teaching Methods', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Curriculum Development', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Educational Technology', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Classroom Management', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

INSERT INTO courses (name, department_id)
SELECT 'Assessment and Evaluation', id FROM departments WHERE name = 'Education'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert Computer Science unit codes and names
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('CS101', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS102', 'Data Structures', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS103', 'Computer Architecture', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 2
  ('CS201', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS202', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS203', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 3
  ('CS301', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS302', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS303', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 4
  ('CS401', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS402', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS403', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science'))
ON CONFLICT (code) DO NOTHING;

-- Insert Engineering unit codes and names
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ENG101', 'Engineering Mathematics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG102', 'Physics for Engineers', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG103', 'Chemistry for Engineers', (SELECT id FROM courses WHERE name = 'Electrical Engineering')),
  ('ENG104', 'Engineering Mechanics', (SELECT id FROM courses WHERE name = 'Electrical Engineering')),
  
  -- Year 2
  ('ENG201', 'Thermodynamics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
  ('ENG202', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG203', 'Solid Mechanics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  
  -- Year 3
  ('ENG301', 'Materials Science', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG302', 'Dynamics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG303', 'Control Systems', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  
  -- Year 4
  ('ENG401', 'Engineering Design', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG402', 'Electrical Circuits', (SELECT id FROM courses WHERE name = 'Electrical Engineering')),
  ('ENG403', 'Electronics', (SELECT id FROM courses WHERE name = 'Electrical Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert Business unit codes and names
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('BUS101', 'Principles of Marketing', (SELECT id FROM courses WHERE name = 'Business Administration')),
  ('BUS102', 'Corporate Finance', (SELECT id FROM courses WHERE name = 'Finance')),
  ('BUS103', 'Organizational Behavior', (SELECT id FROM courses WHERE name = 'Marketing')),
  
  -- Year 2
  ('BUS201', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Finance')),
  ('BUS202', 'Operations Management', (SELECT id FROM courses WHERE name = 'Marketing')),
  ('BUS203', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business Administration')),
  
  -- Year 3
  ('BUS301', 'International Business', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS302', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS303', 'Business Law', (SELECT id FROM courses WHERE name = 'Business Administration')),
  
  -- Year 4
  ('BUS401', 'Marketing', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS402', 'Finance', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS403', 'Management Accounting', (SELECT id FROM courses WHERE name = 'Business'))
ON CONFLICT (code) DO NOTHING;

-- Insert Education unit codes and names
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ART101', 'World History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART102', 'English Literature', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART103', 'Philosophical Thought', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 2
  ('ART201', 'Art History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART202', 'Cultural Studies', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART203', 'Creative Writing', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 3
  ('ART301', 'Performing Arts', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART302', 'Educational Psychology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART303', 'Curriculum Development', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 4
  ('ART401', 'Teaching Methods', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART402', 'Educational Technology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART403', 'Classroom Management', (SELECT id FROM courses WHERE name = 'kiswa/hisory'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Computer Science units for Computer Science course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('CS101', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS102', 'Data Structures', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS103', 'Computer Architecture', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 2
  ('CS201', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS202', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS203', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 3
  ('CS301', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS302', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS303', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 4
  ('CS401', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS402', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS403', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Engineering units for Mechanical Engineering course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ENG101', 'Engineering Mathematics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG102', 'Physics for Engineers', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  
  -- Year 2
  ('ENG201', 'Thermodynamics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG202', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  
  -- Year 3
  ('ENG301', 'Solid Mechanics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG302', 'Dynamics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  
  -- Year 4
  ('ENG401', 'Engineering Design', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG402', 'Control Systems', (SELECT id FROM courses WHERE name = 'Mechanical Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Business units for Business Administration course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('BUS101', 'Principles of Marketing', (SELECT id FROM courses WHERE name = 'Business Administration')),
  ('BUS102', 'Corporate Finance', (SELECT id FROM courses WHERE name = 'Finance')),
  
  -- Year 2
  ('BUS201', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Finance')),
  ('BUS202', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 3
  ('BUS301', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS302', 'International Business', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 4
  ('BUS401', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS402', 'Management Accounting', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS403', 'Marketing', (SELECT id FROM courses WHERE name = 'Business'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Education units for education courses
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ART101', 'World History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART102', 'English Literature', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART103', 'Philosophical Thought', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 2
  ('ART201', 'Art History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART202', 'Cultural Studies', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART203', 'Creative Writing', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 3
  ('ART301', 'Performing Arts', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART302', 'Educational Psychology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART303', 'Curriculum Development', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 4
  ('ART401', 'Teaching Methods', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART402', 'Educational Technology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART403', 'Classroom Management', (SELECT id FROM courses WHERE name = 'kiswa/hisory'))
ON CONFLICT (code) DO NOTHING;

-- Create functions to get dropdown options

CREATE OR REPLACE FUNCTION get_departments()
RETURNS SETOF departments AS $$
BEGIN
  RETURN QUERY SELECT * FROM departments ORDER BY name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_courses_by_department(department_id UUID)
RETURNS SETOF courses AS $$
BEGIN
  RETURN QUERY SELECT * FROM courses WHERE courses.department_id = $1 ORDER BY name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_academic_years()
RETURNS SETOF academic_years AS $$
BEGIN
  RETURN QUERY SELECT * FROM academic_years ORDER BY year;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_semesters()
RETURNS SETOF semesters AS $$
BEGIN
  RETURN QUERY SELECT * FROM semesters ORDER BY name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_units_by_department(department_id UUID)
RETURNS SETOF units AS $$
BEGIN
  RETURN QUERY SELECT * FROM units WHERE units.department_id = $1 ORDER BY code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace the functions to support student signup and updates

-- Function to get all dropdown data for student signup in one call
CREATE OR REPLACE FUNCTION get_student_signup_data()
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'departments', (SELECT json_agg(row_to_json(d)) FROM (SELECT id, name FROM departments ORDER BY name) d),
    'academic_years', (SELECT json_agg(row_to_json(y)) FROM (SELECT id, year FROM academic_years ORDER BY year) y),
    'semesters', (SELECT json_agg(row_to_json(s)) FROM (SELECT id, name FROM semesters ORDER BY name) s)
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get courses by department for cascade dropdowns
CREATE OR REPLACE FUNCTION get_department_courses(p_department_id UUID)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_agg(row_to_json(c))
  FROM (
    SELECT id, name
    FROM courses
    WHERE department_id = p_department_id
    ORDER BY name
  ) c INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get units by department for sessions
CREATE OR REPLACE FUNCTION get_department_units(p_department_id UUID)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_agg(row_to_json(u))
  FROM (
    SELECT id, code, name
    FROM units
    WHERE department_id = p_department_id
    ORDER BY code
  ) u INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update student information using the referenced tables
CREATE OR REPLACE FUNCTION update_student_info(
  p_student_id UUID,
  p_department_id UUID,
  p_course_id UUID,
  p_year_id UUID,
  p_semester_id UUID
) RETURNS boolean AS $$
DECLARE
  v_department_name TEXT;
  v_course_name TEXT;
  v_year_name TEXT;
  v_semester_name TEXT;
BEGIN
  -- Get the actual values from the lookup tables
  SELECT name INTO v_department_name FROM departments WHERE id = p_department_id;
  SELECT name INTO v_course_name FROM courses WHERE id = p_course_id;
  SELECT year INTO v_year_name FROM academic_years WHERE id = p_year_id;
  SELECT name INTO v_semester_name FROM semesters WHERE id = p_semester_id;
  
  -- Update the student record with these values
  UPDATE students 
  SET 
    department = v_department_name,
    course = v_course_name,
    year = v_year_name,
    semester = v_semester_name,
    updated_at = NOW()
  WHERE id = p_student_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add a function to help with migration of existing data
CREATE OR REPLACE FUNCTION migrate_student_to_reference_ids() 
RETURNS void AS $$
DECLARE
  student_rec RECORD;
  dept_id UUID;
  course_id UUID;
  year_id UUID;
  semester_id UUID;
BEGIN
  FOR student_rec IN SELECT * FROM students LOOP
    -- Find matching IDs from reference tables
    SELECT id INTO dept_id FROM departments WHERE name = student_rec.department;
    SELECT id INTO course_id FROM courses WHERE name = student_rec.course;
    SELECT id INTO year_id FROM academic_years WHERE year = student_rec.year;
    SELECT id INTO semester_id FROM semesters WHERE name = student_rec.semester;
    
    -- Create reference columns if they don't exist yet
    BEGIN
      ALTER TABLE students ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id);
      ALTER TABLE students ADD COLUMN IF NOT EXISTS course_id UUID REFERENCES courses(id);
      ALTER TABLE students ADD COLUMN IF NOT EXISTS year_id UUID REFERENCES academic_years(id);
      ALTER TABLE students ADD COLUMN IF NOT EXISTS semester_id UUID REFERENCES semesters(id);
    EXCEPTION WHEN duplicate_column THEN
      -- Columns already exist, continue
    END;
    
    -- Update the student with reference IDs
    UPDATE students 
    SET 
      department_id = dept_id,
      course_id = course_id,
      year_id = year_id,
      semester_id = semester_id
    WHERE id = student_rec.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Update the unit selection functions to respect department > course > unit hierarchy

-- Function to get units by course for cascade dropdowns
CREATE OR REPLACE FUNCTION get_units_by_course(p_course_id UUID)
RETURNS SETOF units AS $$
BEGIN
  RETURN QUERY SELECT * FROM units WHERE units.course_id = $1 ORDER BY code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert sample Computer Science units for Computer Science course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('CS111', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS112', 'Computer Organization', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS121', 'Data Structures and Algorithms', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS122', 'Discrete Mathematics', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 2
  ('CS211', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS212', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS221', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS222', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 3
  ('CS311', 'Software Engineering', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS312', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS321', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS322', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 4
  ('CS411', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS412', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS421', 'Project Management', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS422', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science'))
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    updated_at = NOW();

-- Insert sample Engineering units for Mechanical Engineering course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ENG101', 'Engineering Mathematics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG102', 'Physics for Engineers', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  
  -- Year 2
  ('ENG201', 'Thermodynamics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG202', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  
  -- Year 3
  ('ENG301', 'Solid Mechanics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG302', 'Dynamics', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  
  -- Year 4
  ('ENG401', 'Engineering Design', (SELECT id FROM courses WHERE name = 'Mechanical Engineering')),
  ('ENG402', 'Control Systems', (SELECT id FROM courses WHERE name = 'Mechanical Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Business units for Business Administration course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('BUS101', 'Principles of Marketing', (SELECT id FROM courses WHERE name = 'Business Administration')),
  ('BUS102', 'Corporate Finance', (SELECT id FROM courses WHERE name = 'Finance')),
  
  -- Year 2
  ('BUS201', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Finance')),
  ('BUS202', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 3
  ('BUS301', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS302', 'International Business', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 4
  ('BUS401', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS402', 'Management Accounting', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS403', 'Marketing', (SELECT id FROM courses WHERE name = 'Business'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Education units for education courses
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ART101', 'World History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART102', 'English Literature', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART103', 'Philosophical Thought', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 2
  ('ART201', 'Art History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART202', 'Cultural Studies', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART203', 'Creative Writing', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 3
  ('ART301', 'Performing Arts', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART302', 'Educational Psychology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART303', 'Curriculum Development', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 4
  ('ART401', 'Teaching Methods', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART402', 'Educational Technology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART403', 'Classroom Management', (SELECT id FROM courses WHERE name = 'kiswa/hisory'))
ON CONFLICT (code) DO NOTHING;

-- Create function to get units by course (replacing get_units_by_department)
CREATE OR REPLACE FUNCTION get_units_by_course(p_course_id UUID)
RETURNS SETOF units AS $$
BEGIN
  RETURN QUERY SELECT * FROM units WHERE units.course_id = $1 ORDER BY code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get units by course for cascade dropdowns (JSON format)
CREATE OR REPLACE FUNCTION get_course_units(p_course_id UUID)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_agg(row_to_json(u))
  FROM (
    SELECT id, code, name
    FROM units
    WHERE course_id = p_course_id
    ORDER BY code
  ) u INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get student signup data with cascade dropdown structure
CREATE OR REPLACE FUNCTION get_student_signup_data_cascade()
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'departments', (
      SELECT json_agg(
        json_build_object(
          'id', d.id, 
          'name', d.name,
          'courses', (
            SELECT json_agg(
              json_build_object(
                'id', c.id,
                'name', c.name
              )
            )
            FROM courses c
            WHERE c.department_id = d.id
          )
        )
      )
      FROM departments d
    ),
    'academic_years', (
      SELECT json_agg(row_to_json(y)) 
      FROM (SELECT id, year FROM academic_years ORDER BY year) y
    ),
    'semesters', (
      SELECT json_agg(row_to_json(s)) 
      FROM (SELECT id, name FROM semesters ORDER BY name) s
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Add after the existing triggers and functions

-- Function to update student profile with improved handling of all fields
CREATE OR REPLACE FUNCTION update_student_profile(
  p_student_id UUID,
  p_name TEXT DEFAULT NULL,
  p_department TEXT DEFAULT NULL,
  p_course TEXT DEFAULT NULL,
  p_year TEXT DEFAULT NULL,
  p_semester TEXT DEFAULT NULL,
  p_password TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_updated_user JSONB;
  v_updated_student JSONB;
  v_changes_made BOOLEAN;
  v_user_changes BOOLEAN;
  v_student_changes BOOLEAN;
BEGIN
  -- Get the user_id associated with the student
  SELECT user_id INTO v_user_id FROM students WHERE id = p_student_id;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Student record not found');
  END IF;
  
  -- Track if any changes were made
  v_changes_made := false;
  
  -- Update user table if name or password provided
  IF p_name IS NOT NULL OR p_password IS NOT NULL THEN
    -- Check if name or password is actually different
    SELECT 
      (p_name IS NOT NULL AND p_name != name) OR 
      (p_password IS NOT NULL AND p_password != password)
    INTO v_user_changes
    FROM users 
    WHERE id = v_user_id;
    
    IF v_user_changes THEN
    UPDATE users
    SET 
      name = COALESCE(p_name, name),
      password = COALESCE(p_password, password),
      updated_at = NOW()
    WHERE id = v_user_id;
      
      v_changes_made := true;
    END IF;
  END IF;
  
  -- Update student table with academic information
  SELECT 
    (p_department IS NOT NULL AND p_department != department) OR
    (p_course IS NOT NULL AND p_course != course) OR
    (p_year IS NOT NULL AND p_year != year) OR
    (p_semester IS NOT NULL AND p_semester != semester)
  INTO v_student_changes
  FROM students
  WHERE id = p_student_id;
  
  IF v_student_changes THEN
  UPDATE students
  SET 
    department = COALESCE(p_department, department),
    course = COALESCE(p_course, course),
    year = COALESCE(p_year, year),
    semester = COALESCE(p_semester, semester),
    updated_at = NOW()
  WHERE id = p_student_id;
    
    v_changes_made := true;
  END IF;
  
  -- Only proceed if changes were actually made
  IF NOT v_changes_made THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'No changes detected'
    );
  END IF;
  
  -- Retrieve updated information
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'password', u.password
  ) INTO v_updated_user
  FROM users u
  WHERE u.id = v_user_id;
  
  SELECT jsonb_build_object(
    'student_id', s.id,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path
  ) INTO v_updated_student
  FROM students s
  WHERE s.id = p_student_id;
  
  v_result = jsonb_build_object(
    'success', true,
    'message', 'Profile updated successfully',
    'user', v_updated_user,
    'student', v_updated_student
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a more permissive update policy for students table
DROP POLICY IF EXISTS "Students can update their own academic information" ON students;
CREATE POLICY "Students can update their own academic information"
ON students
FOR UPDATE
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = students.user_id
    AND users.id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = students.user_id
    AND users.id = auth.uid()
  )
);

-- Create function to refresh dashboard data after profile update
CREATE OR REPLACE FUNCTION refresh_student_dashboard_data(p_student_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'student_id', s.id,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path,
    'current_location', s.current_location
  ) INTO v_result
  FROM users u
  JOIN students s ON u.id = s.user_id
  WHERE s.id = p_student_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Function to update lecturer profile
CREATE OR REPLACE FUNCTION update_lecturer_profile(
  p_lecturer_id UUID,
  p_name TEXT DEFAULT NULL,
  p_department TEXT DEFAULT NULL,
  p_occupation TEXT DEFAULT NULL,
  p_employment_type TEXT DEFAULT NULL,
  p_gender TEXT DEFAULT NULL,
  p_profile_image_path TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_updated_user JSONB;
  v_updated_lecturer JSONB;
  v_changes_made BOOLEAN;
  v_user_changes BOOLEAN;
  v_lecturer_changes BOOLEAN;
BEGIN
  -- Get the user_id associated with the lecturer
  SELECT user_id INTO v_user_id FROM lecturers WHERE id = p_lecturer_id;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Lecturer record not found');
  END IF;
  
  -- Track if any changes were made
  v_changes_made := false;
  
  -- Update user table if name provided
  IF p_name IS NOT NULL THEN
    -- Check if name is actually different
    SELECT (p_name != name) INTO v_user_changes
    FROM users 
    WHERE id = v_user_id;
    
    IF v_user_changes THEN
      UPDATE users
      SET 
        name = p_name,
        updated_at = NOW()
      WHERE id = v_user_id;
      
      v_changes_made := true;
    END IF;
  END IF;
  
  -- Update lecturer table with provided information
  SELECT 
    (p_department IS NOT NULL AND p_department != department) OR
    (p_occupation IS NOT NULL AND p_occupation != occupation) OR
    (p_employment_type IS NOT NULL AND p_employment_type != employment_type) OR
    (p_gender IS NOT NULL AND p_gender != gender) OR
    (p_profile_image_path IS NOT NULL AND p_profile_image_path != profile_image_path)
  INTO v_lecturer_changes
  FROM lecturers
  WHERE id = p_lecturer_id;
  
  IF v_lecturer_changes THEN
    UPDATE lecturers
    SET 
      department = COALESCE(p_department, department),
      occupation = COALESCE(p_occupation, occupation),
      employment_type = COALESCE(p_employment_type, employment_type),
      gender = COALESCE(p_gender, gender),
      profile_image_path = COALESCE(p_profile_image_path, profile_image_path),
      updated_at = NOW()
    WHERE id = p_lecturer_id;
    
    v_changes_made := true;
  END IF;
  
  -- Only proceed if changes were actually made
  IF NOT v_changes_made THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'No changes detected'
    );
  END IF;
  
  -- Retrieve updated information
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name
  ) INTO v_updated_user
  FROM users u
  WHERE u.id = v_user_id;
  
  SELECT jsonb_build_object(
    'lecturer_id', l.id,
    'department', l.department,
    'occupation', l.occupation,
    'employment_type', l.employment_type,
    'gender', l.gender,
    'profile_image_path', l.profile_image_path
  ) INTO v_updated_lecturer
  FROM lecturers l
  WHERE l.id = p_lecturer_id;
  
  v_result = jsonb_build_object(
    'success', true,
    'message', 'Profile updated successfully',
    'user', v_updated_user,
    'lecturer', v_updated_lecturer
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refresh lecturer dashboard data
CREATE OR REPLACE FUNCTION refresh_lecturer_dashboard_data(p_lecturer_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'lecturer_id', l.id,
    'department', l.department,
    'occupation', l.occupation,
    'employment_type', l.employment_type,
    'gender', l.gender,
    'profile_image_path', l.profile_image_path
  ) INTO v_result
  FROM users u
  JOIN lecturers l ON u.id = l.user_id
  WHERE l.id = p_lecturer_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Create policies for lecturer profile updates
DROP POLICY IF EXISTS "Lecturers can update their own profile" ON lecturers;
CREATE POLICY "Lecturers can update their own profile"
ON lecturers
FOR UPDATE
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
);

-- Create policies for lecturer data access
DROP POLICY IF EXISTS "Lecturers can view their own data" ON lecturers;
CREATE POLICY "Lecturers can view their own data"
ON lecturers
FOR SELECT
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
);

-- Enable RLS on lecturers table if not already enabled
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY; 

-- Create lecturer_assigned_units table if not exists
CREATE TABLE IF NOT EXISTS lecturer_assigned_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  lecturer_email TEXT NOT NULL,
  unit_code TEXT NOT NULL,
  unit_name TEXT NOT NULL,
  department TEXT NOT NULL,
  course_name TEXT NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(lecturer_id, unit_code)
);

-- Insert sample departments if they don't exist
INSERT INTO departments (name) 
VALUES ('Computer Science'), ('Software Engineering')
ON CONFLICT (name) DO NOTHING;

-- Insert sample courses for Computer Science
INSERT INTO courses (name, department_id)
SELECT 'Computer Science', d.id
FROM departments d
WHERE d.name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert sample courses for Software Engineering
INSERT INTO courses (name, department_id)
SELECT 'Software Engineering', d.id
FROM departments d
WHERE d.name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert sample units for Computer Science
INSERT INTO units (code, name, course_id) VALUES
-- Computer Science Units
('CS111', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS112', 'Computer Organization', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS121', 'Data Structures and Algorithms', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS122', 'Discrete Mathematics', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS211', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS212', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS221', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS222', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS311', 'Software Engineering', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS312', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS321', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS322', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS411', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS412', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS421', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS422', 'Project Management', (SELECT id FROM courses WHERE name = 'Computer Science')),

-- Civil Engineering Units
('CE111', 'Engineering Mathematics I', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE112', 'Engineering Drawing', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE121', 'Engineering Mathematics II', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE122', 'Structural Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE211', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE212', 'Construction Materials', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE221', 'Soil Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE222', 'Surveying', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE311', 'Structural Analysis', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE312', 'Transportation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE321', 'Foundation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE322', 'Environmental Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE411', 'Construction Management', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE412', 'Steel Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE421', 'Concrete Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE422', 'Highway Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),

-- Business Administration Units
('BA111', 'Principles of Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA112', 'Business Mathematics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA121', 'Financial Accounting', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA122', 'Business Communication', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA211', 'Marketing Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA212', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA221', 'Business Law', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA222', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA311', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA312', 'International Business', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA321', 'Entrepreneurship', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA322', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA411', 'Project Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA412', 'Risk Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA421', 'Business Analytics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA422', 'Digital Business', (SELECT id FROM courses WHERE name = 'Business Administration')),

-- Math/Bio Units
('MB111', 'Calculus I', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB112', 'General Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB121', 'Calculus II', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB122', 'Cell Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB211', 'Linear Algebra', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB212', 'Genetics', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB221', 'Differential Equations', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB222', 'Molecular Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB311', 'Statistics', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB312', 'Ecology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB321', 'Complex Analysis', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB322', 'Evolution', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB411', 'Abstract Algebra', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB412', 'Biotechnology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB421', 'Number Theory', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB422', 'Bioinformatics', (SELECT id FROM courses WHERE name = 'Math/bio'))
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    updated_at = NOW();

-- Insert sample units for Software Engineering
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('SE101', 'Software Development Fundamentals', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE102', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE103', 'Software Design Patterns', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 2
  ('SE201', 'Software Requirements Engineering', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE202', 'Software Testing', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE203', 'Agile Development', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 3
  ('SE301', 'Software Project Management', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE302', 'DevOps Practices', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE303', 'Enterprise Software Architecture', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 4
  ('SE401', 'Software Quality Assurance', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE402', 'Microservices Architecture', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE403', 'Software Maintenance', (SELECT id FROM courses WHERE name = 'Software Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample units for Software Engineering
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('SE101', 'Software Development Fundamentals', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE102', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 2
  ('SE201', 'Thermodynamics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE202', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 3
  ('SE301', 'Solid Mechanics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE302', 'Dynamics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 4
  ('SE401', 'Engineering Design', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE402', 'Control Systems', (SELECT id FROM courses WHERE name = 'Software Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Business units for Business Administration course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('BUS101', 'Principles of Marketing', (SELECT id FROM courses WHERE name = 'Business Administration')),
  ('BUS102', 'Corporate Finance', (SELECT id FROM courses WHERE name = 'Finance')),
  
  -- Year 2
  ('BUS201', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Finance')),
  ('BUS202', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 3
  ('BUS301', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS302', 'International Business', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 4
  ('BUS401', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS402', 'Management Accounting', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS403', 'Marketing', (SELECT id FROM courses WHERE name = 'Business'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Education units for education courses
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ART101', 'World History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART102', 'English Literature', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART103', 'Philosophical Thought', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 2
  ('ART201', 'Art History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART202', 'Cultural Studies', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART203', 'Creative Writing', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 3
  ('ART301', 'Performing Arts', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART302', 'Educational Psychology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART303', 'Curriculum Development', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 4
  ('ART401', 'Teaching Methods', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART402', 'Educational Technology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART403', 'Classroom Management', (SELECT id FROM courses WHERE name = 'kiswa/hisory'))
ON CONFLICT (code) DO NOTHING;

-- Create function to get units by course (replacing get_units_by_department)
CREATE OR REPLACE FUNCTION get_units_by_course(p_course_id UUID)
RETURNS SETOF units AS $$
BEGIN
  RETURN QUERY SELECT * FROM units WHERE units.course_id = $1 ORDER BY code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get units by course for cascade dropdowns (JSON format)
CREATE OR REPLACE FUNCTION get_course_units(p_course_id UUID)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_agg(row_to_json(u))
  FROM (
    SELECT id, code, name
    FROM units
    WHERE course_id = p_course_id
    ORDER BY code
  ) u INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get student signup data with cascade dropdown structure
CREATE OR REPLACE FUNCTION get_student_signup_data_cascade()
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'departments', (
      SELECT json_agg(
        json_build_object(
          'id', d.id, 
          'name', d.name,
          'courses', (
            SELECT json_agg(
              json_build_object(
                'id', c.id,
                'name', c.name
              )
            )
            FROM courses c
            WHERE c.department_id = d.id
          )
        )
      )
      FROM departments d
    ),
    'academic_years', (
      SELECT json_agg(row_to_json(y)) 
      FROM (SELECT id, year FROM academic_years ORDER BY year) y
    ),
    'semesters', (
      SELECT json_agg(row_to_json(s)) 
      FROM (SELECT id, name FROM semesters ORDER BY name) s
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Add after the existing triggers and functions

-- Function to update student profile with improved handling of all fields
CREATE OR REPLACE FUNCTION update_student_profile(
  p_student_id UUID,
  p_name TEXT DEFAULT NULL,
  p_department TEXT DEFAULT NULL,
  p_course TEXT DEFAULT NULL,
  p_year TEXT DEFAULT NULL,
  p_semester TEXT DEFAULT NULL,
  p_password TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_updated_user JSONB;
  v_updated_student JSONB;
  v_changes_made BOOLEAN;
  v_user_changes BOOLEAN;
  v_student_changes BOOLEAN;
BEGIN
  -- Get the user_id associated with the student
  SELECT user_id INTO v_user_id FROM students WHERE id = p_student_id;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Student record not found');
  END IF;
  
  -- Track if any changes were made
  v_changes_made := false;
  
  -- Update user table if name or password provided
  IF p_name IS NOT NULL OR p_password IS NOT NULL THEN
    -- Check if name or password is actually different
    SELECT 
      (p_name IS NOT NULL AND p_name != name) OR 
      (p_password IS NOT NULL AND p_password != password)
    INTO v_user_changes
    FROM users 
    WHERE id = v_user_id;
    
    IF v_user_changes THEN
    UPDATE users
    SET 
      name = COALESCE(p_name, name),
      password = COALESCE(p_password, password),
      updated_at = NOW()
    WHERE id = v_user_id;
      
      v_changes_made := true;
    END IF;
  END IF;
  
  -- Update student table with academic information
  SELECT 
    (p_department IS NOT NULL AND p_department != department) OR
    (p_course IS NOT NULL AND p_course != course) OR
    (p_year IS NOT NULL AND p_year != year) OR
    (p_semester IS NOT NULL AND p_semester != semester)
  INTO v_student_changes
  FROM students
  WHERE id = p_student_id;
  
  IF v_student_changes THEN
  UPDATE students
  SET 
    department = COALESCE(p_department, department),
    course = COALESCE(p_course, course),
    year = COALESCE(p_year, year),
    semester = COALESCE(p_semester, semester),
    updated_at = NOW()
  WHERE id = p_student_id;
    
    v_changes_made := true;
  END IF;
  
  -- Only proceed if changes were actually made
  IF NOT v_changes_made THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'No changes detected'
    );
  END IF;
  
  -- Retrieve updated information
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'password', u.password
  ) INTO v_updated_user
  FROM users u
  WHERE u.id = v_user_id;
  
  SELECT jsonb_build_object(
    'student_id', s.id,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path
  ) INTO v_updated_student
  FROM students s
  WHERE s.id = p_student_id;
  
  v_result = jsonb_build_object(
    'success', true,
    'message', 'Profile updated successfully',
    'user', v_updated_user,
    'student', v_updated_student
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a more permissive update policy for students table
DROP POLICY IF EXISTS "Students can update their own academic information" ON students;
CREATE POLICY "Students can update their own academic information"
ON students
FOR UPDATE
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = students.user_id
    AND users.id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = students.user_id
    AND users.id = auth.uid()
  )
);

-- Create function to refresh dashboard data after profile update
CREATE OR REPLACE FUNCTION refresh_student_dashboard_data(p_student_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'student_id', s.id,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path,
    'current_location', s.current_location
  ) INTO v_result
  FROM users u
  JOIN students s ON u.id = s.user_id
  WHERE s.id = p_student_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Function to update lecturer profile
CREATE OR REPLACE FUNCTION update_lecturer_profile(
  p_lecturer_id UUID,
  p_name TEXT DEFAULT NULL,
  p_department TEXT DEFAULT NULL,
  p_occupation TEXT DEFAULT NULL,
  p_employment_type TEXT DEFAULT NULL,
  p_gender TEXT DEFAULT NULL,
  p_profile_image_path TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_updated_user JSONB;
  v_updated_lecturer JSONB;
  v_changes_made BOOLEAN;
  v_user_changes BOOLEAN;
  v_lecturer_changes BOOLEAN;
BEGIN
  -- Get the user_id associated with the lecturer
  SELECT user_id INTO v_user_id FROM lecturers WHERE id = p_lecturer_id;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Lecturer record not found');
  END IF;
  
  -- Track if any changes were made
  v_changes_made := false;
  
  -- Update user table if name provided
  IF p_name IS NOT NULL THEN
    -- Check if name is actually different
    SELECT (p_name != name) INTO v_user_changes
    FROM users 
    WHERE id = v_user_id;
    
    IF v_user_changes THEN
      UPDATE users
      SET 
        name = p_name,
        updated_at = NOW()
      WHERE id = v_user_id;
      
      v_changes_made := true;
    END IF;
  END IF;
  
  -- Update lecturer table with provided information
  SELECT 
    (p_department IS NOT NULL AND p_department != department) OR
    (p_occupation IS NOT NULL AND p_occupation != occupation) OR
    (p_employment_type IS NOT NULL AND p_employment_type != employment_type) OR
    (p_gender IS NOT NULL AND p_gender != gender) OR
    (p_profile_image_path IS NOT NULL AND p_profile_image_path != profile_image_path)
  INTO v_lecturer_changes
  FROM lecturers
  WHERE id = p_lecturer_id;
  
  IF v_lecturer_changes THEN
    UPDATE lecturers
    SET 
      department = COALESCE(p_department, department),
      occupation = COALESCE(p_occupation, occupation),
      employment_type = COALESCE(p_employment_type, employment_type),
      gender = COALESCE(p_gender, gender),
      profile_image_path = COALESCE(p_profile_image_path, profile_image_path),
      updated_at = NOW()
    WHERE id = p_lecturer_id;
    
    v_changes_made := true;
  END IF;
  
  -- Only proceed if changes were actually made
  IF NOT v_changes_made THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'No changes detected'
    );
  END IF;
  
  -- Retrieve updated information
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name
  ) INTO v_updated_user
  FROM users u
  WHERE u.id = v_user_id;
  
  SELECT jsonb_build_object(
    'lecturer_id', l.id,
    'department', l.department,
    'occupation', l.occupation,
    'employment_type', l.employment_type,
    'gender', l.gender,
    'profile_image_path', l.profile_image_path
  ) INTO v_updated_lecturer
  FROM lecturers l
  WHERE l.id = p_lecturer_id;
  
  v_result = jsonb_build_object(
    'success', true,
    'message', 'Profile updated successfully',
    'user', v_updated_user,
    'lecturer', v_updated_lecturer
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refresh lecturer dashboard data
CREATE OR REPLACE FUNCTION refresh_lecturer_dashboard_data(p_lecturer_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'lecturer_id', l.id,
    'department', l.department,
    'occupation', l.occupation,
    'employment_type', l.employment_type,
    'gender', l.gender,
    'profile_image_path', l.profile_image_path
  ) INTO v_result
  FROM users u
  JOIN lecturers l ON u.id = l.user_id
  WHERE l.id = p_lecturer_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Create policies for lecturer profile updates
DROP POLICY IF EXISTS "Lecturers can update their own profile" ON lecturers;
CREATE POLICY "Lecturers can update their own profile"
ON lecturers
FOR UPDATE
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
);

-- Create policies for lecturer data access
DROP POLICY IF EXISTS "Lecturers can view their own data" ON lecturers;
CREATE POLICY "Lecturers can view their own data"
ON lecturers
FOR SELECT
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
);

-- Enable RLS on lecturers table if not already enabled
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY; 

-- Create lecturer_assigned_units table if not exists
CREATE TABLE IF NOT EXISTS lecturer_assigned_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  lecturer_email TEXT NOT NULL,
  unit_code TEXT NOT NULL,
  unit_name TEXT NOT NULL,
  department TEXT NOT NULL,
  course_name TEXT NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(lecturer_id, unit_code)
);

-- Insert sample departments if they don't exist
INSERT INTO departments (name) 
VALUES ('Computer Science'), ('Software Engineering')
ON CONFLICT (name) DO NOTHING;

-- Insert sample courses for Computer Science
INSERT INTO courses (name, department_id)
SELECT 'Computer Science', d.id
FROM departments d
WHERE d.name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert sample courses for Software Engineering
INSERT INTO courses (name, department_id)
SELECT 'Software Engineering', d.id
FROM departments d
WHERE d.name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert sample units for Computer Science
INSERT INTO units (code, name, course_id) VALUES
-- Computer Science Units
('CS111', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS112', 'Computer Organization', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS121', 'Data Structures and Algorithms', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS122', 'Discrete Mathematics', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS211', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS212', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS221', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS222', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS311', 'Software Engineering', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS312', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS321', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS322', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS411', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS412', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS421', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS422', 'Project Management', (SELECT id FROM courses WHERE name = 'Computer Science')),

-- Civil Engineering Units
('CE111', 'Engineering Mathematics I', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE112', 'Engineering Drawing', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE121', 'Engineering Mathematics II', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE122', 'Structural Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE211', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE212', 'Construction Materials', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE221', 'Soil Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE222', 'Surveying', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE311', 'Structural Analysis', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE312', 'Transportation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE321', 'Foundation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE322', 'Environmental Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE411', 'Construction Management', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE412', 'Steel Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE421', 'Concrete Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE422', 'Highway Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),

-- Business Administration Units
('BA111', 'Principles of Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA112', 'Business Mathematics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA121', 'Financial Accounting', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA122', 'Business Communication', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA211', 'Marketing Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA212', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA221', 'Business Law', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA222', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA311', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA312', 'International Business', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA321', 'Entrepreneurship', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA322', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA411', 'Project Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA412', 'Risk Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA421', 'Business Analytics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA422', 'Digital Business', (SELECT id FROM courses WHERE name = 'Business Administration')),

-- Math/Bio Units
('MB111', 'Calculus I', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB112', 'General Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB121', 'Calculus II', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB122', 'Cell Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB211', 'Linear Algebra', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB212', 'Genetics', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB221', 'Differential Equations', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB222', 'Molecular Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB311', 'Statistics', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB312', 'Ecology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB321', 'Complex Analysis', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB322', 'Evolution', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB411', 'Abstract Algebra', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB412', 'Biotechnology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB421', 'Number Theory', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB422', 'Bioinformatics', (SELECT id FROM courses WHERE name = 'Math/bio'))
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    updated_at = NOW();

-- Insert sample units for Software Engineering
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('SE101', 'Software Development Fundamentals', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE102', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE103', 'Software Design Patterns', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 2
  ('SE201', 'Software Requirements Engineering', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE202', 'Software Testing', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE203', 'Agile Development', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 3
  ('SE301', 'Software Project Management', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE302', 'DevOps Practices', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE303', 'Enterprise Software Architecture', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 4
  ('SE401', 'Software Quality Assurance', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE402', 'Microservices Architecture', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE403', 'Software Maintenance', (SELECT id FROM courses WHERE name = 'Software Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample units for Software Engineering
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('SE101', 'Software Development Fundamentals', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE102', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 2
  ('SE201', 'Thermodynamics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE202', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 3
  ('SE301', 'Solid Mechanics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE302', 'Dynamics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 4
  ('SE401', 'Engineering Design', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE402', 'Control Systems', (SELECT id FROM courses WHERE name = 'Software Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Business units for Business Administration course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('BUS101', 'Principles of Marketing', (SELECT id FROM courses WHERE name = 'Business Administration')),
  ('BUS102', 'Corporate Finance', (SELECT id FROM courses WHERE name = 'Finance')),
  
  -- Year 2
  ('BUS201', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Finance')),
  ('BUS202', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 3
  ('BUS301', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS302', 'International Business', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 4
  ('BUS401', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS402', 'Management Accounting', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS403', 'Marketing', (SELECT id FROM courses WHERE name = 'Business'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Education units for education courses
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ART101', 'World History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART102', 'English Literature', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART103', 'Philosophical Thought', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 2
  ('ART201', 'Art History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART202', 'Cultural Studies', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART203', 'Creative Writing', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 3
  ('ART301', 'Performing Arts', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART302', 'Educational Psychology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART303', 'Curriculum Development', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 4
  ('ART401', 'Teaching Methods', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART402', 'Educational Technology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART403', 'Classroom Management', (SELECT id FROM courses WHERE name = 'kiswa/hisory'))
ON CONFLICT (code) DO NOTHING;

-- Create function to get units by course (replacing get_units_by_department)
CREATE OR REPLACE FUNCTION get_units_by_course(p_course_id UUID)
RETURNS SETOF units AS $$
BEGIN
  RETURN QUERY SELECT * FROM units WHERE units.course_id = $1 ORDER BY code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get units by course for cascade dropdowns (JSON format)
CREATE OR REPLACE FUNCTION get_course_units(p_course_id UUID)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_agg(row_to_json(u))
  FROM (
    SELECT id, code, name
    FROM units
    WHERE course_id = p_course_id
    ORDER BY code
  ) u INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get student signup data with cascade dropdown structure
CREATE OR REPLACE FUNCTION get_student_signup_data_cascade()
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'departments', (
      SELECT json_agg(
        json_build_object(
          'id', d.id, 
          'name', d.name,
          'courses', (
            SELECT json_agg(
              json_build_object(
                'id', c.id,
                'name', c.name
              )
            )
            FROM courses c
            WHERE c.department_id = d.id
          )
        )
      )
      FROM departments d
    ),
    'academic_years', (
      SELECT json_agg(row_to_json(y)) 
      FROM (SELECT id, year FROM academic_years ORDER BY year) y
    ),
    'semesters', (
      SELECT json_agg(row_to_json(s)) 
      FROM (SELECT id, name FROM semesters ORDER BY name) s
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Add after the existing triggers and functions

-- Function to update student profile with improved handling of all fields
CREATE OR REPLACE FUNCTION update_student_profile(
  p_student_id UUID,
  p_name TEXT DEFAULT NULL,
  p_department TEXT DEFAULT NULL,
  p_course TEXT DEFAULT NULL,
  p_year TEXT DEFAULT NULL,
  p_semester TEXT DEFAULT NULL,
  p_password TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_updated_user JSONB;
  v_updated_student JSONB;
  v_changes_made BOOLEAN;
  v_user_changes BOOLEAN;
  v_student_changes BOOLEAN;
BEGIN
  -- Get the user_id associated with the student
  SELECT user_id INTO v_user_id FROM students WHERE id = p_student_id;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Student record not found');
  END IF;
  
  -- Track if any changes were made
  v_changes_made := false;
  
  -- Update user table if name or password provided
  IF p_name IS NOT NULL OR p_password IS NOT NULL THEN
    -- Check if name or password is actually different
    SELECT 
      (p_name IS NOT NULL AND p_name != name) OR 
      (p_password IS NOT NULL AND p_password != password)
    INTO v_user_changes
    FROM users 
    WHERE id = v_user_id;
    
    IF v_user_changes THEN
    UPDATE users
    SET 
      name = COALESCE(p_name, name),
      password = COALESCE(p_password, password),
      updated_at = NOW()
    WHERE id = v_user_id;
      
      v_changes_made := true;
    END IF;
  END IF;
  
  -- Update student table with academic information
  SELECT 
    (p_department IS NOT NULL AND p_department != department) OR
    (p_course IS NOT NULL AND p_course != course) OR
    (p_year IS NOT NULL AND p_year != year) OR
    (p_semester IS NOT NULL AND p_semester != semester)
  INTO v_student_changes
  FROM students
  WHERE id = p_student_id;
  
  IF v_student_changes THEN
  UPDATE students
  SET 
    department = COALESCE(p_department, department),
    course = COALESCE(p_course, course),
    year = COALESCE(p_year, year),
    semester = COALESCE(p_semester, semester),
    updated_at = NOW()
  WHERE id = p_student_id;
    
    v_changes_made := true;
  END IF;
  
  -- Only proceed if changes were actually made
  IF NOT v_changes_made THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'No changes detected'
    );
  END IF;
  
  -- Retrieve updated information
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'password', u.password
  ) INTO v_updated_user
  FROM users u
  WHERE u.id = v_user_id;
  
  SELECT jsonb_build_object(
    'student_id', s.id,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path
  ) INTO v_updated_student
  FROM students s
  WHERE s.id = p_student_id;
  
  v_result = jsonb_build_object(
    'success', true,
    'message', 'Profile updated successfully',
    'user', v_updated_user,
    'student', v_updated_student
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a more permissive update policy for students table
DROP POLICY IF EXISTS "Students can update their own academic information" ON students;
CREATE POLICY "Students can update their own academic information"
ON students
FOR UPDATE
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = students.user_id
    AND users.id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = students.user_id
    AND users.id = auth.uid()
  )
);

-- Create function to refresh dashboard data after profile update
CREATE OR REPLACE FUNCTION refresh_student_dashboard_data(p_student_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'student_id', s.id,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path,
    'current_location', s.current_location
  ) INTO v_result
  FROM users u
  JOIN students s ON u.id = s.user_id
  WHERE s.id = p_student_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Function to update lecturer profile
CREATE OR REPLACE FUNCTION update_lecturer_profile(
  p_lecturer_id UUID,
  p_name TEXT DEFAULT NULL,
  p_department TEXT DEFAULT NULL,
  p_occupation TEXT DEFAULT NULL,
  p_employment_type TEXT DEFAULT NULL,
  p_gender TEXT DEFAULT NULL,
  p_profile_image_path TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_updated_user JSONB;
  v_updated_lecturer JSONB;
  v_changes_made BOOLEAN;
  v_user_changes BOOLEAN;
  v_lecturer_changes BOOLEAN;
BEGIN
  -- Get the user_id associated with the lecturer
  SELECT user_id INTO v_user_id FROM lecturers WHERE id = p_lecturer_id;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Lecturer record not found');
  END IF;
  
  -- Track if any changes were made
  v_changes_made := false;
  
  -- Update user table if name provided
  IF p_name IS NOT NULL THEN
    -- Check if name is actually different
    SELECT (p_name != name) INTO v_user_changes
    FROM users 
    WHERE id = v_user_id;
    
    IF v_user_changes THEN
      UPDATE users
      SET 
        name = p_name,
        updated_at = NOW()
      WHERE id = v_user_id;
      
      v_changes_made := true;
    END IF;
  END IF;
  
  -- Update lecturer table with provided information
  SELECT 
    (p_department IS NOT NULL AND p_department != department) OR
    (p_occupation IS NOT NULL AND p_occupation != occupation) OR
    (p_employment_type IS NOT NULL AND p_employment_type != employment_type) OR
    (p_gender IS NOT NULL AND p_gender != gender) OR
    (p_profile_image_path IS NOT NULL AND p_profile_image_path != profile_image_path)
  INTO v_lecturer_changes
  FROM lecturers
  WHERE id = p_lecturer_id;
  
  IF v_lecturer_changes THEN
    UPDATE lecturers
    SET 
      department = COALESCE(p_department, department),
      occupation = COALESCE(p_occupation, occupation),
      employment_type = COALESCE(p_employment_type, employment_type),
      gender = COALESCE(p_gender, gender),
      profile_image_path = COALESCE(p_profile_image_path, profile_image_path),
      updated_at = NOW()
    WHERE id = p_lecturer_id;
    
    v_changes_made := true;
  END IF;
  
  -- Only proceed if changes were actually made
  IF NOT v_changes_made THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'No changes detected'
    );
  END IF;
  
  -- Retrieve updated information
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name
  ) INTO v_updated_user
  FROM users u
  WHERE u.id = v_user_id;
  
  SELECT jsonb_build_object(
    'lecturer_id', l.id,
    'department', l.department,
    'occupation', l.occupation,
    'employment_type', l.employment_type,
    'gender', l.gender,
    'profile_image_path', l.profile_image_path
  ) INTO v_updated_lecturer
  FROM lecturers l
  WHERE l.id = p_lecturer_id;
  
  v_result = jsonb_build_object(
    'success', true,
    'message', 'Profile updated successfully',
    'user', v_updated_user,
    'lecturer', v_updated_lecturer
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refresh lecturer dashboard data
CREATE OR REPLACE FUNCTION refresh_lecturer_dashboard_data(p_lecturer_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'lecturer_id', l.id,
    'department', l.department,
    'occupation', l.occupation,
    'employment_type', l.employment_type,
    'gender', l.gender,
    'profile_image_path', l.profile_image_path
  ) INTO v_result
  FROM users u
  JOIN lecturers l ON u.id = l.user_id
  WHERE l.id = p_lecturer_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Create policies for lecturer profile updates
DROP POLICY IF EXISTS "Lecturers can update their own profile" ON lecturers;
CREATE POLICY "Lecturers can update their own profile"
ON lecturers
FOR UPDATE
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
);

-- Create policies for lecturer data access
DROP POLICY IF EXISTS "Lecturers can view their own data" ON lecturers;
CREATE POLICY "Lecturers can view their own data"
ON lecturers
FOR SELECT
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
);

-- Enable RLS on lecturers table if not already enabled
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY; 

-- Create lecturer_assigned_units table if not exists
CREATE TABLE IF NOT EXISTS lecturer_assigned_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  lecturer_email TEXT NOT NULL,
  unit_code TEXT NOT NULL,
  unit_name TEXT NOT NULL,
  department TEXT NOT NULL,
  course_name TEXT NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(lecturer_id, unit_code)
);

-- Insert sample departments if they don't exist
INSERT INTO departments (name) 
VALUES ('Computer Science'), ('Software Engineering')
ON CONFLICT (name) DO NOTHING;

-- Insert sample courses for Computer Science
INSERT INTO courses (name, department_id)
SELECT 'Computer Science', d.id
FROM departments d
WHERE d.name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert sample courses for Software Engineering
INSERT INTO courses (name, department_id)
SELECT 'Software Engineering', d.id
FROM departments d
WHERE d.name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert sample units for Computer Science
INSERT INTO units (code, name, course_id) VALUES
-- Computer Science Units
('CS111', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS112', 'Computer Organization', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS121', 'Data Structures and Algorithms', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS122', 'Discrete Mathematics', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS211', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS212', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS221', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS222', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS311', 'Software Engineering', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS312', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS321', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS322', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS411', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS412', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS421', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS422', 'Project Management', (SELECT id FROM courses WHERE name = 'Computer Science')),

-- Civil Engineering Units
('CE111', 'Engineering Mathematics I', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE112', 'Engineering Drawing', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE121', 'Engineering Mathematics II', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE122', 'Structural Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE211', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE212', 'Construction Materials', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE221', 'Soil Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE222', 'Surveying', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE311', 'Structural Analysis', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE312', 'Transportation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE321', 'Foundation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE322', 'Environmental Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE411', 'Construction Management', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE412', 'Steel Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE421', 'Concrete Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE422', 'Highway Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),

-- Business Administration Units
('BA111', 'Principles of Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA112', 'Business Mathematics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA121', 'Financial Accounting', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA122', 'Business Communication', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA211', 'Marketing Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA212', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA221', 'Business Law', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA222', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA311', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA312', 'International Business', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA321', 'Entrepreneurship', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA322', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA411', 'Project Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA412', 'Risk Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA421', 'Business Analytics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA422', 'Digital Business', (SELECT id FROM courses WHERE name = 'Business Administration')),

-- Math/Bio Units
('MB111', 'Calculus I', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB112', 'General Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB121', 'Calculus II', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB122', 'Cell Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB211', 'Linear Algebra', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB212', 'Genetics', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB221', 'Differential Equations', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB222', 'Molecular Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB311', 'Statistics', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB312', 'Ecology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB321', 'Complex Analysis', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB322', 'Evolution', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB411', 'Abstract Algebra', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB412', 'Biotechnology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB421', 'Number Theory', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB422', 'Bioinformatics', (SELECT id FROM courses WHERE name = 'Math/bio'))
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    updated_at = NOW();

-- Insert sample units for Software Engineering
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('SE101', 'Software Development Fundamentals', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE102', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE103', 'Software Design Patterns', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 2
  ('SE201', 'Software Requirements Engineering', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE202', 'Software Testing', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE203', 'Agile Development', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 3
  ('SE301', 'Software Project Management', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE302', 'DevOps Practices', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE303', 'Enterprise Software Architecture', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 4
  ('SE401', 'Software Quality Assurance', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE402', 'Microservices Architecture', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE403', 'Software Maintenance', (SELECT id FROM courses WHERE name = 'Software Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample units for Software Engineering
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('SE101', 'Software Development Fundamentals', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE102', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 2
  ('SE201', 'Thermodynamics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE202', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 3
  ('SE301', 'Solid Mechanics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE302', 'Dynamics', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 4
  ('SE401', 'Engineering Design', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE402', 'Control Systems', (SELECT id FROM courses WHERE name = 'Software Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Business units for Business Administration course
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('BUS101', 'Principles of Marketing', (SELECT id FROM courses WHERE name = 'Business Administration')),
  ('BUS102', 'Corporate Finance', (SELECT id FROM courses WHERE name = 'Finance')),
  
  -- Year 2
  ('BUS201', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Finance')),
  ('BUS202', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 3
  ('BUS301', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS302', 'International Business', (SELECT id FROM courses WHERE name = 'Business')),
  
  -- Year 4
  ('BUS401', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS402', 'Management Accounting', (SELECT id FROM courses WHERE name = 'Business')),
  ('BUS403', 'Marketing', (SELECT id FROM courses WHERE name = 'Business'))
ON CONFLICT (code) DO NOTHING;

-- Insert sample Education units for education courses
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('ART101', 'World History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART102', 'English Literature', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART103', 'Philosophical Thought', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 2
  ('ART201', 'Art History', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART202', 'Cultural Studies', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART203', 'Creative Writing', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 3
  ('ART301', 'Performing Arts', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART302', 'Educational Psychology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART303', 'Curriculum Development', (SELECT id FROM courses WHERE name = 'kiswa/hisory')),
  
  -- Year 4
  ('ART401', 'Teaching Methods', (SELECT id FROM courses WHERE name = 'Math/bio')),
  ('ART402', 'Educational Technology', (SELECT id FROM courses WHERE name = 'phys/chem')),
  ('ART403', 'Classroom Management', (SELECT id FROM courses WHERE name = 'kiswa/hisory'))
ON CONFLICT (code) DO NOTHING;

-- Create function to get units by course (replacing get_units_by_department)
CREATE OR REPLACE FUNCTION get_units_by_course(p_course_id UUID)
RETURNS SETOF units AS $$
BEGIN
  RETURN QUERY SELECT * FROM units WHERE units.course_id = $1 ORDER BY code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get units by course for cascade dropdowns (JSON format)
CREATE OR REPLACE FUNCTION get_course_units(p_course_id UUID)
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_agg(row_to_json(u))
  FROM (
    SELECT id, code, name
    FROM units
    WHERE course_id = p_course_id
    ORDER BY code
  ) u INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get student signup data with cascade dropdown structure
CREATE OR REPLACE FUNCTION get_student_signup_data_cascade()
RETURNS json AS $$
DECLARE
  result json;
BEGIN
  SELECT json_build_object(
    'departments', (
      SELECT json_agg(
        json_build_object(
          'id', d.id, 
          'name', d.name,
          'courses', (
            SELECT json_agg(
              json_build_object(
                'id', c.id,
                'name', c.name
              )
            )
            FROM courses c
            WHERE c.department_id = d.id
          )
        )
      )
      FROM departments d
    ),
    'academic_years', (
      SELECT json_agg(row_to_json(y)) 
      FROM (SELECT id, year FROM academic_years ORDER BY year) y
    ),
    'semesters', (
      SELECT json_agg(row_to_json(s)) 
      FROM (SELECT id, name FROM semesters ORDER BY name) s
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Add after the existing triggers and functions

-- Function to update student profile with improved handling of all fields
CREATE OR REPLACE FUNCTION update_student_profile(
  p_student_id UUID,
  p_name TEXT DEFAULT NULL,
  p_department TEXT DEFAULT NULL,
  p_course TEXT DEFAULT NULL,
  p_year TEXT DEFAULT NULL,
  p_semester TEXT DEFAULT NULL,
  p_password TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_updated_user JSONB;
  v_updated_student JSONB;
  v_changes_made BOOLEAN;
  v_user_changes BOOLEAN;
  v_student_changes BOOLEAN;
BEGIN
  -- Get the user_id associated with the student
  SELECT user_id INTO v_user_id FROM students WHERE id = p_student_id;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Student record not found');
  END IF;
  
  -- Track if any changes were made
  v_changes_made := false;
  
  -- Update user table if name or password provided
  IF p_name IS NOT NULL OR p_password IS NOT NULL THEN
    -- Check if name or password is actually different
    SELECT 
      (p_name IS NOT NULL AND p_name != name) OR 
      (p_password IS NOT NULL AND p_password != password)
    INTO v_user_changes
    FROM users 
    WHERE id = v_user_id;
    
    IF v_user_changes THEN
    UPDATE users
    SET 
      name = COALESCE(p_name, name),
      password = COALESCE(p_password, password),
      updated_at = NOW()
    WHERE id = v_user_id;
      
      v_changes_made := true;
    END IF;
  END IF;
  
  -- Update student table with academic information
  SELECT 
    (p_department IS NOT NULL AND p_department != department) OR
    (p_course IS NOT NULL AND p_course != course) OR
    (p_year IS NOT NULL AND p_year != year) OR
    (p_semester IS NOT NULL AND p_semester != semester)
  INTO v_student_changes
  FROM students
  WHERE id = p_student_id;
  
  IF v_student_changes THEN
  UPDATE students
  SET 
    department = COALESCE(p_department, department),
    course = COALESCE(p_course, course),
    year = COALESCE(p_year, year),
    semester = COALESCE(p_semester, semester),
    updated_at = NOW()
  WHERE id = p_student_id;
    
    v_changes_made := true;
  END IF;
  
  -- Only proceed if changes were actually made
  IF NOT v_changes_made THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'No changes detected'
    );
  END IF;
  
  -- Retrieve updated information
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'password', u.password
  ) INTO v_updated_user
  FROM users u
  WHERE u.id = v_user_id;
  
  SELECT jsonb_build_object(
    'student_id', s.id,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path
  ) INTO v_updated_student
  FROM students s
  WHERE s.id = p_student_id;
  
  v_result = jsonb_build_object(
    'success', true,
    'message', 'Profile updated successfully',
    'user', v_updated_user,
    'student', v_updated_student
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a more permissive update policy for students table
DROP POLICY IF EXISTS "Students can update their own academic information" ON students;
CREATE POLICY "Students can update their own academic information"
ON students
FOR UPDATE
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = students.user_id
    AND users.id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = students.user_id
    AND users.id = auth.uid()
  )
);

-- Create function to refresh dashboard data after profile update
CREATE OR REPLACE FUNCTION refresh_student_dashboard_data(p_student_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'student_id', s.id,
    'department', s.department,
    'course', s.course,
    'year', s.year,
    'semester', s.semester,
    'profile_image_path', s.profile_image_path,
    'current_location', s.current_location
  ) INTO v_result
  FROM users u
  JOIN students s ON u.id = s.user_id
  WHERE s.id = p_student_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Function to update lecturer profile
CREATE OR REPLACE FUNCTION update_lecturer_profile(
  p_lecturer_id UUID,
  p_name TEXT DEFAULT NULL,
  p_department TEXT DEFAULT NULL,
  p_occupation TEXT DEFAULT NULL,
  p_employment_type TEXT DEFAULT NULL,
  p_gender TEXT DEFAULT NULL,
  p_profile_image_path TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_result JSONB;
  v_updated_user JSONB;
  v_updated_lecturer JSONB;
  v_changes_made BOOLEAN;
  v_user_changes BOOLEAN;
  v_lecturer_changes BOOLEAN;
BEGIN
  -- Get the user_id associated with the lecturer
  SELECT user_id INTO v_user_id FROM lecturers WHERE id = p_lecturer_id;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Lecturer record not found');
  END IF;
  
  -- Track if any changes were made
  v_changes_made := false;
  
  -- Update user table if name provided
  IF p_name IS NOT NULL THEN
    -- Check if name is actually different
    SELECT (p_name != name) INTO v_user_changes
    FROM users 
    WHERE id = v_user_id;
    
    IF v_user_changes THEN
      UPDATE users
      SET 
        name = p_name,
        updated_at = NOW()
      WHERE id = v_user_id;
      
      v_changes_made := true;
    END IF;
  END IF;
  
  -- Update lecturer table with provided information
  SELECT 
    (p_department IS NOT NULL AND p_department != department) OR
    (p_occupation IS NOT NULL AND p_occupation != occupation) OR
    (p_employment_type IS NOT NULL AND p_employment_type != employment_type) OR
    (p_gender IS NOT NULL AND p_gender != gender) OR
    (p_profile_image_path IS NOT NULL AND p_profile_image_path != profile_image_path)
  INTO v_lecturer_changes
  FROM lecturers
  WHERE id = p_lecturer_id;
  
  IF v_lecturer_changes THEN
    UPDATE lecturers
    SET 
      department = COALESCE(p_department, department),
      occupation = COALESCE(p_occupation, occupation),
      employment_type = COALESCE(p_employment_type, employment_type),
      gender = COALESCE(p_gender, gender),
      profile_image_path = COALESCE(p_profile_image_path, profile_image_path),
      updated_at = NOW()
    WHERE id = p_lecturer_id;
    
    v_changes_made := true;
  END IF;
  
  -- Only proceed if changes were actually made
  IF NOT v_changes_made THEN
    RETURN jsonb_build_object(
      'success', false, 
      'message', 'No changes detected'
    );
  END IF;
  
  -- Retrieve updated information
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name
  ) INTO v_updated_user
  FROM users u
  WHERE u.id = v_user_id;
  
  SELECT jsonb_build_object(
    'lecturer_id', l.id,
    'department', l.department,
    'occupation', l.occupation,
    'employment_type', l.employment_type,
    'gender', l.gender,
    'profile_image_path', l.profile_image_path
  ) INTO v_updated_lecturer
  FROM lecturers l
  WHERE l.id = p_lecturer_id;
  
  v_result = jsonb_build_object(
    'success', true,
    'message', 'Profile updated successfully',
    'user', v_updated_user,
    'lecturer', v_updated_lecturer
  );
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refresh lecturer dashboard data
CREATE OR REPLACE FUNCTION refresh_lecturer_dashboard_data(p_lecturer_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', u.name,
    'lecturer_id', l.id,
    'department', l.department,
    'occupation', l.occupation,
    'employment_type', l.employment_type,
    'gender', l.gender,
    'profile_image_path', l.profile_image_path
  ) INTO v_result
  FROM users u
  JOIN lecturers l ON u.id = l.user_id
  WHERE l.id = p_lecturer_id;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 

-- Create policies for lecturer profile updates
DROP POLICY IF EXISTS "Lecturers can update their own profile" ON lecturers;
CREATE POLICY "Lecturers can update their own profile"
ON lecturers
FOR UPDATE
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
)
WITH CHECK (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
);

-- Create policies for lecturer data access
DROP POLICY IF EXISTS "Lecturers can view their own data" ON lecturers;
CREATE POLICY "Lecturers can view their own data"
ON lecturers
FOR SELECT
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = lecturers.user_id
    AND users.id = auth.uid()
  )
);

-- Enable RLS on lecturers table if not already enabled
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY; 

-- Create lecturer_assigned_units table if not exists
CREATE TABLE IF NOT EXISTS lecturer_assigned_units (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
  lecturer_email TEXT NOT NULL,
  unit_code TEXT NOT NULL,
  unit_name TEXT NOT NULL,
  department TEXT NOT NULL,
  course_name TEXT NOT NULL,
  year TEXT NOT NULL,
  semester TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(lecturer_id, unit_code)
);

-- Insert sample departments if they don't exist
INSERT INTO departments (name) 
VALUES ('Computer Science'), ('Software Engineering')
ON CONFLICT (name) DO NOTHING;

-- Insert sample courses for Computer Science
INSERT INTO courses (name, department_id)
SELECT 'Computer Science', d.id
FROM departments d
WHERE d.name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert sample courses for Software Engineering
INSERT INTO courses (name, department_id)
SELECT 'Software Engineering', d.id
FROM departments d
WHERE d.name = 'Computer Science'
ON CONFLICT (name, department_id) DO NOTHING;

-- Insert sample units for Computer Science
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('CS111', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS112', 'Computer Organization', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS121', 'Data Structures and Algorithms', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS122', 'Discrete Mathematics', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 2
  ('CS211', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS212', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS221', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS222', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 3
  ('CS311', 'Software Engineering', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS312', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS321', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS322', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
  
  -- Year 4
  ('CS411', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS412', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS421', 'Project Management', (SELECT id FROM courses WHERE name = 'Computer Science')),
  ('CS422', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science'))
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    updated_at = NOW();

-- Insert sample units for Software Engineering
INSERT INTO units (code, name, course_id)
VALUES 
  -- Year 1
  ('SE101', 'Software Development Fundamentals', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE102', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE103', 'Software Design Patterns', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 2
  ('SE201', 'Software Requirements Engineering', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE202', 'Software Testing', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE203', 'Agile Development', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 3
  ('SE301', 'Software Project Management', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE302', 'DevOps Practices', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE303', 'Enterprise Software Architecture', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  
  -- Year 4
  ('SE401', 'Software Quality Assurance', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE402', 'Microservices Architecture', (SELECT id FROM courses WHERE name = 'Software Engineering')),
  ('SE403', 'Software Maintenance', (SELECT id FROM courses WHERE name = 'Software Engineering'))
ON CONFLICT (code) DO NOTHING;

-- Enable RLS on all tables
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE semesters ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE lecturer_assigned_units ENABLE ROW LEVEL SECURITY;

-- Create policies for departments
CREATE POLICY "Public can view departments"
ON departments FOR SELECT
TO public
USING (true);

-- Create policies for courses
CREATE POLICY "Public can view courses"
ON courses FOR SELECT
TO public
USING (true);

-- Create policies for units
CREATE POLICY "Public can view units"
ON units FOR SELECT
TO public
USING (true);

-- Create policies for lecturer_assigned_units
CREATE POLICY "Lecturers can view their assigned units"
ON lecturer_assigned_units FOR SELECT
TO authenticated
USING (
    lecturer_email IN (
        SELECT email 
        FROM users 
        WHERE id = auth.uid()
    )
);

CREATE POLICY "Lecturers can assign units to themselves"
ON lecturer_assigned_units FOR INSERT
WITH CHECK (
    lecturer_email IN (
        SELECT email 
        FROM users 
        WHERE id = auth.uid()
    )
);

CREATE POLICY "Lecturers can update their assigned units"
ON lecturer_assigned_units FOR UPDATE
USING (
    lecturer_email IN (
        SELECT email 
        FROM users 
        WHERE id = auth.uid()
    )
);

CREATE POLICY "Lecturers can delete their assigned units"
ON lecturer_assigned_units FOR DELETE
USING (
    lecturer_email IN (
        SELECT email 
        FROM users 
        WHERE id = auth.uid()
    )
); 
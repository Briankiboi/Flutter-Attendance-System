-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_lecturer_signup();

-- Create users table if not exists (for local auth)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password TEXT NOT NULL,
  user_type TEXT NOT NULL DEFAULT 'lecturer',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Recreate the function with proper error handling
CREATE OR REPLACE FUNCTION handle_lecturer_signup()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Create user record first
  INSERT INTO users (
    id,
    email,
    name,
    password,
    user_type
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.raw_user_meta_data->>'password',
    'lecturer'
  ) RETURNING id INTO v_user_id;

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
    v_user_id,
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
    RAISE NOTICE 'Error in handle_lecturer_signup: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  WHEN (NEW.raw_user_meta_data->>'user_type' = 'lecturer')
  EXECUTE FUNCTION handle_lecturer_signup();

-- Make sure RLS is enabled but with proper policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies first
DROP POLICY IF EXISTS "Allow anonymous lecturer creation" ON lecturers;
DROP POLICY IF EXISTS "Lecturers can view their own profile" ON lecturers;
DROP POLICY IF EXISTS "Lecturers can update their own profile" ON lecturers;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON lecturers;
DROP POLICY IF EXISTS "Allow lecturer read access" ON lecturers;
DROP POLICY IF EXISTS "Allow lecturer update" ON lecturers;
DROP POLICY IF EXISTS "Allow lecturer delete" ON lecturers;
DROP POLICY IF EXISTS "Allow anonymous access to users" ON users;

-- Create new policies for users table
CREATE POLICY "Allow anonymous access to users"
ON users FOR ALL USING (true);

-- Create new policies for lecturers table
CREATE POLICY "Allow anonymous lecturer creation"
ON lecturers FOR INSERT
WITH CHECK (true);

CREATE POLICY "Allow lecturer read access"
ON lecturers FOR SELECT
USING (true);

CREATE POLICY "Allow lecturer update"
ON lecturers FOR UPDATE
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow lecturer delete"
ON lecturers FOR DELETE
USING (true);

-- Function to verify lecturer login
CREATE OR REPLACE FUNCTION verify_lecturer_login(p_email TEXT, p_password TEXT)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  user_data JSON
) AS $$
DECLARE
  v_user_record RECORD;
  v_lecturer_record RECORD;
BEGIN
  -- Check if email exists and password matches
  SELECT * INTO v_user_record
  FROM users
  WHERE email = p_email 
  AND password = p_password
  AND user_type = 'lecturer';

  IF v_user_record IS NULL THEN
    RETURN QUERY SELECT 
      false AS success,
      'Invalid credentials' AS message,
      NULL::JSON AS user_data;
    RETURN;
  END IF;

  -- Get lecturer details
  SELECT * INTO v_lecturer_record
  FROM lecturers
  WHERE user_id = v_user_record.id;

  IF v_lecturer_record IS NULL THEN
    RETURN QUERY SELECT 
      false AS success,
      'Lecturer profile not found' AS message,
      NULL::JSON AS user_data;
    RETURN;
  END IF;

  -- Return success with user data
  RETURN QUERY SELECT 
    true AS success,
    'Login successful' AS message,
    json_build_object(
      'id', v_user_record.id,
      'email', v_user_record.email,
      'name', v_user_record.name,
      'department', v_lecturer_record.department,
      'occupation', v_lecturer_record.occupation,
      'employmentType', v_lecturer_record.employment_type,
      'gender', v_lecturer_record.gender,
      'profile_image_path', v_lecturer_record.profile_image_path,
      'lecturer_id', v_lecturer_record.id,
      'user_type', 'lecturer'
    ) AS user_data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
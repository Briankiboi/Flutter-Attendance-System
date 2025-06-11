-- Drop existing trigger first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop existing function
DROP FUNCTION IF EXISTS handle_lecturer_signup();

-- Recreate the function with proper error handling and table structure
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

-- Recreate the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  WHEN (NEW.raw_user_meta_data->>'user_type' = 'lecturer')
  EXECUTE FUNCTION handle_lecturer_signup();

-- Make sure RLS is enabled but with proper policies
ALTER TABLE lecturers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to clean up
DROP POLICY IF EXISTS "Allow anonymous lecturer creation" ON lecturers;
DROP POLICY IF EXISTS "Lecturers can view their own profile" ON lecturers;
DROP POLICY IF EXISTS "Lecturers can update their own profile" ON lecturers;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON lecturers;

-- Create new policies
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
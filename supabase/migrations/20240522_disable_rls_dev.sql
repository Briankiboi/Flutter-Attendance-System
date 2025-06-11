-- First, drop all existing policies
DROP POLICY IF EXISTS "Lecturers can view their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can create messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can update their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can delete their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Enable all operations for lecturers" ON schedule_messages;
DROP POLICY IF EXISTS "Enable student read access" ON schedule_messages;
DROP POLICY IF EXISTS "Allow all during development" ON schedule_messages;

-- Disable RLS completely
ALTER TABLE schedule_messages DISABLE ROW LEVEL SECURITY;

-- Grant full permissions
GRANT ALL ON schedule_messages TO authenticated;
GRANT ALL ON schedule_messages TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon; 
-- Create attendance table
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES attendance_sessions(id),
    student_id UUID REFERENCES students(id),
    server_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    device_timestamp TIMESTAMP WITH TIME ZONE,
    mark_method TEXT CHECK (mark_method IN ('QR_CODE', 'BACKUP_KEY')),
    status TEXT CHECK (status IN ('PRESENT', 'LATE', 'ABSENT')),
    location_data JSONB,
    is_time_synced BOOLEAN,
    verification_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(session_id, student_id)
);

-- Add new columns to attendance table if they don't exist
ALTER TABLE attendance
ADD COLUMN IF NOT EXISTS status TEXT CHECK (status IN ('Present', 'Late', 'Absent')) DEFAULT 'Present',
ADD COLUMN IF NOT EXISTS location_name TEXT,
ADD COLUMN IF NOT EXISTS attendance_method TEXT CHECK (attendance_method IN ('QR', 'Key')) DEFAULT 'QR',
ADD COLUMN IF NOT EXISTS device_info JSONB DEFAULT '{}'::jsonb;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_attendance_session ON attendance(session_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_status ON attendance(status);
CREATE INDEX IF NOT EXISTS idx_attendance_marked_at ON attendance(marked_at);

-- Function to check if student is eligible for attendance
CREATE OR REPLACE FUNCTION check_student_eligibility(
  p_student_id UUID,
  p_session_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_unit_id UUID;
BEGIN
  -- Get unit_id from session
  SELECT unit_id INTO v_unit_id
  FROM attendance_sessions
  WHERE id = p_session_id;

  -- Check if student is enrolled in the unit
  RETURN EXISTS (
    SELECT 1 
    FROM student_unit_enrollments sue
    WHERE sue.student_id = p_student_id
    AND sue.unit_id = v_unit_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark attendance
CREATE OR REPLACE FUNCTION mark_attendance(
  p_student_id UUID,
  p_session_id UUID,
  p_location_name TEXT,
  p_attendance_method TEXT DEFAULT 'QR',
  p_device_info JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) AS $$
DECLARE
  v_session_record attendance_sessions%ROWTYPE;
  v_status TEXT;
BEGIN
  -- Get session details
  SELECT * INTO v_session_record
  FROM attendance_sessions
  WHERE id = p_session_id;

  -- Check if session exists and is active
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Session not found';
    RETURN;
  END IF;

  IF NOT v_session_record.is_active THEN
    RETURN QUERY SELECT false, 'Session is not active';
    RETURN;
  END IF;

  -- Check student eligibility
  IF NOT check_student_eligibility(p_student_id, p_session_id) THEN
    RETURN QUERY SELECT false, 'Student not enrolled in this unit';
    RETURN;
  END IF;

  -- Check for duplicate attendance
  IF EXISTS (
    SELECT 1 FROM attendance
    WHERE session_id = p_session_id
    AND student_id = p_student_id
  ) THEN
    RETURN QUERY SELECT false, 'Attendance already marked';
    RETURN;
  END IF;

  -- Determine attendance status based on time
  v_status := CASE 
    WHEN NOW() <= v_session_record.start_time + INTERVAL '15 minutes' THEN 'Present'
    WHEN NOW() <= v_session_record.end_time THEN 'Late'
    ELSE 'Absent'
  END;

  -- Insert attendance record
  INSERT INTO attendance (
    session_id,
    student_id,
    marked_at,
    status,
    location_name,
    attendance_method,
    device_info
  ) VALUES (
    p_session_id,
    p_student_id,
    NOW(),
    v_status,
    p_location_name,
    p_attendance_method,
    p_device_info
  );

  RETURN QUERY SELECT true, 'Attendance marked successfully: ' || v_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate backup key for a session
CREATE OR REPLACE FUNCTION generate_session_backup_key(
  p_session_id UUID
) RETURNS TEXT AS $$
DECLARE
  v_key TEXT;
BEGIN
  -- Generate a 6-character alphanumeric key
  v_key := UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));
  
  -- Update the session with the backup key
  UPDATE attendance_sessions
  SET session_data = COALESCE(session_data, '{}'::jsonb) || jsonb_build_object('backup_key', v_key)
  WHERE id = p_session_id
  AND lecturer_id = (
    SELECT id FROM lecturers WHERE user_id = auth.uid()
  );

  RETURN v_key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify backup key and mark attendance
CREATE OR REPLACE FUNCTION mark_attendance_with_key(
  p_student_id UUID,
  p_session_id UUID,
  p_backup_key TEXT,
  p_location_name TEXT,
  p_device_info JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) AS $$
DECLARE
  v_stored_key TEXT;
BEGIN
  -- Get stored backup key
  SELECT (session_data->>'backup_key')::TEXT INTO v_stored_key
  FROM attendance_sessions
  WHERE id = p_session_id;

  -- Verify backup key
  IF v_stored_key IS NULL OR v_stored_key != UPPER(p_backup_key) THEN
    RETURN QUERY SELECT false, 'Invalid backup key';
    RETURN;
  END IF;

  -- Mark attendance using the main function
  RETURN QUERY
  SELECT * FROM mark_attendance(p_student_id, p_session_id, p_location_name, 'Key', p_device_info);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- Students can view their own attendance
CREATE POLICY IF NOT EXISTS "Students can view their own attendance"
ON attendance FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM students
    WHERE students.id = attendance.student_id
    AND students.user_id = auth.uid()
  )
);

-- Lecturers can view attendance for their sessions
CREATE POLICY IF NOT EXISTS "Lecturers can view attendance for their sessions"
ON attendance FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM attendance_sessions
    WHERE attendance_sessions.id = attendance.session_id
    AND attendance_sessions.lecturer_id IN (
      SELECT id FROM lecturers WHERE user_id = auth.uid()
    )
  )
);

-- Create view for active sessions with attendance stats
CREATE OR REPLACE VIEW active_sessions_with_stats AS
SELECT 
  s.*,
  COUNT(DISTINCT a.student_id) as attendance_count,
  COUNT(DISTINCT CASE WHEN a.status = 'Present' THEN a.student_id END) as present_count,
  COUNT(DISTINCT CASE WHEN a.status = 'Late' THEN a.student_id END) as late_count
FROM attendance_sessions s
LEFT JOIN attendance a ON s.id = a.session_id
WHERE s.is_active = true
GROUP BY s.id; 
-- Create attendance_sessions table
CREATE TABLE attendance_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lecturer_id UUID REFERENCES lecturers(id),
    unit_id UUID REFERENCES units(id),
    qr_code_url TEXT,
    qr_code_data JSONB,
    backup_key TEXT,
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    session_data JSONB,
    location TEXT,
    coordinates JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create attendance table
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES attendance_sessions(id),
    student_id UUID REFERENCES students(id),
    server_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    device_timestamp TIMESTAMP WITH TIME ZONE,
    mark_method TEXT CHECK (mark_method IN ('QR_CODE', 'BACKUP_KEY')),
    status TEXT CHECK (status IN ('PRESENT', 'LATE', 'ABSENT')),
    location JSONB,
    is_time_synced BOOLEAN,
    verification_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_attendance_sessions_lecturer ON attendance_sessions(lecturer_id);
CREATE INDEX idx_attendance_sessions_unit ON attendance_sessions(unit_id);
CREATE INDEX idx_attendance_sessions_active ON attendance_sessions(is_active);
CREATE INDEX idx_attendance_student ON attendance(student_id);
CREATE INDEX idx_attendance_session ON attendance(session_id);
CREATE INDEX idx_attendance_status ON attendance(status);

-- Create function to check overlapping sessions
CREATE OR REPLACE FUNCTION check_overlapping_sessions(
    p_student_id UUID,
    p_session_id UUID,
    p_start_time TIMESTAMP WITH TIME ZONE,
    p_end_time TIMESTAMP WITH TIME ZONE
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM attendance_sessions s
        JOIN attendance a ON a.session_id = s.id
        WHERE a.student_id = p_student_id
        AND s.id != p_session_id
        AND s.is_active = true
        AND (
            (s.start_time, s.end_time) OVERLAPS (p_start_time, p_end_time)
        )
    );
END;
$$ LANGUAGE plpgsql;

-- Create function to mark attendance
CREATE OR REPLACE FUNCTION mark_attendance(
    p_session_id UUID,
    p_student_id UUID,
    p_device_timestamp TIMESTAMP WITH TIME ZONE,
    p_mark_method TEXT,
    p_location JSONB,
    p_verification_data JSONB
) RETURNS JSONB AS $$
DECLARE
    v_session attendance_sessions;
    v_status TEXT;
    v_time_diff INTEGER;
BEGIN
    -- Get session details
    SELECT * INTO v_session
    FROM attendance_sessions
    WHERE id = p_session_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid or inactive session'
        );
    END IF;

    -- Check if attendance already marked
    IF EXISTS (
        SELECT 1 FROM attendance
        WHERE session_id = p_session_id AND student_id = p_student_id
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Attendance already marked'
        );
    END IF;

    -- Check for overlapping sessions
    IF check_overlapping_sessions(
        p_student_id,
        p_session_id,
        v_session.start_time,
        v_session.end_time
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'You have another active class session'
        );
    END IF;

    -- Determine attendance status
    v_time_diff := EXTRACT(EPOCH FROM (NOW() - v_session.start_time))/60;
    v_status := CASE
        WHEN v_time_diff <= 15 THEN 'PRESENT'
        ELSE 'LATE'
    END;

    -- Insert attendance record
    INSERT INTO attendance (
        session_id,
        student_id,
        device_timestamp,
        mark_method,
        status,
        location,
        is_time_synced,
        verification_data
    ) VALUES (
        p_session_id,
        p_student_id,
        p_device_timestamp,
        p_mark_method,
        v_status,
        p_location,
        (abs(EXTRACT(EPOCH FROM (NOW() - p_device_timestamp))) <= 120), -- within 2 minutes
        p_verification_data
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Attendance marked successfully',
        'status', v_status
    );
END;
$$ LANGUAGE plpgsql; 
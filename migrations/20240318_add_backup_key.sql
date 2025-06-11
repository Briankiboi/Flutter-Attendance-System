-- Add backup_key column to attendance_sessions if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'attendance_sessions' 
        AND column_name = 'backup_key'
    ) THEN
        ALTER TABLE attendance_sessions 
        ADD COLUMN backup_key TEXT;
    END IF;
END $$;

-- Update any existing NULL backup_key values with a generated key
DO $$
BEGIN
    UPDATE attendance_sessions 
    SET backup_key = 'LEGACY_' || id::text
    WHERE backup_key IS NULL;

    -- Then make the column NOT NULL
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'attendance_sessions' 
        AND column_name = 'backup_key'
        AND is_nullable = 'YES'
    ) THEN
        ALTER TABLE attendance_sessions
        ALTER COLUMN backup_key SET NOT NULL;
    END IF;
END $$;

-- Add index for faster backup key lookups
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE tablename = 'attendance_sessions'
        AND indexname = 'idx_attendance_sessions_backup_key'
    ) THEN
        CREATE INDEX idx_attendance_sessions_backup_key 
        ON attendance_sessions(backup_key);
    END IF;
END $$;

-- Add function to check for active sessions
CREATE OR REPLACE FUNCTION check_active_sessions(
    p_unit_code TEXT,
    p_start_time TIMESTAMP WITH TIME ZONE,
    p_end_time TIMESTAMP WITH TIME ZONE
) RETURNS TABLE (
    has_conflict BOOLEAN,
    conflict_details JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH active_session AS (
        SELECT 
            id,
            unit_id,
            start_time,
            end_time,
            session_data->>'unit_name' as unit_name
        FROM attendance_sessions
        WHERE is_active = true
        AND end_time > NOW()
        AND unit_id = (SELECT id FROM units WHERE code = p_unit_code)
        AND (
            (start_time, end_time) OVERLAPS (p_start_time, p_end_time)
        )
        LIMIT 1
    )
    SELECT 
        CASE WHEN COUNT(*) > 0 THEN true ELSE false END as has_conflict,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                jsonb_build_object(
                    'session_id', id,
                    'unit_name', unit_name,
                    'start_time', start_time,
                    'end_time', end_time
                )
            ELSE NULL
        END as conflict_details
    FROM active_session;
END;
$$ LANGUAGE plpgsql;

-- Add function to validate backup key
CREATE OR REPLACE FUNCTION validate_backup_key(
    p_session_id UUID,
    p_backup_key TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM attendance_sessions 
        WHERE id = p_session_id 
        AND backup_key = p_backup_key
        AND is_active = true
        AND end_time > NOW()
    );
END;
$$ LANGUAGE plpgsql;

-- Add function to mark attendance using backup key
CREATE OR REPLACE FUNCTION mark_attendance_with_backup_key(
    p_student_id UUID,
    p_session_id UUID,
    p_backup_key TEXT
) RETURNS JSONB AS $$
DECLARE
    v_is_valid BOOLEAN;
    v_already_marked BOOLEAN;
BEGIN
    -- First validate the backup key
    SELECT validate_backup_key(p_session_id, p_backup_key) INTO v_is_valid;
    
    IF NOT v_is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid or expired backup key'
        );
    END IF;
    
    -- Check if attendance already marked
    SELECT EXISTS (
        SELECT 1 
        FROM attendance 
        WHERE session_id = p_session_id 
        AND student_id = p_student_id
    ) INTO v_already_marked;
    
    IF v_already_marked THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Attendance already marked'
        );
    END IF;
    
    -- Mark attendance
    INSERT INTO attendance (
        session_id,
        student_id,
        time_scanned,
        created_at,
        updated_at
    ) VALUES (
        p_session_id,
        p_student_id,
        NOW(),
        NOW(),
        NOW()
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Attendance marked successfully using backup key'
    );
END;
$$ LANGUAGE plpgsql; 
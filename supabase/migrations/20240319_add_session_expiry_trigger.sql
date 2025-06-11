-- Add comment header for documentation
/*
 * Session Management Migration
 * Purpose: Manages attendance session states automatically
 * Compatible with: Supabase Free Tier
 * Features:
 * - Automatic session state management
 * - Performance indexes
 * - Cleanup function for Edge Functions
 * - Security measures for production use
 */

-- Create necessary indexes for performance
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_active ON attendance_sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_time ON attendance_sessions(start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_composite ON attendance_sessions(is_active, start_time, end_time);

-- Function to update session status based on start_time and end_time
CREATE OR REPLACE FUNCTION update_session_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Set initial status based on time windows using UTC time
    IF NEW.start_time > (NOW() AT TIME ZONE 'UTC') THEN
        -- Session hasn't started yet
        NEW.is_active = false;
    ELSIF NEW.end_time < (NOW() AT TIME ZONE 'UTC') THEN
        -- Session has ended
        NEW.is_active = false;
    ELSE
        -- Session is currently active (between start and end time)
        NEW.is_active = true;
    END IF;
    
    -- Update the updated_at timestamp
    NEW.updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update session status
DROP TRIGGER IF EXISTS session_expiry_trigger ON attendance_sessions;
CREATE TRIGGER session_expiry_trigger
    BEFORE INSERT OR UPDATE ON attendance_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_session_status();

-- Update existing sessions based on their time windows
UPDATE attendance_sessions
SET is_active = 
    CASE 
        WHEN start_time > (NOW() AT TIME ZONE 'UTC') THEN false  -- Future sessions
        WHEN end_time < (NOW() AT TIME ZONE 'UTC') THEN false    -- Past sessions
        ELSE true                           -- Current sessions
    END,
    updated_at = NOW()
WHERE is_active != 
    CASE 
        WHEN start_time > (NOW() AT TIME ZONE 'UTC') THEN false
        WHEN end_time < (NOW() AT TIME ZONE 'UTC') THEN false
        ELSE true
    END;

-- Create function that can be called by Supabase Edge Functions or HTTP requests
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS json AS $$
DECLARE
    updated_count INTEGER;
    start_time TIMESTAMP;
BEGIN
    -- Record start time for performance monitoring
    start_time := clock_timestamp();

    -- Update sessions with proper status
    WITH updated_rows AS (
        UPDATE attendance_sessions
        SET is_active = 
            CASE 
                WHEN start_time > (NOW() AT TIME ZONE 'UTC') THEN false  -- Future sessions
                WHEN end_time < (NOW() AT TIME ZONE 'UTC') THEN false    -- Past sessions
                ELSE true                           -- Current sessions
            END,
            updated_at = NOW()
        WHERE is_active != 
            CASE 
                WHEN start_time > (NOW() AT TIME ZONE 'UTC') THEN false
                WHEN end_time < (NOW() AT TIME ZONE 'UTC') THEN false
                ELSE true
            END
        RETURNING id
    )
    SELECT COUNT(*) INTO updated_count FROM updated_rows;

    -- Return detailed execution information
    RETURN json_build_object(
        'success', true,
        'updated_sessions', updated_count,
        'execution_time_ms', EXTRACT(MILLISECONDS FROM clock_timestamp() - start_time)::INTEGER,
        'executed_at', NOW() AT TIME ZONE 'UTC',
        'details', json_build_object(
            'active_sessions', (SELECT COUNT(*) FROM attendance_sessions WHERE is_active = true),
            'inactive_sessions', (SELECT COUNT(*) FROM attendance_sessions WHERE is_active = false)
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Revoke public access and grant only to service role
REVOKE EXECUTE ON FUNCTION cleanup_expired_sessions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cleanup_expired_sessions() TO service_role;

-- Add helpful comment for future reference
COMMENT ON FUNCTION cleanup_expired_sessions() IS 
'Automatically manages session states based on time windows. 
Call this function from Edge Functions or scheduled tasks to maintain session states.
Returns JSON with execution details and statistics.
Security: Only accessible by service_role.';

-- Function to manually update session status
CREATE OR REPLACE FUNCTION update_session_status_manual(session_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE attendance_sessions
    SET is_active = 
        CASE 
            WHEN start_time > (NOW() AT TIME ZONE 'UTC') THEN false  -- Future sessions
            WHEN end_time < (NOW() AT TIME ZONE 'UTC') THEN false    -- Past sessions
            ELSE true                           -- Current sessions
        END,
        updated_at = NOW()
    WHERE id = session_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql; 
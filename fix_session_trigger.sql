-- Non-destructive update to fix UTC time comparison in session trigger
DO $OUTER$ 
BEGIN
    -- Drop existing trigger first
    DROP TRIGGER IF EXISTS session_expiry_trigger ON attendance_sessions;
    
    -- Update the function without dropping it (preserves permissions)
    CREATE OR REPLACE FUNCTION update_session_status()
    RETURNS TRIGGER AS $FUNCTION$
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
    $FUNCTION$ LANGUAGE plpgsql;

    -- Recreate the trigger
    CREATE TRIGGER session_expiry_trigger
        BEFORE INSERT OR UPDATE ON attendance_sessions
        FOR EACH ROW
        EXECUTE FUNCTION update_session_status();

    -- Update existing sessions to correct state (only updates if needed)
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
END $OUTER$; 
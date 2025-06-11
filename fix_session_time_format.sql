-- Non-destructive update to fix time format and UTC comparison
DO $OUTER$ 
BEGIN
    -- First create a function to convert display time to proper timestamp
    CREATE OR REPLACE FUNCTION convert_display_time_to_timestamp(
        p_time TEXT,
        p_date TEXT
    ) RETURNS TIMESTAMP WITH TIME ZONE AS $FUNCTION$
    DECLARE
        v_date DATE;
        v_time TIME;
        v_timestamp TIMESTAMP WITH TIME ZONE;
    BEGIN
        IF p_time IS NULL OR p_date IS NULL THEN
            RETURN NULL;
        END IF;

        -- First convert the date string to a proper DATE
        BEGIN
            -- Try DD/MM/YYYY format first
            v_date := TO_DATE(p_date, 'DD/MM/YYYY');
        EXCEPTION WHEN OTHERS THEN
            BEGIN
                -- Try YYYY-MM-DD format as fallback
                v_date := TO_DATE(p_date, 'YYYY-MM-DD');
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Invalid date format: %', p_date;
                RETURN NULL;
            END;
        END;

        -- Convert time string to TIME
        BEGIN
            v_time := TO_TIMESTAMP(p_time, 'HH24:MI')::TIME;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Invalid time format: %', p_time;
            RETURN NULL;
        END;

        -- Combine date and time into timestamp
        v_timestamp := (v_date::TEXT || ' ' || v_time::TEXT)::TIMESTAMP;
        
        -- Convert to UTC
        RETURN v_timestamp AT TIME ZONE 'UTC';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error in convert_display_time_to_timestamp: %, %, %', p_time, p_date, SQLERRM;
        RETURN NULL;
    END;
    $FUNCTION$ LANGUAGE plpgsql;

    -- Update the session status function to handle both formats
    CREATE OR REPLACE FUNCTION update_session_status()
    RETURNS TRIGGER AS $FUNCTION$
    DECLARE
        v_start_timestamp TIMESTAMP WITH TIME ZONE;
        v_end_timestamp TIMESTAMP WITH TIME ZONE;
        v_current_time TIMESTAMP WITH TIME ZONE;
    BEGIN
        -- Get current UTC time
        v_current_time := NOW() AT TIME ZONE 'UTC';
        
        -- Initialize with existing values
        NEW.start_time := COALESCE(NEW.start_time, OLD.start_time);
        NEW.end_time := COALESCE(NEW.end_time, OLD.end_time);
        NEW.is_active := COALESCE(NEW.is_active, false);

        -- Convert display format times to timestamps if needed
        IF NEW.session_data IS NOT NULL 
           AND NEW.session_data->>'start_time' IS NOT NULL 
           AND NEW.session_data->>'display_date' IS NOT NULL THEN
            
            v_start_timestamp := convert_display_time_to_timestamp(
                NEW.session_data->>'start_time',
                NEW.session_data->>'display_date'
            );
            v_end_timestamp := convert_display_time_to_timestamp(
                NEW.session_data->>'end_time',
                NEW.session_data->>'display_date'
            );
            
            -- Only update timestamps if conversion was successful
            IF v_start_timestamp IS NOT NULL AND v_end_timestamp IS NOT NULL THEN
                NEW.start_time := v_start_timestamp;
                NEW.end_time := v_end_timestamp;
                
                RAISE NOTICE 'Converted times - Start: %, End: %, Current: %', 
                    v_start_timestamp, 
                    v_end_timestamp,
                    v_current_time;
            END IF;
        END IF;

        -- Set active status based on UTC time comparison
        IF NEW.start_time IS NULL OR NEW.end_time IS NULL THEN
            NEW.is_active := false;
            RAISE NOTICE 'Setting inactive - NULL times';
        ELSIF v_current_time >= NEW.start_time AND v_current_time <= NEW.end_time THEN
            NEW.is_active := true;
            RAISE NOTICE 'Setting active - Current time is within session window';
        ELSE
            NEW.is_active := false;
            RAISE NOTICE 'Setting inactive - Current time outside session window';
        END IF;
        
        RETURN NEW;
    END;
    $FUNCTION$ LANGUAGE plpgsql;

    -- Recreate the trigger
    DROP TRIGGER IF EXISTS session_expiry_trigger ON attendance_sessions;
    CREATE TRIGGER session_expiry_trigger
        BEFORE INSERT OR UPDATE ON attendance_sessions
        FOR EACH ROW
        EXECUTE FUNCTION update_session_status();

    -- Update all sessions to recalculate their status
    UPDATE attendance_sessions a
    SET updated_at = NOW()
    WHERE session_data IS NOT NULL;

END $OUTER$;

-- Verify the results (run this as a separate statement)
SELECT 
    id,
    start_time,
    end_time,
    NOW() AT TIME ZONE 'UTC' as current_time,
    is_active,
    session_data->>'display_date' as display_date,
    session_data->>'start_time' as display_start_time,
    session_data->>'end_time' as display_end_time,
    CASE 
        WHEN start_time <= NOW() AT TIME ZONE 'UTC' 
        AND end_time >= NOW() AT TIME ZONE 'UTC' THEN 'SHOULD BE ACTIVE'
        ELSE 'SHOULD BE INACTIVE'
    END as expected_status
FROM attendance_sessions
WHERE session_data IS NOT NULL
ORDER BY start_time DESC; 
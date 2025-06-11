-- Enable the pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a function to update all session statuses
CREATE OR REPLACE FUNCTION update_all_session_statuses()
RETURNS void AS $$
BEGIN
    -- Update all sessions to trigger the status update
    UPDATE attendance_sessions
    SET updated_at = NOW()
    WHERE session_data IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Schedule the function to run every minute
SELECT cron.schedule(
    'update-session-statuses',  -- unique schedule name
    '* * * * *',               -- every minute (cron expression)
    'SELECT update_all_session_statuses()'
);

-- To remove the schedule if needed (commented out by default):
-- SELECT cron.unschedule('update-session-statuses'); 
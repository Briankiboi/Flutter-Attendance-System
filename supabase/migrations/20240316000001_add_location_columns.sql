 -- Add location columns to attendance_sessions table
-- Using IF NOT EXISTS to make it safe and idempotent
DO $$ 
BEGIN
    -- Add class_latitude if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'attendance_sessions' 
        AND column_name = 'class_latitude'
    ) THEN
        ALTER TABLE attendance_sessions 
        ADD COLUMN class_latitude DECIMAL(10, 8) NULL;
    END IF;

    -- Add class_longitude if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'attendance_sessions' 
        AND column_name = 'class_longitude'
    ) THEN
        ALTER TABLE attendance_sessions 
        ADD COLUMN class_longitude DECIMAL(11, 8) NULL;
    END IF;

    -- Add radius_meters if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'attendance_sessions' 
        AND column_name = 'radius_meters'
    ) THEN
        ALTER TABLE attendance_sessions 
        ADD COLUMN radius_meters INTEGER DEFAULT 100;
    END IF;

    -- Add location_required if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'attendance_sessions' 
        AND column_name = 'location_required'
    ) THEN
        ALTER TABLE attendance_sessions 
        ADD COLUMN location_required BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Add index for faster location queries
-- Using IF NOT EXISTS to make it safe
CREATE INDEX IF NOT EXISTS idx_attendance_location 
ON attendance_sessions(class_latitude, class_longitude) 
WHERE class_latitude IS NOT NULL AND class_longitude IS NOT NULL;

-- Add comment to explain the columns
COMMENT ON COLUMN attendance_sessions.class_latitude IS 'Latitude of the class location';
COMMENT ON COLUMN attendance_sessions.class_longitude IS 'Longitude of the class location';
COMMENT ON COLUMN attendance_sessions.radius_meters IS 'Allowed radius in meters from class location';
COMMENT ON COLUMN attendance_sessions.location_required IS 'Whether location verification is required for this session'; 
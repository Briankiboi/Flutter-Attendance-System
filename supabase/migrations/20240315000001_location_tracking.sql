-- Enable PostGIS extension for accurate distance calculations
CREATE EXTENSION IF NOT EXISTS postgis;

-- Drop existing function if exists to avoid conflicts
DROP FUNCTION IF EXISTS verify_student_location;

-- Create student_location_history table if not exists
CREATE TABLE IF NOT EXISTS student_location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id),
    session_id UUID REFERENCES attendance_sessions(id),
    location_point geometry(Point, 4326),
    accuracy DOUBLE PRECISION,
    location_name TEXT,
    device_timestamp TIMESTAMP WITH TIME ZONE,
    server_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT false,
    verification_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_location_student;
DROP INDEX IF EXISTS idx_location_session;
DROP INDEX IF EXISTS idx_location_timestamp;
DROP INDEX IF EXISTS idx_location_point;

-- Create indexes for location queries
CREATE INDEX idx_location_student ON student_location_history(student_id);
CREATE INDEX idx_location_session ON student_location_history(session_id);
CREATE INDEX idx_location_timestamp ON student_location_history(server_timestamp);
CREATE INDEX idx_location_point ON student_location_history USING GIST(location_point);

-- Create function to verify student location
CREATE OR REPLACE FUNCTION verify_student_location(
    p_student_id UUID,
    p_session_id UUID,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_max_distance_meters DOUBLE PRECISION DEFAULT 50.0
) RETURNS TABLE (
    is_within_range BOOLEAN,
    distance_meters DOUBLE PRECISION,
    location_name TEXT
) AS $$
DECLARE
    v_session_location geometry;
    v_student_location geometry;
BEGIN
    -- Get session location
    SELECT ST_SetSRID(ST_MakePoint(
        (coordinates->>'longitude')::float,
        (coordinates->>'latitude')::float
    ), 4326)
    INTO v_session_location
    FROM attendance_sessions
    WHERE id = p_session_id;

    -- Create student location point
    v_student_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);

    -- Calculate distance in meters
    RETURN QUERY
    SELECT 
        ST_DWithin(
            v_session_location::geography,
            v_student_location::geography,
            p_max_distance_meters
        ) as is_within_range,
        ST_Distance(
            v_session_location::geography,
            v_student_location::geography
        )::DOUBLE PRECISION as distance_meters,
        COALESCE(
            (SELECT location FROM attendance_sessions WHERE id = p_session_id),
            'Unknown Location'
        ) as location_name;
END;
$$ LANGUAGE plpgsql; 
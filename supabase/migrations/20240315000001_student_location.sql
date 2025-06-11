-- Create student_location_history table
CREATE TABLE student_location_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id),
    session_id UUID REFERENCES attendance_sessions(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    location_name TEXT,
    device_timestamp TIMESTAMP WITH TIME ZONE,
    server_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT false,
    verification_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for location queries
CREATE INDEX idx_location_student ON student_location_history(student_id);
CREATE INDEX idx_location_session ON student_location_history(session_id);
CREATE INDEX idx_location_timestamp ON student_location_history(server_timestamp);

-- Create function to verify student location
CREATE OR REPLACE FUNCTION verify_student_location(
    p_student_id UUID,
    p_session_id UUID,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_max_distance DOUBLE PRECISION DEFAULT 50.0 -- 50 meters default
) RETURNS BOOLEAN AS $$
DECLARE
    v_session_location JSONB;
    v_distance DOUBLE PRECISION;
BEGIN
    -- Get session location
    SELECT coordinates INTO v_session_location
    FROM attendance_sessions
    WHERE id = p_session_id;

    -- Calculate distance using PostgreSQL's built-in earth distance functions
    SELECT earth_distance(
        ll_to_earth(p_latitude, p_longitude),
        ll_to_earth(
            (v_session_location->>'latitude')::float,
            (v_session_location->>'longitude')::float
        )
    ) INTO v_distance;

    -- Return true if within max distance
    RETURN v_distance <= p_max_distance;
END;
$$ LANGUAGE plpgsql; 
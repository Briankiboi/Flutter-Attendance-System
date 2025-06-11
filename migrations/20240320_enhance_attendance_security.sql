-- Safe migration script that adds security and location tracking
-- This script is non-destructive and preserves existing data

-- 1. Create session settings table (separate from attendance_sessions)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'session_security_settings') THEN
        CREATE TABLE session_security_settings (
            session_id UUID PRIMARY KEY REFERENCES attendance_sessions(id),
            allowed_radius_meters INTEGER DEFAULT 50,
            allow_multiple_devices BOOLEAN DEFAULT false,
            min_app_version TEXT DEFAULT '1.0.0',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    END IF;
END $$;

-- 2. Add location tracking columns
DO $$ 
BEGIN
    -- Add student location columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'student_latitude') THEN
        ALTER TABLE attendance ADD COLUMN student_latitude DECIMAL(10, 8);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'student_longitude') THEN
        ALTER TABLE attendance ADD COLUMN student_longitude DECIMAL(11, 8);
    END IF;

    -- Add distance calculation
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'distance_from_class') THEN
        ALTER TABLE attendance ADD COLUMN distance_from_class DOUBLE PRECISION;
    END IF;

    -- Add location verification
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'is_within_radius') THEN
        ALTER TABLE attendance ADD COLUMN is_within_radius BOOLEAN DEFAULT false;
    END IF;

    -- Add location accuracy
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'location_accuracy') THEN
        ALTER TABLE attendance ADD COLUMN location_accuracy DOUBLE PRECISION;
    END IF;
END $$;

-- 3. Add enhanced device security columns
DO $$ 
BEGIN
    -- Enhanced device tracking
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'device_id') THEN
        ALTER TABLE attendance ADD COLUMN device_id TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'device_model') THEN
        ALTER TABLE attendance ADD COLUMN device_model TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'platform') THEN
        ALTER TABLE attendance ADD COLUMN platform TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'os_version') THEN
        ALTER TABLE attendance ADD COLUMN os_version TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'is_mock_location') THEN
        ALTER TABLE attendance ADD COLUMN is_mock_location BOOLEAN DEFAULT false;
    END IF;

    -- Network information
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'network_info') THEN
        ALTER TABLE attendance ADD COLUMN network_info JSONB DEFAULT '{}'::jsonb;
    END IF;

    -- App information
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'app_version') THEN
        ALTER TABLE attendance ADD COLUMN app_version TEXT;
    END IF;
END $$;

-- 4. Add verification status columns
DO $$ 
BEGIN
    -- Add verification status if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'verification_status') THEN
        ALTER TABLE attendance ADD COLUMN verification_status TEXT 
        CHECK (verification_status IN (
            'VERIFIED',
            'LOCATION_MISMATCH',
            'MOCK_LOCATION_DETECTED',
            'DEVICE_MISMATCH',
            'TIME_MISMATCH',
            'NETWORK_ISSUE',
            'OUTSIDE_RADIUS',
            'MULTIPLE_DEVICE_ATTEMPT',
            'INVALID_APP_VERSION'
        ));
    END IF;

    -- Add verification timestamp
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'attendance' AND column_name = 'verified_at') THEN
        ALTER TABLE attendance ADD COLUMN verified_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- 5. Create function to calculate distance between two points using Haversine formula
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
DECLARE
    R DOUBLE PRECISION := 6371000; -- Earth's radius in meters
    φ1 DOUBLE PRECISION := lat1 * pi()/180;
    φ2 DOUBLE PRECISION := lat2 * pi()/180;
    Δφ DOUBLE PRECISION := (lat2-lat1) * pi()/180;
    Δλ DOUBLE PRECISION := (lon2-lon1) * pi()/180;
    a DOUBLE PRECISION;
    c DOUBLE PRECISION;
    d DOUBLE PRECISION;
BEGIN
    -- Haversine formula for accurate Earth-surface distance
    a := sin(Δφ/2) * sin(Δφ/2) +
         cos(φ1) * cos(φ2) *
         sin(Δλ/2) * sin(Δλ/2);
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    d := R * c;
    RETURN d;
END;
$$ LANGUAGE plpgsql;

-- 6. Create function to check device usage
CREATE OR REPLACE FUNCTION check_device_usage(
    p_student_id UUID,
    p_device_id TEXT,
    p_session_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_allow_multiple BOOLEAN;
    v_device_count INTEGER;
BEGIN
    -- Get session settings
    SELECT allow_multiple_devices INTO v_allow_multiple
    FROM session_security_settings
    WHERE session_id = p_session_id;

    -- If no settings found or multiple devices are allowed, return true
    IF v_allow_multiple IS NULL OR v_allow_multiple THEN
        RETURN true;
    END IF;

    -- Count different devices used by student
    SELECT COUNT(DISTINCT device_id) INTO v_device_count
    FROM attendance
    WHERE student_id = p_student_id
    AND device_id != p_device_id
    AND marked_at >= NOW() - INTERVAL '24 hours';

    RETURN v_device_count = 0;
END;
$$ LANGUAGE plpgsql;

-- 7. Create enhanced function to verify attendance location
CREATE OR REPLACE FUNCTION verify_attendance_location(
    p_attendance_id UUID
) RETURNS TEXT AS $$
DECLARE
    v_session_lat DECIMAL(10, 8);
    v_session_lon DECIMAL(11, 8);
    v_student_lat DECIMAL(10, 8);
    v_student_lon DECIMAL(11, 8);
    v_allowed_radius INTEGER;
    v_distance DOUBLE PRECISION;
    v_is_mock BOOLEAN;
    v_student_id UUID;
    v_session_id UUID;
    v_device_id TEXT;
    v_device_allowed BOOLEAN;
BEGIN
    -- Get all necessary information
    SELECT 
        s.class_latitude, 
        s.class_longitude,
        COALESCE(ss.allowed_radius_meters, 50), -- Default to 50m if not set
        s.id,
        a.student_latitude,
        a.student_longitude,
        a.is_mock_location,
        a.student_id,
        a.device_id
    INTO 
        v_session_lat, v_session_lon, v_allowed_radius, v_session_id,
        v_student_lat, v_student_lon, v_is_mock, v_student_id, v_device_id
    FROM attendance a
    JOIN attendance_sessions s ON a.session_id = s.id
    LEFT JOIN session_security_settings ss ON s.id = ss.session_id
    WHERE a.id = p_attendance_id;

    -- Check for mock location
    IF v_is_mock THEN
        UPDATE attendance SET
            verification_status = 'MOCK_LOCATION_DETECTED',
            verified_at = NOW()
        WHERE id = p_attendance_id;
        RETURN 'MOCK_LOCATION_DETECTED';
    END IF;

    -- Check device usage
    v_device_allowed := check_device_usage(v_student_id, v_device_id, v_session_id);
    IF NOT v_device_allowed THEN
        UPDATE attendance SET
            verification_status = 'MULTIPLE_DEVICE_ATTEMPT',
            verified_at = NOW()
        WHERE id = p_attendance_id;
        RETURN 'MULTIPLE_DEVICE_ATTEMPT';
    END IF;

    -- Calculate distance using Haversine formula
    v_distance := calculate_distance(
        v_session_lat,
        v_session_lon,
        v_student_lat,
        v_student_lon
    );

    -- Update attendance record with distance and verification
    UPDATE attendance SET
        distance_from_class = v_distance,
        is_within_radius = (v_distance <= v_allowed_radius),
        verification_status = CASE 
            WHEN v_distance <= v_allowed_radius THEN 'VERIFIED'
            ELSE 'OUTSIDE_RADIUS'
        END,
        verified_at = NOW()
    WHERE id = p_attendance_id;

    IF v_distance <= v_allowed_radius THEN
        RETURN 'VERIFIED';
    ELSE
        RETURN 'OUTSIDE_RADIUS';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 8. Create function to verify device authenticity
CREATE OR REPLACE FUNCTION verify_device_authenticity(
    p_attendance_id UUID
) RETURNS TEXT AS $$
DECLARE
    v_device_info JSONB;
    v_is_mock BOOLEAN;
    v_platform TEXT;
    v_app_version TEXT;
    v_min_app_version TEXT;
    v_session_id UUID;
BEGIN
    -- Get device info and session
    SELECT 
        a.network_info,
        a.is_mock_location,
        a.platform,
        a.app_version,
        a.session_id,
        COALESCE(ss.min_app_version, '1.0.0')
    INTO 
        v_device_info,
        v_is_mock,
        v_platform,
        v_app_version,
        v_session_id,
        v_min_app_version
    FROM attendance a
    LEFT JOIN session_security_settings ss ON a.session_id = ss.session_id
    WHERE a.id = p_attendance_id;

    -- Check for mock location
    IF v_is_mock THEN
        RETURN 'MOCK_LOCATION_DETECTED';
    END IF;

    -- Check app version
    IF v_app_version < v_min_app_version THEN
        RETURN 'INVALID_APP_VERSION';
    END IF;

    -- Update verification status
    UPDATE attendance SET
        verification_status = 'VERIFIED',
        verified_at = NOW()
    WHERE id = p_attendance_id;

    RETURN 'VERIFIED';
END;
$$ LANGUAGE plpgsql;

-- 9. Add indexes for performance (with proper existence checks)
DO $$ 
BEGIN
    -- Drop existing indexes if they exist (to avoid conflicts)
    DROP INDEX IF EXISTS idx_attendance_location;
    DROP INDEX IF EXISTS idx_attendance_device;
    DROP INDEX IF EXISTS idx_attendance_verification;
    DROP INDEX IF EXISTS idx_attendance_student_device;

    -- Create new indexes
    CREATE INDEX IF NOT EXISTS idx_attendance_location ON attendance(student_latitude, student_longitude);
    CREATE INDEX IF NOT EXISTS idx_attendance_device ON attendance(device_id);
    CREATE INDEX IF NOT EXISTS idx_attendance_verification ON attendance(verification_status);
    CREATE INDEX IF NOT EXISTS idx_attendance_student_device ON attendance(student_id, device_id);
END $$;

-- 10. Create trigger to auto-update session settings
CREATE OR REPLACE FUNCTION update_session_settings_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    -- Drop trigger if exists
    DROP TRIGGER IF EXISTS trigger_update_session_settings_timestamp ON session_security_settings;
    
    -- Create new trigger
    CREATE TRIGGER trigger_update_session_settings_timestamp
    BEFORE UPDATE ON session_security_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_session_settings_timestamp();
END $$; 
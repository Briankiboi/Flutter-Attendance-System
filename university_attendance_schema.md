# University Attendance System Schema

## Main Attendance Table

```sql
CREATE TABLE university_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Session and Unit Information
    session_id UUID REFERENCES attendance_sessions(id),
    unit_code TEXT NOT NULL,
    unit_name TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    semester INTEGER NOT NULL,
    
    -- Student Information
    student_id UUID REFERENCES students(id),
    student_name TEXT NOT NULL,
    student_email TEXT NOT NULL,
    registration_number TEXT NOT NULL,
    department TEXT NOT NULL,
    course TEXT NOT NULL,
    year_of_study INTEGER NOT NULL,
    
    -- Lecturer Information
    lecturer_id UUID REFERENCES lecturers(id),
    lecturer_name TEXT NOT NULL,
    lecturer_email TEXT NOT NULL,
    
    -- Time Information
    class_date DATE NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    marked_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Location Information
    class_latitude DECIMAL(10, 8),
    class_longitude DECIMAL(11, 8),
    class_radius_meters INTEGER,
    student_latitude DECIMAL(10, 8),
    student_longitude DECIMAL(11, 8),
    distance_from_class DECIMAL(10, 2),
    is_within_radius BOOLEAN,
    location_accuracy_meters DECIMAL(6, 2),
    
    -- Attendance Method
    attendance_method TEXT CHECK (attendance_method IN ('QR_CODE', 'BACKUP_KEY')),
    backup_key TEXT,
    qr_code_data JSONB,
    
    -- Device and Security Information
    device_id TEXT NOT NULL,
    device_model TEXT,
    device_os TEXT,
    device_fingerprint TEXT,
    ip_address TEXT,
    network_info JSONB,
    is_mock_location BOOLEAN DEFAULT false,
    gps_accuracy_meters DECIMAL(6, 2),
    
    -- Status and Verification
    attendance_status TEXT CHECK (attendance_status IN (
        'PENDING',
        'VERIFIED',
        'REJECTED',
        'OUTSIDE_RADIUS',
        'OUTSIDE_TIME_WINDOW',
        'INVALID_LOCATION',
        'MOCK_LOCATION_DETECTED',
        'DEVICE_MISMATCH',
        'SUCCESS'
    )),
    verification_attempts INTEGER DEFAULT 1,
    last_verification_at TIMESTAMPTZ,
    verification_notes TEXT,
    
    -- Timestamps and Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    verified_by UUID REFERENCES staff(id),
    
    -- Constraints
    CONSTRAINT unique_student_session 
        UNIQUE(student_id, session_id),
    CONSTRAINT valid_coordinates 
        CHECK (
            (class_latitude BETWEEN -90 AND 90) AND 
            (class_longitude BETWEEN -180 AND 180) AND
            (student_latitude BETWEEN -90 AND 90) AND 
            (student_longitude BETWEEN -180 AND 180)
        ),
    CONSTRAINT valid_radius
        CHECK (class_radius_meters BETWEEN 1 AND 100),
    CONSTRAINT valid_time_window
        CHECK (end_time > start_time)
);

-- Indexes for performance
CREATE INDEX idx_uni_attendance_session ON university_attendance(session_id);
CREATE INDEX idx_uni_attendance_student ON university_attendance(student_id);
CREATE INDEX idx_uni_attendance_unit ON university_attendance(unit_code);
CREATE INDEX idx_uni_attendance_date ON university_attendance(class_date);
CREATE INDEX idx_uni_attendance_status ON university_attendance(attendance_status);
```

## Automatic Validation Trigger

```sql
-- Function to validate attendance
CREATE OR REPLACE FUNCTION validate_attendance()
RETURNS TRIGGER AS $$
BEGIN
    -- Check time window
    IF NEW.marked_at < NEW.start_time OR NEW.marked_at > NEW.end_time THEN
        NEW.attendance_status = 'OUTSIDE_TIME_WINDOW';
        RETURN NEW;
    END IF;

    -- Check location if required
    IF NEW.class_latitude IS NOT NULL AND NEW.student_latitude IS NOT NULL THEN
        -- Calculate distance using Haversine formula
        WITH distance_calc AS (
            SELECT 
                2 * 6371000 * asin(
                    sqrt(
                        sin(radians(NEW.student_latitude - NEW.class_latitude)/2)^2 +
                        cos(radians(NEW.class_latitude)) * 
                        cos(radians(NEW.student_latitude)) * 
                        sin(radians(NEW.student_longitude - NEW.class_longitude)/2)^2
                    )
                ) AS distance_meters
        )
        SELECT distance_meters INTO NEW.distance_from_class FROM distance_calc;

        IF NEW.distance_from_class > NEW.class_radius_meters THEN
            NEW.attendance_status = 'OUTSIDE_RADIUS';
            RETURN NEW;
        END IF;
    END IF;

    -- Check for mock locations
    IF NEW.is_mock_location THEN
        NEW.attendance_status = 'MOCK_LOCATION_DETECTED';
        RETURN NEW;
    END IF;

    -- All checks passed
    NEW.attendance_status = 'SUCCESS';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_university_attendance
    BEFORE INSERT OR UPDATE ON university_attendance
    FOR EACH ROW
    EXECUTE FUNCTION validate_attendance();
```

## Views for Reports

```sql
-- Student Attendance View
CREATE VIEW student_attendance_view AS
SELECT 
    unit_code,
    unit_name,
    class_date,
    start_time,
    end_time,
    attendance_status,
    attendance_method,
    CASE 
        WHEN attendance_status = 'SUCCESS' THEN 'Present'
        WHEN attendance_status = 'OUTSIDE_RADIUS' THEN 'Too Far from Class'
        WHEN attendance_status = 'OUTSIDE_TIME_WINDOW' THEN 'Late/Early'
        ELSE 'Absent'
    END as attendance_result
FROM university_attendance;

-- Lecturer Summary View
CREATE VIEW lecturer_attendance_summary AS
SELECT 
    unit_code,
    class_date,
    COUNT(*) as total_students,
    SUM(CASE WHEN attendance_status = 'SUCCESS' THEN 1 ELSE 0 END) as present_count,
    SUM(CASE WHEN attendance_status != 'SUCCESS' THEN 1 ELSE 0 END) as absent_count,
    ROUND(AVG(distance_from_class), 2) as avg_distance_meters,
    COUNT(DISTINCT device_id) as unique_devices
FROM university_attendance
GROUP BY unit_code, class_date;
```

## Security Queries

```sql
-- Detect Multiple Devices
CREATE VIEW suspicious_device_usage AS
SELECT 
    student_id,
    student_name,
    COUNT(DISTINCT device_id) as device_count,
    COUNT(DISTINCT ip_address) as ip_count,
    COUNT(*) as total_attempts,
    array_agg(DISTINCT device_model) as devices_used
FROM university_attendance
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY student_id, student_name
HAVING COUNT(DISTINCT device_id) > 1;

-- Monitor Location Accuracy
CREATE VIEW location_accuracy_monitoring AS
SELECT 
    unit_code,
    class_date,
    AVG(gps_accuracy_meters) as avg_gps_accuracy,
    COUNT(*) FILTER (WHERE is_mock_location) as mock_location_attempts,
    COUNT(*) FILTER (WHERE gps_accuracy_meters > 20) as low_accuracy_count
FROM university_attendance
GROUP BY unit_code, class_date;
```

## Usage Example

```typescript
// Record attendance
async function recordAttendance(sessionData, studentLocation) {
    const { data: session } = await supabase
        .from('attendance_sessions')
        .select('*')
        .eq('id', sessionData.session_id)
        .single();

    const deviceInfo = await getDeviceInfo();
    
    const { data, error } = await supabase
        .from('university_attendance')
        .insert({
            session_id: session.id,
            unit_code: session.unit_code,
            unit_name: session.unit_name,
            student_id: studentData.id,
            student_name: studentData.name,
            student_email: studentData.email,
            class_latitude: session.latitude,
            class_longitude: session.longitude,
            class_radius_meters: session.radius_meters,
            student_latitude: studentLocation.latitude,
            student_longitude: studentLocation.longitude,
            device_id: deviceInfo.id,
            device_model: deviceInfo.model,
            attendance_method: 'QR_CODE'
        })
        .select()
        .single();

    return { data, error };
}
``` 
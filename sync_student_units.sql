-- Safe, non-destructive script to create student unit synchronization
-- Similar to lecturer_units pattern

-- First drop existing objects to avoid conflicts
DROP POLICY IF EXISTS "Students can view their registered units" ON student_registered_units;
DROP FUNCTION IF EXISTS sync_student_registrations();
DROP FUNCTION IF EXISTS trigger_sync_student_registrations();
DROP FUNCTION IF EXISTS get_unit_students_for_cat();
DROP TABLE IF EXISTS student_registered_units CASCADE;

-- First create the combined student units view
CREATE OR REPLACE VIEW combined_student_units AS
SELECT DISTINCT
    su.id,
    su.student_id,
    su.unit_id,
    u.code as unit_code,
    u.name as unit_name,
    c.name as course_name,
    d.name as department_name,
    su.year,
    su.semester,
    su.status,
    su.registration_date,
    su.created_at,
    su.updated_at
FROM student_units su
JOIN units u ON u.id = su.unit_id
JOIN courses c ON c.id = u.course_id
JOIN departments d ON d.id = c.department_id;

-- Create student_registered_units table (similar to lecturer_assigned_units)
CREATE TABLE IF NOT EXISTS student_registered_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id),
    unit_id UUID NOT NULL REFERENCES units(id),
    unit_code TEXT NOT NULL,
    unit_name TEXT NOT NULL,
    department TEXT NOT NULL,
    course_name TEXT NOT NULL,
    year TEXT NOT NULL,
    semester TEXT NOT NULL,
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, unit_code, year, semester)
);

-- Enable RLS on the new table
ALTER TABLE student_registered_units ENABLE ROW LEVEL SECURITY;

-- Create policies for student_registered_units
CREATE POLICY "Students can view their registered units"
ON student_registered_units FOR SELECT TO authenticated
USING (
    auth.uid() IN (
        SELECT user_id FROM students WHERE id = student_registered_units.student_id
    )
);

-- Create function to sync student registrations
CREATE OR REPLACE FUNCTION sync_student_registrations()
RETURNS void AS $$
BEGIN
    -- Insert new registrations
    INSERT INTO student_registered_units (
        student_id,
        unit_id,
        unit_code,
        unit_name,
        department,
        course_name,
        year,
        semester,
        registration_date
    )
    SELECT DISTINCT
        su.student_id,
        su.unit_id,
        u.code,
        u.name,
        d.name,
        c.name,
        su.year,
        su.semester,
        su.registration_date
    FROM student_units su
    JOIN units u ON u.id = su.unit_id
    JOIN courses c ON c.id = u.course_id
    JOIN departments d ON d.id = c.department_id
    WHERE su.status = 'registered'
    AND NOT EXISTS (
        SELECT 1 FROM student_registered_units sru
        WHERE sru.student_id = su.student_id
        AND sru.unit_id = su.unit_id
        AND sru.year = su.year
        AND sru.semester = su.semester
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get students for CAT marks entry
CREATE OR REPLACE FUNCTION get_unit_students_for_cat(
    p_unit_id UUID,
    p_lecturer_id UUID
) RETURNS TABLE (
    student_id UUID,
    registration_number TEXT,
    student_name TEXT,
    email TEXT,
    department TEXT,
    course_name TEXT,
    cat1_marks NUMERIC,
    cat2_marks NUMERIC,
    registration_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- First verify lecturer is assigned to this unit
    IF NOT EXISTS (
        SELECT 1 FROM lecturer_units 
        WHERE lecturer_id = p_lecturer_id 
        AND unit_id = p_unit_id
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Lecturer not assigned to this unit';
    END IF;

    RETURN QUERY
    SELECT DISTINCT
        s.id as student_id,
        COALESCE(s.registration_number, UPPER(u.email::text)) as registration_number,
        u.name as student_name,
        u.email,
        sru.department,
        sru.course_name,
        cat1.marks as cat1_marks,
        cat2.marks as cat2_marks,
        sru.registration_date
    FROM student_registered_units sru
    JOIN students s ON s.id = sru.student_id
    JOIN users u ON u.id = s.user_id
    LEFT JOIN cat_results cat1 ON 
        cat1.student_id = s.id 
        AND cat1.unit_id = sru.unit_id 
        AND cat1.cat_number = 'CAT1'
    LEFT JOIN cat_results cat2 ON 
        cat2.student_id = s.id 
        AND cat2.unit_id = sru.unit_id 
        AND cat2.cat_number = 'CAT2'
    WHERE sru.unit_id = p_unit_id
    ORDER BY u.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger function to automatically sync registrations
CREATE OR REPLACE FUNCTION trigger_sync_student_registrations()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM sync_student_registrations();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically sync when student_units changes
DROP TRIGGER IF EXISTS student_units_sync_trigger ON student_units;
CREATE TRIGGER student_units_sync_trigger
    AFTER INSERT OR UPDATE OR DELETE ON student_units
    FOR EACH STATEMENT
    EXECUTE FUNCTION trigger_sync_student_registrations();

-- Grant permissions
GRANT EXECUTE ON FUNCTION sync_student_registrations TO authenticated;
GRANT EXECUTE ON FUNCTION trigger_sync_student_registrations TO authenticated;
GRANT EXECUTE ON FUNCTION get_unit_students_for_cat TO authenticated;

-- Run the sync once to populate the table
SELECT sync_student_registrations(); 
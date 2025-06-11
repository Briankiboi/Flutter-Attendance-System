-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing functions first to avoid conflicts
DROP FUNCTION IF EXISTS register_unit(UUID, UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_available_units(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_units_by_department(UUID);
DROP FUNCTION IF EXISTS get_units_by_course(UUID);

-- First, let's clean up any existing data and start fresh
TRUNCATE TABLE student_units CASCADE;

-- Drop and recreate the student_units table with proper structure
DROP TABLE IF EXISTS student_units CASCADE;
CREATE TABLE student_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id),
    unit_id UUID NOT NULL REFERENCES units(id),
    year TEXT NOT NULL,
    semester TEXT NOT NULL,
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'registered', 'dropped')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, unit_id, year, semester)
);

-- Create indexes for better query performance
CREATE INDEX idx_student_units_student_id ON student_units(student_id);
CREATE INDEX idx_student_units_unit_id ON student_units(unit_id);
CREATE INDEX idx_student_units_status ON student_units(status);

-- Drop ALL existing versions of the function first
DROP FUNCTION IF EXISTS get_available_units(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_available_units(p_student_id UUID, p_year TEXT, p_semester TEXT);

-- Function to get available units for a student
CREATE OR REPLACE FUNCTION get_available_units(
    p_student_id UUID,
    p_year TEXT,
    p_semester TEXT
) RETURNS TABLE (
    unit_id UUID,
    unit_code TEXT,
    unit_name TEXT,
    course_name TEXT,
    department_name TEXT,
    year TEXT,
    semester TEXT
) AS $$
DECLARE
    v_student_course_id UUID;
    v_student_department_id UUID;
    v_student_course TEXT;
    v_student_department TEXT;
BEGIN
    -- Get student's course and department info
    SELECT 
        s.course_id,
        s.department_id,
        s.course,
        s.department
    INTO 
        v_student_course_id,
        v_student_department_id,
        v_student_course,
        v_student_department
    FROM students s
    WHERE s.id = p_student_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student not found';
    END IF;

    -- Return available units
    RETURN QUERY
    SELECT DISTINCT
        u.id as unit_id,
        u.code as unit_code,
        u.name as unit_name,
        c.name as course_name,
        d.name as department_name,
        u.year,
        u.semester
    FROM units u
    JOIN courses c ON u.course_id = c.id
    JOIN departments d ON c.department_id = d.id
    WHERE 
        -- Match year and semester (remove any prefix)
        REPLACE(REPLACE(u.year, 'Year ', ''), 'year ', '') = REPLACE(REPLACE(p_year, 'Year ', ''), 'year ', '')
        AND REPLACE(REPLACE(u.semester, 'Semester ', ''), 'semester ', '') = REPLACE(REPLACE(p_semester, 'Semester ', ''), 'semester ', '')
        AND (
            -- Case 1: Direct course match using course_id
            (v_student_course_id IS NOT NULL AND u.course_id = v_student_course_id)
            OR
            -- Case 2: Match by department_id
            (v_student_department_id IS NOT NULL AND c.department_id = v_student_department_id)
            OR
            -- Case 3: Education students can see Math/bio units
            (v_student_department = 'Education' AND c.name = 'Math/bio')
            OR
            -- Case 4: Fallback to text matching if IDs not available
            (v_student_course_id IS NULL AND v_student_course = c.name)
            OR
            (v_student_department_id IS NULL AND v_student_department = d.name)
        )
        -- Exclude already registered units
        AND NOT EXISTS (
            SELECT 1 
            FROM student_units su
            WHERE su.unit_id = u.id
            AND su.student_id = p_student_id
            AND REPLACE(REPLACE(su.year, 'Year ', ''), 'year ', '') = REPLACE(REPLACE(p_year, 'Year ', ''), 'year ', '')
            AND REPLACE(REPLACE(su.semester, 'Semester ', ''), 'semester ', '') = REPLACE(REPLACE(p_semester, 'Semester ', ''), 'semester ', '')
            AND su.status = 'registered'
        )
    ORDER BY u.code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_available_units(UUID, TEXT, TEXT) TO authenticated;

-- Function to register units
CREATE OR REPLACE FUNCTION register_unit(
    p_student_id UUID,
    p_unit_id UUID,
    p_year TEXT,
    p_semester TEXT
) RETURNS TEXT AS $$
DECLARE
    v_unit_exists BOOLEAN;
    v_already_registered BOOLEAN;
BEGIN
    -- Check if unit exists and is available for the course
    SELECT EXISTS (
        SELECT 1 
        FROM get_available_units(p_student_id, p_year, p_semester) 
        WHERE unit_id = p_unit_id
    ) INTO v_unit_exists;

    IF NOT v_unit_exists THEN
        RETURN 'Unit not available for registration';
    END IF;

    -- Check if already registered
    SELECT EXISTS (
        SELECT 1 
        FROM student_units 
        WHERE student_id = p_student_id 
        AND unit_id = p_unit_id
        AND year = p_year 
        AND semester = p_semester
        AND status = 'registered'
    ) INTO v_already_registered;

    IF v_already_registered THEN
        RETURN 'Unit already registered';
    END IF;

    -- Register the unit
    INSERT INTO student_units (
        student_id,
        unit_id,
        year,
        semester,
        status
    ) VALUES (
        p_student_id,
        p_unit_id,
        p_year,
        p_semester,
        'registered'
    )
    ON CONFLICT (student_id, unit_id, year, semester) 
    DO UPDATE SET 
        status = 'registered',
        updated_at = NOW();

    RETURN 'Unit registered successfully';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE student_units ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DROP POLICY IF EXISTS "Students can view their own units" ON student_units;
DROP POLICY IF EXISTS "Students can register units" ON student_units;
DROP POLICY IF EXISTS "Students can update their own units" ON student_units;

CREATE POLICY "Students can view their own units"
ON student_units FOR SELECT
USING (auth.uid() IN (SELECT user_id FROM students WHERE id = student_id));

CREATE POLICY "Students can register units"
ON student_units FOR INSERT
WITH CHECK (auth.uid() IN (SELECT user_id FROM students WHERE id = student_id));

CREATE POLICY "Students can update their own units"
ON student_units FOR UPDATE
USING (auth.uid() IN (SELECT user_id FROM students WHERE id = student_id));

-- Grant permissions
GRANT ALL ON TABLE student_units TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_units TO authenticated;
GRANT EXECUTE ON FUNCTION register_unit TO authenticated; 
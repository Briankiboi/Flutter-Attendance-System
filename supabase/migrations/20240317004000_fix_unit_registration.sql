-- First, ensure units are properly linked to courses
ALTER TABLE units
ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id);

-- Create a function to help find available units for students
CREATE OR REPLACE FUNCTION get_available_units(
    p_student_id UUID,
    p_year TEXT,
    p_semester TEXT
) 
RETURNS TABLE (
    unit_id UUID,
    unit_code TEXT,
    unit_name TEXT,
    course_name TEXT,
    department_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as unit_id,
        u.code as unit_code,
        u.name as unit_name,
        c.name as course_name,
        d.name as department_name
    FROM units u
    JOIN courses c ON u.course_id = c.id
    JOIN departments d ON c.department_id = d.id
    JOIN students s ON s.course_id = c.id
    WHERE s.id = p_student_id
    AND u.year = p_year
    AND u.semester = p_semester
    AND NOT EXISTS (
        -- Exclude already registered units
        SELECT 1 FROM student_units su
        WHERE su.student_id = p_student_id
        AND su.unit_id = u.id
        AND su.year = p_year
        AND su.semester = p_semester
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to register units for a student
CREATE OR REPLACE FUNCTION register_student_units(
    p_student_id UUID,
    p_unit_ids UUID[],
    p_year TEXT,
    p_semester TEXT
) RETURNS void AS $$
BEGIN
    INSERT INTO student_units (
        student_id,
        unit_id,
        year,
        semester,
        status,
        created_at,
        updated_at
    )
    SELECT 
        p_student_id,
        unit_id,
        p_year,
        p_semester,
        'registered',
        NOW(),
        NOW()
    FROM unnest(p_unit_ids) unit_id
    WHERE NOT EXISTS (
        SELECT 1 FROM student_units
        WHERE student_id = p_student_id
        AND unit_id = unit_id
        AND year = p_year
        AND semester = p_semester
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Migrate existing student data to student_units if not already there
INSERT INTO student_units (
    student_id,
    unit_id,
    year,
    semester,
    status,
    created_at,
    updated_at
)
SELECT DISTINCT
    s.id as student_id,
    u.id as unit_id,
    s.year,
    s.semester,
    'registered',
    NOW(),
    NOW()
FROM students s
JOIN courses c ON s.course_id = c.id
JOIN units u ON u.course_id = c.id
WHERE u.year = s.year 
AND u.semester = s.semester
AND NOT EXISTS (
    SELECT 1 FROM student_units su
    WHERE su.student_id = s.id
    AND su.unit_id = u.id
    AND su.year = s.year
    AND su.semester = s.semester
); 
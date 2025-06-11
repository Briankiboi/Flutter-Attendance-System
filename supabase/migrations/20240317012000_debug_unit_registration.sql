-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS get_available_units(UUID, TEXT, TEXT);

-- Create a simpler version of get_available_units
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
    department_name TEXT,
    year TEXT,
    semester TEXT
) AS $$
BEGIN
    -- Return all available units for the student's year and semester
    -- that haven't been registered yet
    RETURN QUERY
    SELECT 
        u.id as unit_id,
        u.code as unit_code,
        u.name as unit_name,
        c.name as course_name,
        d.name as department_name,
        u.year,
        u.semester
    FROM units u
    LEFT JOIN courses c ON u.course_id = c.id
    LEFT JOIN departments d ON c.department_id = d.id
    -- Get the student's course and department
    CROSS JOIN (
        SELECT 
            s.course_id,
            s.department_id,
            s.course as student_course,
            s.department as student_department
        FROM students s
        WHERE s.id = p_student_id
    ) student
    WHERE 
        -- Match year and semester
        u.year = p_year 
        AND u.semester = p_semester
        -- Ensure unit hasn't been registered yet
        AND NOT EXISTS (
            SELECT 1 
            FROM student_units su
            WHERE su.unit_id = u.id
            AND su.student_id = p_student_id
            AND su.year = p_year
            AND su.semester = p_semester
        )
        -- Match either by course_id, department_id, or text fields
        AND (
            -- Match by course_id if available
            (student.course_id IS NOT NULL AND u.course_id = student.course_id)
            OR 
            -- Match by department_id if available
            (student.department_id IS NOT NULL AND c.department_id = student.department_id)
            OR
            -- Fallback to text matching if IDs not available
            (student.course_id IS NULL AND c.name = student.student_course)
            OR
            (student.department_id IS NULL AND d.name = student.student_department)
        );

    -- Log debug info
    RAISE NOTICE 'Fetching units for student %, year %, semester %', 
        p_student_id, p_year, p_semester;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_available_units TO authenticated; 
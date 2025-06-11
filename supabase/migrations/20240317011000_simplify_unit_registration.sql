-- Simplify the get_available_units function to handle all departments uniformly
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
    SELECT DISTINCT
        u.id as unit_id,
        u.code as unit_code,
        u.name as unit_name,
        c.name as course_name,
        d.name as department_name
    FROM units u
    JOIN courses c ON u.course_id = c.id
    JOIN departments d ON c.department_id = d.id
    JOIN students s ON (
        -- Match by course_id (primary method)
        (s.course_id = c.id)
        OR
        -- Match by department_id (allows students to take any course in their department)
        (s.department_id = d.id)
    )
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
    )
    ORDER BY u.code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
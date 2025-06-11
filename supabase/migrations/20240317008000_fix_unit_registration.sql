-- Update the get_available_units function to handle course names better
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
DECLARE
    v_student_department TEXT;
    v_student_course TEXT;
BEGIN
    -- Get student's department and course
    SELECT department, course INTO v_student_department, v_student_course
    FROM students
    WHERE id = p_student_id;

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
    WHERE (
        -- For Education department students taking Math/bio
        (v_student_department = 'Education' AND c.name = 'Math/bio')
        OR
        -- For other students, match by course name
        (v_student_course = c.name)
    )
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
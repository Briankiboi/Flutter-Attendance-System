-- Update the get_available_units function to better handle Education students
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
    v_student_course_id UUID;
BEGIN
    -- Get student's department, course and course_id
    SELECT 
        d.name,
        c.name,
        s.course_id
    INTO 
        v_student_department,
        v_student_course,
        v_student_course_id
    FROM students s
    LEFT JOIN departments d ON s.department_id = d.id
    LEFT JOIN courses c ON s.course_id = c.id
    WHERE s.id = p_student_id;

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
    WHERE (
        -- Case 1: Direct course match using course_id
        (v_student_course_id IS NOT NULL AND u.course_id = v_student_course_id)
        OR
        -- Case 2: Education students taking Math/bio
        (v_student_department = 'Education' AND c.name = 'Math/bio')
        OR
        -- Case 3: Fallback to text field matching if no course_id
        (v_student_course_id IS NULL AND v_student_course = c.name)
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
    )
    ORDER BY u.code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
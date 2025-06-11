-- Update student profiles to set course_id and department_id based on text fields
UPDATE students s
SET 
    department_id = d.id,
    course_id = c.id
FROM departments d, courses c
WHERE 
    LOWER(TRIM(s.department)) = LOWER(TRIM(d.name))
    AND LOWER(TRIM(s.course)) = LOWER(TRIM(c.name))
    AND c.department_id = d.id
    AND (s.department_id IS NULL OR s.course_id IS NULL);

-- Update the get_available_units function to handle both old and new fields
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
        -- Match using new foreign keys if available
        (s.course_id IS NOT NULL AND s.course_id = c.id)
        OR
        -- Match by department for education students (can see all courses in their department)
        (s.department_id IS NOT NULL AND s.department_id = d.id)
        OR
        -- Fall back to text fields if foreign keys are not set
        (s.course_id IS NULL AND LOWER(TRIM(s.course)) = LOWER(TRIM(c.name)))
        OR
        -- Fall back to department text field (can see all courses in their department)
        (s.department_id IS NULL AND LOWER(TRIM(s.department)) = LOWER(TRIM(d.name)))
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
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
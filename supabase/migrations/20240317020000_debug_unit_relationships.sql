-- Debug script to check unit relationships and data

-- 1. Check units table
SELECT 
    'Units Table Stats' as check_type,
    count(*) as total_count,
    count(DISTINCT course_id) as unique_courses,
    count(DISTINCT year) as unique_years,
    count(DISTINCT semester) as unique_semesters
FROM units;

-- 2. Check specific units for Year 3, Semester 2
SELECT 
    u.id,
    u.code as unit_code,
    u.name as unit_name,
    u.year,
    u.semester,
    u.course_id,
    c.name as course_name,
    d.name as department_name
FROM units u
LEFT JOIN courses c ON u.course_id = c.id
LEFT JOIN departments d ON c.department_id = d.id
WHERE u.year = 'Year 3'
AND u.semester = 'Semester 2'
ORDER BY u.code;

-- 3. Check student data
SELECT 
    s.id,
    s.user_id,
    s.department,
    s.course,
    s.year,
    s.semester,
    s.course_id,
    s.department_id,
    c.name as course_name,
    d.name as department_name
FROM students s
LEFT JOIN courses c ON s.course_id = c.id
LEFT JOIN departments d ON s.department_id = d.id
WHERE s.id = 'd62dceba-60e9-4581-a9e9-87050d9cfc3e';  -- Your student ID

-- 4. Check course relationships
SELECT 
    c.id as course_id,
    c.name as course_name,
    d.id as department_id,
    d.name as department_name,
    (SELECT count(*) FROM units u WHERE u.course_id = c.id) as unit_count
FROM courses c
LEFT JOIN departments d ON c.department_id = d.id
WHERE c.name = 'Math/bio'
   OR d.name = 'Education';

-- 5. Check registered units
SELECT 
    su.student_id,
    su.unit_id,
    su.year,
    su.semester,
    u.code as unit_code,
    u.name as unit_name,
    c.name as course_name
FROM student_units su
JOIN units u ON su.unit_id = u.id
LEFT JOIN courses c ON u.course_id = c.id
WHERE su.student_id = 'd62dceba-60e9-4581-a9e9-87050d9cfc3e'
AND su.year = 'Year 3'
AND su.semester = 'Semester 2';

-- 6. Check available units (not registered)
SELECT 
    u.id as unit_id,
    u.code as unit_code,
    u.name as unit_name,
    u.year,
    u.semester,
    c.name as course_name,
    d.name as department_name
FROM units u
JOIN courses c ON u.course_id = c.id
JOIN departments d ON c.department_id = d.id
WHERE u.year = 'Year 3'
AND u.semester = 'Semester 2'
AND (
    c.name = 'Math/bio'
    OR d.name = 'Education'
)
AND NOT EXISTS (
    SELECT 1 FROM student_units su
    WHERE su.unit_id = u.id
    AND su.student_id = 'd62dceba-60e9-4581-a9e9-87050d9cfc3e'
    AND su.year = 'Year 3'
    AND su.semester = 'Semester 2'
);

-- 7. Check if any orphaned records exist
SELECT 'Orphaned Units' as issue,
       count(*) as count
FROM units u
LEFT JOIN courses c ON u.course_id = c.id
WHERE c.id IS NULL
UNION ALL
SELECT 'Units without Year', count(*)
FROM units
WHERE year IS NULL
UNION ALL
SELECT 'Units without Semester', count(*)
FROM units
WHERE semester IS NULL
UNION ALL
SELECT 'Courses without Department', count(*)
FROM courses c
LEFT JOIN departments d ON c.department_id = d.id
WHERE d.id IS NULL;

-- 8. Check units table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'units';

-- 9. Check if units exist for Math/bio course
SELECT u.*, c.name as course_name
FROM units u
JOIN courses c ON u.course_id = c.id
WHERE c.name = 'Math/bio'
ORDER BY u.year, u.semester;

-- First, let's check and fix the department relationships

-- 1. Check current department setup
SELECT id, name FROM departments WHERE name = 'Education';

-- 2. Check current course-department relationships
SELECT c.id as course_id, 
       c.name as course_name,
       c.department_id,
       d.name as department_name
FROM courses c
LEFT JOIN departments d ON c.department_id = d.id
WHERE c.name = 'Math/bio';

-- 3. Ensure Education department exists
INSERT INTO departments (id, name)
SELECT 
    gen_random_uuid(),
    'Education'
WHERE NOT EXISTS (
    SELECT 1 FROM departments WHERE name = 'Education'
);

-- 4. Update Math/bio course to link with Education department
UPDATE courses c
SET department_id = (SELECT id FROM departments WHERE name = 'Education')
WHERE c.name = 'Math/bio'
AND (c.department_id IS NULL OR 
    c.department_id NOT IN (SELECT id FROM departments WHERE name = 'Education'));

-- 5. Verify the relationships are fixed
SELECT 
    u.code as unit_code,
    u.name as unit_name,
    u.year,
    u.semester,
    c.name as course_name,
    d.name as department_name,
    c.department_id
FROM units u
JOIN courses c ON u.course_id = c.id
LEFT JOIN departments d ON c.department_id = d.id
WHERE c.name = 'Math/bio'
ORDER BY u.year, u.semester;

-- 6. Update get_available_units function to handle all relationships generically
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
    RETURN QUERY
    WITH student_info AS (
        SELECT 
            s.id,
            s.course_id,
            s.department_id,
            s.course,
            s.department,
            s.year,
            s.semester,
            c.department_id as course_dept_id,
            c.name as linked_course_name,
            d.name as linked_dept_name
        FROM students s
        LEFT JOIN courses c ON s.course_id = c.id
        LEFT JOIN departments d ON COALESCE(s.department_id, c.department_id) = d.id
        WHERE s.id = p_student_id
    )
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
    CROSS JOIN student_info si
    WHERE u.year = p_year 
    AND u.semester = p_semester
    AND (
        -- Match by course ID (primary)
        u.course_id = si.course_id
        OR
        -- Match by department ID from either student or course
        (COALESCE(si.department_id, si.course_dept_id) IS NOT NULL 
         AND c.department_id = COALESCE(si.department_id, si.course_dept_id))
        OR
        -- Match by course name text field
        (si.course IS NOT NULL AND c.name = si.course)
        OR
        -- Match by department name text field
        (si.department IS NOT NULL AND d.name = si.department)
        OR
        -- Match by linked course name
        (si.linked_course_name IS NOT NULL AND c.name = si.linked_course_name)
        OR
        -- Match by linked department name
        (si.linked_dept_name IS NOT NULL AND d.name = si.linked_dept_name)
    )
    AND NOT EXISTS (
        SELECT 1 FROM student_units su
        WHERE su.unit_id = u.id
        AND su.student_id = p_student_id
        AND su.year = p_year
        AND su.semester = p_semester
    )
    ORDER BY u.code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_available_units TO authenticated;

-- Debug query to verify relationships (can be run anytime to check status)
SELECT 
    'Relationship Check' as check_type,
    count(DISTINCT d.id) as total_departments,
    count(DISTINCT c.id) as total_courses,
    count(DISTINCT u.id) as total_units,
    count(DISTINCT u.year) as unique_years,
    count(DISTINCT u.semester) as unique_semesters,
    count(DISTINCT CASE WHEN c.department_id IS NOT NULL THEN c.id END) as courses_with_dept,
    count(DISTINCT CASE WHEN u.course_id IS NOT NULL THEN u.id END) as units_with_course
FROM departments d
LEFT JOIN courses c ON c.department_id = d.id
LEFT JOIN units u ON u.course_id = c.id; 
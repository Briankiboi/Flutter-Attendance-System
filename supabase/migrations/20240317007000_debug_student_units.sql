-- First check the student's profile and course linkage
WITH student_info AS (
    SELECT 
        s.id as student_id,
        s.user_id,
        s.course_id,
        s.department_id,
        s.year,
        s.semester,
        c.name as course_name,
        d.name as department_name
    FROM students s
    LEFT JOIN courses c ON s.course_id = c.id
    LEFT JOIN departments d ON s.department_id = d.id
    WHERE s.year = '3' 
    AND s.semester = '2'
    AND (c.name ILIKE 'Math/bio' OR d.name ILIKE 'Education')
)
SELECT * FROM student_info;

-- Then check available units for this course
SELECT 
    u.code,
    u.name,
    u.year,
    u.semester,
    c.name as course_name,
    d.name as department_name
FROM units u
JOIN courses c ON u.course_id = c.id
JOIN departments d ON c.department_id = d.id
WHERE u.year = '3'
AND u.semester = '2'
AND (c.name ILIKE 'Math/bio' OR d.name ILIKE 'Education'); 
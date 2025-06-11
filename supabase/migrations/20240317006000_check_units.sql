-- Check units and their relationships
SELECT 
    u.code as unit_code,
    u.name as unit_name,
    u.year,
    u.semester,
    c.name as course_name,
    d.name as department_name
FROM units u
LEFT JOIN courses c ON u.course_id = c.id
LEFT JOIN departments d ON c.department_id = d.id
ORDER BY u.year, u.semester, u.code; 
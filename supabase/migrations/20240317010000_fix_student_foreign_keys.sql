-- First ensure all departments exist
INSERT INTO departments (name)
SELECT DISTINCT department
FROM students
WHERE department IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM departments
    WHERE LOWER(TRIM(departments.name)) = LOWER(TRIM(students.department))
  );

-- Then ensure all courses exist with proper department relationships
INSERT INTO courses (name, department_id)
SELECT DISTINCT 
    s.course,
    d.id as department_id
FROM students s
JOIN departments d ON LOWER(TRIM(d.name)) = LOWER(TRIM(s.department))
WHERE s.course IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM courses c
    WHERE LOWER(TRIM(c.name)) = LOWER(TRIM(s.course))
    AND c.department_id = d.id
  );

-- Update student records to use foreign keys
UPDATE students s
SET 
    department_id = d.id,
    course_id = c.id
FROM departments d
JOIN courses c ON c.department_id = d.id
WHERE 
    LOWER(TRIM(s.department)) = LOWER(TRIM(d.name))
    AND LOWER(TRIM(s.course)) = LOWER(TRIM(c.name))
    AND (s.department_id IS NULL OR s.course_id IS NULL);

-- Special handling for Education department
UPDATE students s
SET 
    department_id = d.id,
    course_id = c.id
FROM departments d
JOIN courses c ON c.department_id = d.id
WHERE 
    LOWER(TRIM(s.department)) ILIKE 'education'
    AND LOWER(TRIM(c.name)) ILIKE 'math/bio'
    AND (s.department_id IS NULL OR s.course_id IS NULL); 
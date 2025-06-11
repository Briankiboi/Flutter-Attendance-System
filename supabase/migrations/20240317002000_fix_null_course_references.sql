-- Function to fix NULL course_id values safely
CREATE OR REPLACE FUNCTION fix_null_course_references() 
RETURNS void AS $$
DECLARE
  student_rec RECORD;
  matching_course_id UUID;
BEGIN
  -- Loop through students with NULL course_id
  FOR student_rec IN 
    SELECT * FROM students 
    WHERE course_id IS NULL 
    AND course IS NOT NULL 
  LOOP
    -- Try to find matching course with case-insensitive comparison
    SELECT id INTO matching_course_id 
    FROM courses c
    WHERE LOWER(TRIM(c.name)) = LOWER(TRIM(student_rec.course))
    AND c.department_id = student_rec.department_id;
    
    IF matching_course_id IS NOT NULL THEN
      -- Update only if we found a match
      UPDATE students
      SET course_id = matching_course_id
      WHERE id = student_rec.id
      AND course_id IS NULL; -- Extra safety check
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the fix function
SELECT fix_null_course_references(); 
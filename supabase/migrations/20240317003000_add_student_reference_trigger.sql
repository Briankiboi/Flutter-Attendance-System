-- Create a function to set course_id and department_id based on text values
CREATE OR REPLACE FUNCTION set_student_references()
RETURNS TRIGGER AS $$
DECLARE
    dept_id UUID;
    crs_id UUID;
BEGIN
    -- First find department_id from department name
    IF NEW.department IS NOT NULL THEN
        SELECT id INTO dept_id
        FROM departments
        WHERE LOWER(TRIM(name)) = LOWER(TRIM(NEW.department));
        
        IF FOUND THEN
            NEW.department_id := dept_id;
            
            -- Then find course_id using department_id
            IF NEW.course IS NOT NULL THEN
                SELECT id INTO crs_id
                FROM courses
                WHERE LOWER(TRIM(name)) = LOWER(TRIM(NEW.course))
                AND department_id = dept_id;
                
                IF FOUND THEN
                    NEW.course_id := crs_id;
                END IF;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for INSERT and UPDATE operations
DROP TRIGGER IF EXISTS set_student_references_trigger ON students;
CREATE TRIGGER set_student_references_trigger
    BEFORE INSERT OR UPDATE OF department, course
    ON students
    FOR EACH ROW
    EXECUTE FUNCTION set_student_references();

-- Fix existing NULL values
UPDATE students
SET 
    department = TRIM(department),
    course = TRIM(course)
WHERE department IS NOT NULL OR course IS NOT NULL; 
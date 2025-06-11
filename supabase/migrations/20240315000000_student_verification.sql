-- Create function to verify student eligibility
CREATE OR REPLACE FUNCTION verify_student_eligibility(
    p_student_id UUID,
    p_department TEXT,
    p_course TEXT,
    p_year TEXT,
    p_semester TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM students s
        WHERE s.id = p_student_id
        AND s.department = p_department
        AND s.course = p_course
        AND s.year = p_year
        AND s.current_semester = p_semester
        AND s.is_active = true
    );
END;
$$ LANGUAGE plpgsql;

-- Create view for active sessions by student criteria
CREATE OR REPLACE VIEW eligible_sessions AS
SELECT 
    s.*,
    s.session_data->>'department' as department,
    s.session_data->>'course' as course,
    s.session_data->>'year' as year,
    s.session_data->>'semester' as semester
FROM attendance_sessions s
WHERE s.is_active = true; 
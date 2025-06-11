-- Safe, non-destructive script to fix student access
-- This script only adds/updates functions and policies without touching existing data

-- First, create or replace the get_registered_students function
CREATE OR REPLACE FUNCTION get_registered_students(p_unit_id UUID)
RETURNS TABLE (
    student_id UUID,
    student_name TEXT,
    email TEXT,
    registration_number TEXT,
    registration_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        s.id as student_id,
        u.name as student_name,
        u.email,
        UPPER(SPLIT_PART(u.email, '@', 1)) as registration_number,
        su.registration_date
    FROM student_units su
    JOIN students s ON s.id = su.student_id
    JOIN users u ON u.id = s.user_id
    WHERE su.unit_id = p_unit_id
    AND su.status = 'registered'
    ORDER BY u.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION get_registered_students TO authenticated;

-- Update the lecturer view policy for student_units (won't affect data)
DO $$
BEGIN
    -- Drop only if exists (safe operation)
    DROP POLICY IF EXISTS "Lecturers can view units of their students" ON student_units;
    
    -- Create new policy
    CREATE POLICY "Lecturers can view units of their students"
    ON student_units FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 
            FROM lecturer_units lu
            JOIN lecturers l ON l.id = lu.lecturer_id
            WHERE lu.unit_id = student_units.unit_id
            AND l.user_id = auth.uid()
        )
    );
END $$; 
-- Remove auto-registered units but keep manually registered ones
DELETE FROM student_units 
WHERE created_at = updated_at  -- This indicates it was from the auto-migration
AND status = 'registered';

-- Update the registration function to be more explicit
CREATE OR REPLACE FUNCTION register_student_units(
    p_student_id UUID,
    p_unit_ids UUID[],
    p_year TEXT,
    p_semester TEXT
) RETURNS TABLE (
    unit_code TEXT,
    unit_name TEXT,
    status TEXT
) AS $$
BEGIN
    -- Register the units
    INSERT INTO student_units (
        student_id,
        unit_id,
        year,
        semester,
        status,
        created_at,
        updated_at
    )
    SELECT 
        p_student_id,
        unit_id,
        p_year,
        p_semester,
        'registered',
        NOW(),
        NOW()
    FROM unnest(p_unit_ids) unit_id
    WHERE NOT EXISTS (
        SELECT 1 FROM student_units
        WHERE student_id = p_student_id
        AND unit_id = unit_id
        AND year = p_year
        AND semester = p_semester
    );

    -- Return the registered units info
    RETURN QUERY
    SELECT 
        u.code as unit_code,
        u.name as unit_name,
        su.status
    FROM student_units su
    JOIN units u ON u.id = su.unit_id
    WHERE su.student_id = p_student_id
    AND su.year = p_year
    AND su.semester = p_semester;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
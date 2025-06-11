BEGIN;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Step 1: Create message types enum
DO $$ BEGIN
    CREATE TYPE schedule_message_type AS ENUM ('schedule', 'announcement');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE schedule_message_status AS ENUM ('draft', 'sent', 'deleted');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Step 2: Create the main messages table
CREATE TABLE IF NOT EXISTS schedule_messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    unit_id UUID NOT NULL REFERENCES units(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    schedule_date DATE DEFAULT CURRENT_DATE
);

-- Step 3: Create read status table
CREATE TABLE IF NOT EXISTS message_read_status (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES schedule_messages(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id),
    read_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(message_id, student_id)
);

-- Step 4: Create indexes
CREATE INDEX IF NOT EXISTS idx_schedule_messages_unit ON schedule_messages(unit_id);
CREATE INDEX IF NOT EXISTS idx_schedule_messages_date ON schedule_messages(schedule_date);
CREATE INDEX IF NOT EXISTS idx_message_read_status ON message_read_status(message_id, student_id);

-- Step 5: Create student view
CREATE OR REPLACE VIEW student_schedules AS
WITH student_unit_access AS (
    SELECT DISTINCT student_id, unit_id 
    FROM (
        SELECT student_id, unit_id FROM student_units
        UNION
        SELECT student_id, unit_id FROM student_registered_units
    ) combined
)
SELECT 
    sm.*,
    u.code as unit_code,
    u.name as unit_name,
    l.name as lecturer_name,
    sua.student_id,
    mrs.read_at,
    CASE 
        WHEN mrs.read_at IS NULL THEN true
        ELSE false
    END as is_new
FROM schedule_messages sm
JOIN units u ON u.id = sm.unit_id
JOIN lecturers l ON l.id = sm.lecturer_id
JOIN student_unit_access sua ON sua.unit_id = sm.unit_id
LEFT JOIN message_read_status mrs ON mrs.message_id = sm.id;

-- Step 6: Enable RLS
ALTER TABLE schedule_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_read_status ENABLE ROW LEVEL SECURITY;

-- Step 7: Create RLS policies
DO $$
BEGIN
    -- Lecturer policies
    DROP POLICY IF EXISTS "Lecturers can view their own messages" ON schedule_messages;
    CREATE POLICY "Lecturers can view their own messages"
    ON schedule_messages FOR SELECT
    TO authenticated
    USING (
        auth.uid() IN (
            SELECT user_id FROM lecturers WHERE id = lecturer_id
        )
    );

    DROP POLICY IF EXISTS "Lecturers can insert their own messages" ON schedule_messages;
    CREATE POLICY "Lecturers can insert their own messages"
    ON schedule_messages FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM lecturers WHERE id = lecturer_id
        )
    );

    DROP POLICY IF EXISTS "Lecturers can update their own messages" ON schedule_messages;
    CREATE POLICY "Lecturers can update their own messages"
    ON schedule_messages FOR UPDATE
    TO authenticated
    USING (
        auth.uid() IN (
            SELECT user_id FROM lecturers WHERE id = lecturer_id
        )
    );

    -- Student policies
    DROP POLICY IF EXISTS "Students can view their read status" ON message_read_status;
    CREATE POLICY "Students can view their read status"
    ON message_read_status FOR SELECT
    TO authenticated
    USING (
        auth.uid() IN (
            SELECT user_id FROM students WHERE id = student_id
        )
    );

    DROP POLICY IF EXISTS "Students can insert their read status" ON message_read_status;
    CREATE POLICY "Students can insert their read status"
    ON message_read_status FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM students WHERE id = student_id
        )
    );
END
$$;

-- Step 8: Create function to get unit student count
CREATE OR REPLACE FUNCTION get_unit_student_count(p_unit_id UUID)
RETURNS TABLE (count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT COUNT(DISTINCT student_id)::BIGINT
    FROM (
        SELECT student_id FROM student_units WHERE unit_id = p_unit_id
        UNION
        SELECT student_id FROM student_registered_units WHERE unit_id = p_unit_id
    ) students;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT; 
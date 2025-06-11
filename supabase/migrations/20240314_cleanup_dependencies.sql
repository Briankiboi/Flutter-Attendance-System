-- Safe migration to handle view dependencies and cleanup
-- PRESERVES ALL STUDENT CONNECTIONS AND ACCESS
BEGIN;

-- 1. First verify student tables exist and have data
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM student_units) THEN
        RAISE EXCEPTION 'student_units table is empty or missing';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM student_registered_units) THEN
        RAISE EXCEPTION 'student_registered_units table is empty or missing';
    END IF;
END $$;

-- 2. Drop the dependent view first
DROP VIEW IF EXISTS student_schedules;

-- 3. Now we can safely drop the message_type column
ALTER TABLE schedule_messages DROP COLUMN IF EXISTS message_type;

-- 4. Recreate the view with preserved student access
CREATE OR REPLACE VIEW student_schedules AS
WITH student_unit_access AS (
    -- Preserve access from both current and registered units
    SELECT DISTINCT student_id, unit_id 
    FROM (
        SELECT student_id, unit_id FROM student_units
        UNION
        SELECT student_id, unit_id FROM student_registered_units
    ) combined
)
SELECT 
    sm.id,
    sm.unit_id,
    sm.content,
    sm.created_at,
    sm.updated_at,
    sm.schedule_date,
    u.code as unit_code,
    u.name as unit_name,
    l.name as lecturer_name,
    sua.student_id,                    -- Preserve student ID
    mrs.read_at,                       -- Preserve read status
    CASE 
        WHEN mrs.read_at IS NULL THEN true
        ELSE false
    END as is_new
FROM schedule_messages sm
JOIN units u ON u.id = sm.unit_id
LEFT JOIN lecturers l ON l.id = sm.lecturer_id
-- Preserve student unit access
JOIN student_unit_access sua ON sua.unit_id = sm.unit_id
-- Preserve student read status
LEFT JOIN message_read_status mrs ON mrs.message_id = sm.id 
    AND mrs.student_id = sua.student_id;

-- 5. Now we can safely drop other unused columns
-- Note: This does NOT affect student access or relationships
ALTER TABLE schedule_messages 
    DROP COLUMN IF EXISTS message,
    DROP COLUMN IF EXISTS start_time,
    DROP COLUMN IF EXISTS end_time,
    DROP COLUMN IF EXISTS is_important,
    DROP COLUMN IF EXISTS media_url;

-- 6. Simplify read_status while preserving student tracking
ALTER TABLE message_read_status 
    DROP COLUMN IF EXISTS device_info;

-- 7. Verify student access is preserved
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM student_schedules LIMIT 1
    ) THEN
        RAISE NOTICE 'Warning: No messages found in student_schedules view. This is normal if no messages exist yet.';
    END IF;
END $$;

COMMIT; 
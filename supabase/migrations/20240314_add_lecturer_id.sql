-- Add lecturer_id to schedule_messages table
BEGIN;

-- 1. Add lecturer_id column
ALTER TABLE schedule_messages
ADD COLUMN IF NOT EXISTS lecturer_id UUID REFERENCES lecturers(id);

-- 2. Update RLS policies to use lecturer_id
DROP POLICY IF EXISTS "Anyone can view messages" ON schedule_messages;
DROP POLICY IF EXISTS "Authenticated users can insert messages" ON schedule_messages;
DROP POLICY IF EXISTS "Authenticated users can update messages" ON schedule_messages;

-- Create new policies
CREATE POLICY "Lecturers can view their messages"
ON schedule_messages FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

CREATE POLICY "Lecturers can create messages"
ON schedule_messages FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

CREATE POLICY "Lecturers can update their messages"
ON schedule_messages FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

-- 3. Update student_schedules view to include lecturer_id
DROP VIEW IF EXISTS student_schedules;
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
    sm.id,
    sm.unit_id,
    sm.content,
    sm.created_at,
    sm.updated_at,
    sm.schedule_date,
    sm.lecturer_id,
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
LEFT JOIN lecturers l ON l.id = sm.lecturer_id
JOIN student_unit_access sua ON sua.unit_id = sm.unit_id
LEFT JOIN message_read_status mrs ON mrs.message_id = sm.id 
    AND mrs.student_id = sua.student_id;

COMMIT; 
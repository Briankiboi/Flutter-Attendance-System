ALTER TABLE schedule_messages DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lecturers can view their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can create messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can update their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can delete their messages" ON schedule_messages;

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

CREATE POLICY "Lecturers can delete their messages"
ON schedule_messages FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

ALTER TABLE schedule_messages ENABLE ROW LEVEL SECURITY;

GRANT ALL ON schedule_messages TO authenticated; 
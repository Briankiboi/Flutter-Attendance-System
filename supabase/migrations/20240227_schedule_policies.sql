-- Enable RLS on schedule-related tables
ALTER TABLE schedule_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_read_status ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Lecturers can view their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can create messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can update their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Lecturers can delete their messages" ON schedule_messages;
DROP POLICY IF EXISTS "Anyone can view read status" ON message_read_status;
DROP POLICY IF EXISTS "Students can create read status" ON message_read_status;

-- Create policies for schedule_messages
CREATE POLICY "Lecturers can view their messages"
ON schedule_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

CREATE POLICY "Lecturers can create messages"
ON schedule_messages FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

CREATE POLICY "Lecturers can update their messages"
ON schedule_messages FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

CREATE POLICY "Lecturers can delete their messages"
ON schedule_messages FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM lecturers
    WHERE lecturers.id = schedule_messages.lecturer_id
    AND lecturers.user_id = auth.uid()
  )
);

-- Create policies for message_read_status
CREATE POLICY "Anyone can view read status"
ON message_read_status FOR SELECT
USING (true);

CREATE POLICY "Students can create read status"
ON message_read_status FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM students
    WHERE students.id = message_read_status.student_id
    AND students.user_id = auth.uid()
  )
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_schedule_messages_lecturer_id ON schedule_messages(lecturer_id);
CREATE INDEX IF NOT EXISTS idx_schedule_messages_unit_id ON schedule_messages(unit_id);
CREATE INDEX IF NOT EXISTS idx_message_read_status_message_id ON message_read_status(message_id);
CREATE INDEX IF NOT EXISTS idx_message_read_status_student_id ON message_read_status(student_id); 
-- Create schedule_messages table if not exists
CREATE TABLE IF NOT EXISTS schedule_messages (
  id SERIAL PRIMARY KEY,
  unit_id INTEGER NOT NULL,
  lecturer_id UUID NOT NULL REFERENCES lecturers(id),
  message TEXT NOT NULL,
  message_type TEXT NOT NULL CHECK (message_type IN ('announcement', 'schedule')),
  schedule_date TIMESTAMP WITH TIME ZONE,
  start_time TEXT,
  end_time TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create message_read_status table if not exists
CREATE TABLE IF NOT EXISTS message_read_status (
  id SERIAL PRIMARY KEY,
  message_id INTEGER REFERENCES schedule_messages(id) ON DELETE CASCADE,
  student_id UUID NOT NULL,
  read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  device_info JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(message_id, student_id)
);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_schedule_messages_updated_at ON schedule_messages;
CREATE TRIGGER update_schedule_messages_updated_at
  BEFORE UPDATE ON schedule_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_message_read_status_updated_at ON message_read_status;
CREATE TRIGGER update_message_read_status_updated_at
  BEFORE UPDATE ON message_read_status
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column(); 
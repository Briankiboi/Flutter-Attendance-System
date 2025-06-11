-- Fix UUID columns in schedule_messages table
BEGIN;

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Modify the id column to use UUID
ALTER TABLE schedule_messages 
    ALTER COLUMN id SET DEFAULT uuid_generate_v4(),
    ALTER COLUMN id TYPE UUID USING (uuid_generate_v4()),
    ALTER COLUMN unit_id TYPE UUID USING (unit_id::UUID);

-- Update foreign key references
ALTER TABLE message_read_status
    DROP CONSTRAINT IF EXISTS message_read_status_message_id_fkey,
    ALTER COLUMN message_id TYPE UUID USING (message_id::UUID),
    ADD CONSTRAINT message_read_status_message_id_fkey 
        FOREIGN KEY (message_id) REFERENCES schedule_messages(id) ON DELETE CASCADE;

COMMIT; 
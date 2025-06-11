-- Safe migration to simplify schedule_messages table
BEGIN;

-- 1. First check and modify constraint columns if they exist
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'schedule_messages' 
        AND column_name = 'message_type'
    ) THEN
        ALTER TABLE schedule_messages ALTER COLUMN message_type DROP NOT NULL;
    END IF;
END $$;

-- 2. Add the new content column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'schedule_messages' 
        AND column_name = 'content'
    ) THEN
        ALTER TABLE schedule_messages ADD COLUMN content TEXT;
    END IF;
END $$;

-- 3. Copy existing message data to content column if message column exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'schedule_messages' 
        AND column_name = 'message'
    ) THEN
        UPDATE schedule_messages 
        SET content = message 
        WHERE content IS NULL AND message IS NOT NULL;
    END IF;
END $$;

-- 4. Make content column required
ALTER TABLE schedule_messages
    ALTER COLUMN content SET NOT NULL;

-- 5. Drop unused columns safely (only if they exist)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'schedule_messages' AND column_name = 'message') THEN
        ALTER TABLE schedule_messages DROP COLUMN message;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'schedule_messages' AND column_name = 'message_type') THEN
        ALTER TABLE schedule_messages DROP COLUMN message_type;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'schedule_messages' AND column_name = 'start_time') THEN
        ALTER TABLE schedule_messages DROP COLUMN start_time;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'schedule_messages' AND column_name = 'end_time') THEN
        ALTER TABLE schedule_messages DROP COLUMN end_time;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'schedule_messages' AND column_name = 'is_important') THEN
        ALTER TABLE schedule_messages DROP COLUMN is_important;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'schedule_messages' AND column_name = 'media_url') THEN
        ALTER TABLE schedule_messages DROP COLUMN media_url;
    END IF;
END $$;

-- 6. Update RLS policies to be simpler
DROP POLICY IF EXISTS "Lecturers can view their own messages" ON schedule_messages;
CREATE POLICY "Anyone can view messages" ON schedule_messages
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Lecturers can insert their own messages" ON schedule_messages;
CREATE POLICY "Authenticated users can insert messages" ON schedule_messages
    FOR INSERT TO authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "Lecturers can update their own messages" ON schedule_messages;
CREATE POLICY "Authenticated users can update messages" ON schedule_messages
    FOR UPDATE TO authenticated
    USING (true);

-- 7. Simplify read status table if device_info exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'message_read_status' 
        AND column_name = 'device_info'
    ) THEN
        ALTER TABLE message_read_status DROP COLUMN device_info;
    END IF;
END $$;

COMMIT; 
-- Safe migration to add content column
BEGIN;

-- 1. Add the new content column if it doesn't exist
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

-- 2. Copy existing message data to content column if message column exists
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

-- 3. Make content column required
ALTER TABLE schedule_messages
    ALTER COLUMN content SET NOT NULL;

-- 4. Update RLS policies to be simpler
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

COMMIT; 
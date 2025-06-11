-- Non-destructive migration to fix attendance_sessions table
DO $$ 
BEGIN
    -- Create attendance_sessions table if it doesn't exist
    CREATE TABLE IF NOT EXISTS attendance_sessions (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        lecturer_id UUID REFERENCES lecturers(id) NOT NULL,
        unit_id UUID NOT NULL,
        qr_code_url TEXT NOT NULL,
        qr_code_data JSONB NOT NULL,
        backup_key TEXT,
        start_time TIMESTAMP WITH TIME ZONE NOT NULL,
        end_time TIMESTAMP WITH TIME ZONE NOT NULL,
        is_active BOOLEAN DEFAULT true,
        session_data JSONB,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    -- Add backup_key column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'attendance_sessions' 
        AND column_name = 'backup_key'
    ) THEN
        ALTER TABLE attendance_sessions 
        ADD COLUMN backup_key TEXT;
    END IF;

    -- Check if old 'sessions' table exists and migrate data if needed
    IF EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_name = 'sessions'
    ) THEN
        -- Migrate data from sessions to attendance_sessions if not already migrated
        INSERT INTO attendance_sessions (
            lecturer_id,
            unit_id,
            qr_code_url,
            qr_code_data,
            backup_key,
            start_time,
            end_time,
            is_active,
            session_data,
            created_at,
            updated_at
        )
        SELECT 
            s.lecturer_id,
            s.unit_id,
            s.qr_code_url,
            s.qr_code_data::jsonb,
            s.backup_key,
            s.start_time,
            s.end_time,
            s.is_active,
            s.session_data::jsonb,
            s.created_at,
            s.updated_at
        FROM sessions s
        WHERE NOT EXISTS (
            SELECT 1 
            FROM attendance_sessions a 
            WHERE a.qr_code_data->>'session_id' = s.qr_code_data->>'session_id'
        );

        -- Create index on backup_key for faster lookups
        CREATE INDEX IF NOT EXISTS idx_attendance_sessions_backup_key 
        ON attendance_sessions(backup_key);

        -- Create index on session_data for JSON operations
        CREATE INDEX IF NOT EXISTS idx_attendance_sessions_session_data 
        ON attendance_sessions USING gin(session_data);
    END IF;
END $$; 
-- CAT System Migration SQL
-- This file contains all the necessary database changes for the CAT system

-- Enable required extensions (safe, won't fail if exists)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create enums only if they don't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mark_status') THEN
        CREATE TYPE mark_status AS ENUM ('draft', 'final', 'pending_review');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'cat_number') THEN
        CREATE TYPE cat_number AS ENUM ('CAT1', 'CAT2');
    END IF;
END $$;

-- Create lecturer_units table if not exists (safe)
CREATE TABLE IF NOT EXISTS lecturer_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lecturer_id UUID NOT NULL REFERENCES lecturers(id),
    unit_id UUID NOT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_lecturer_unit UNIQUE (lecturer_id, unit_id)
);

-- Create student_units table if not exists (safe)
CREATE TABLE IF NOT EXISTS student_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id),
    unit_id UUID NOT NULL,
    year TEXT,
    semester TEXT,
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_student_unit UNIQUE (student_id, unit_id, year, semester)
);

-- Enable RLS for unit assignment tables
ALTER TABLE lecturer_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_units ENABLE ROW LEVEL SECURITY;

-- Create indexes for unit assignments
CREATE INDEX IF NOT EXISTS idx_lecturer_units_lecturer_id ON lecturer_units(lecturer_id);
CREATE INDEX IF NOT EXISTS idx_lecturer_units_unit_id ON lecturer_units(unit_id);
CREATE INDEX IF NOT EXISTS idx_student_units_student_id ON student_units(student_id);
CREATE INDEX IF NOT EXISTS idx_student_units_unit_id ON student_units(unit_id);

-- Create CAT results table
CREATE TABLE IF NOT EXISTS cat_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID NOT NULL,
    student_id UUID NOT NULL REFERENCES students(id),
    lecturer_id UUID NOT NULL REFERENCES lecturers(id),
    cat_number cat_number NOT NULL,
    marks NUMERIC CHECK (marks >= 0 AND marks <= 100),
    status mark_status DEFAULT 'draft',
    comments TEXT,
    batch_id UUID,
    import_source TEXT,
    last_modified_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_cat_entry UNIQUE (unit_id, student_id, cat_number)
);

-- Create table for auto-save drafts
CREATE TABLE IF NOT EXISTS cat_result_drafts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cat_result_id UUID REFERENCES cat_results(id),
    unit_id UUID NOT NULL,
    student_id UUID NOT NULL REFERENCES students(id),
    lecturer_id UUID NOT NULL REFERENCES lecturers(id),
    cat_type cat_number NOT NULL,
    marks NUMERIC CHECK (marks >= 0 AND marks <= 100),
    auto_saved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create table for Excel imports
CREATE TABLE IF NOT EXISTS cat_excel_imports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lecturer_id UUID NOT NULL REFERENCES lecturers(id),
    unit_id UUID NOT NULL,
    file_path TEXT NOT NULL,
    status TEXT NOT NULL,
    processed_count INTEGER DEFAULT 0,
    total_count INTEGER DEFAULT 0,
    error_log JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE cat_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE cat_result_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cat_excel_imports ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance with large datasets
CREATE INDEX IF NOT EXISTS idx_cat_results_unit_id ON cat_results(unit_id);
CREATE INDEX IF NOT EXISTS idx_cat_results_student_id ON cat_results(student_id);
CREATE INDEX IF NOT EXISTS idx_cat_results_lecturer_id ON cat_results(lecturer_id);
CREATE INDEX IF NOT EXISTS idx_cat_results_batch_id ON cat_results(batch_id);
CREATE INDEX IF NOT EXISTS idx_cat_results_status ON cat_results(status);

-- Create indexes for drafts
CREATE INDEX IF NOT EXISTS idx_cat_drafts_result_id ON cat_result_drafts(cat_result_id);
CREATE INDEX IF NOT EXISTS idx_cat_drafts_unit_id ON cat_result_drafts(unit_id);
CREATE INDEX IF NOT EXISTS idx_cat_drafts_student_id ON cat_result_drafts(student_id);
CREATE INDEX IF NOT EXISTS idx_cat_drafts_lecturer_id ON cat_result_drafts(lecturer_id);

-- Create indexes for excel imports
CREATE INDEX IF NOT EXISTS idx_excel_imports_lecturer_id ON cat_excel_imports(lecturer_id);
CREATE INDEX IF NOT EXISTS idx_excel_imports_unit_id ON cat_excel_imports(unit_id);
CREATE INDEX IF NOT EXISTS idx_excel_imports_status ON cat_excel_imports(status);

-- Create indexes for search functionality
CREATE INDEX IF NOT EXISTS idx_users_name ON users USING gin(name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_email ON users USING gin(email gin_trgm_ops);

-- Policies for CAT results (safe, will drop if exists first)
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Lecturers can create CAT results" ON cat_results;
    DROP POLICY IF EXISTS "Lecturers can update their own CAT entries" ON cat_results;
    DROP POLICY IF EXISTS "Students can view their own CAT results" ON cat_results;
    DROP POLICY IF EXISTS "Lecturers can create drafts" ON cat_result_drafts;
    DROP POLICY IF EXISTS "Lecturers can view their drafts" ON cat_result_drafts;
    DROP POLICY IF EXISTS "Lecturers can view their assigned units" ON lecturer_units;
    DROP POLICY IF EXISTS "Students can view their registered units" ON student_units;
    DROP POLICY IF EXISTS "Lecturers can view units of their students" ON student_units;
END $$;

-- Now create policies (they won't fail since we dropped them if they existed)
CREATE POLICY "Lecturers can create CAT results"
ON cat_results FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM lecturers
        WHERE lecturers.id = cat_results.lecturer_id
        AND auth.uid() = lecturers.user_id
    )
);

CREATE POLICY "Lecturers can update their own CAT entries"
ON cat_results FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM lecturers
        WHERE lecturers.id = cat_results.lecturer_id
        AND auth.uid() = lecturers.user_id
    )
);

CREATE POLICY "Students can view their own CAT results"
ON cat_results FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM students s
        WHERE s.id = cat_results.student_id
        AND auth.uid() = s.user_id
    )
);

-- Policies for drafts
CREATE POLICY "Lecturers can create drafts"
ON cat_result_drafts FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM lecturers
        WHERE lecturers.id = cat_result_drafts.lecturer_id
        AND auth.uid() = lecturers.user_id
    )
);

CREATE POLICY "Lecturers can view their drafts"
ON cat_result_drafts FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM lecturers
        WHERE lecturers.id = cat_result_drafts.lecturer_id
        AND auth.uid() = lecturers.user_id
    )
);

-- Policies for lecturer_units
CREATE POLICY "Lecturers can view their assigned units"
ON lecturer_units FOR SELECT TO authenticated
USING (
    auth.uid() IN (
        SELECT user_id FROM lecturers WHERE id = lecturer_units.lecturer_id
    )
);

-- Policies for student_units
CREATE POLICY "Students can view their registered units"
ON student_units FOR SELECT TO authenticated
USING (
    auth.uid() IN (
        SELECT user_id FROM students WHERE id = student_units.student_id
    )
);

CREATE POLICY "Lecturers can view units of their students"
ON student_units FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM lecturer_units lu
        WHERE lu.unit_id = student_units.unit_id
        AND EXISTS (
            SELECT 1 FROM lecturers l
            WHERE l.id = lu.lecturer_id
            AND l.user_id = auth.uid()
        )
    )
);

-- Function to auto-save draft
CREATE OR REPLACE FUNCTION auto_save_mark_draft(
    p_unit_id UUID,
    p_student_id UUID,
    p_lecturer_id UUID,
    p_marks NUMERIC
) RETURNS UUID AS $$
DECLARE
    v_draft_id UUID;
    v_result_id UUID;
BEGIN
    -- Get existing result id if any
    SELECT id INTO v_result_id
    FROM cat_results
    WHERE unit_id = p_unit_id
    AND student_id = p_student_id;

    -- Insert or update draft
    INSERT INTO cat_result_drafts (
        cat_result_id,
        unit_id,
        student_id,
        lecturer_id,
        marks
    ) VALUES (
        v_result_id,
        p_unit_id,
        p_student_id,
        p_lecturer_id,
        p_marks
    )
    ON CONFLICT (cat_result_id, unit_id, student_id)
    DO UPDATE SET
        marks = EXCLUDED.marks,
        auto_saved_at = NOW()
    RETURNING id INTO v_draft_id;

    RETURN v_draft_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to commit drafts to final marks
CREATE OR REPLACE FUNCTION commit_mark_drafts(
    p_unit_id UUID,
    p_lecturer_id UUID
) RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    affected_rows INTEGER
) AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    -- Move drafts to final marks
    WITH moved_drafts AS (
        INSERT INTO cat_results (
            unit_id,
            student_id,
            lecturer_id,
            marks,
            status,
            last_modified_by
        )
        SELECT 
            d.unit_id,
            d.student_id,
            d.lecturer_id,
            d.marks,
            'final'::mark_status,
            auth.uid()
        FROM cat_result_drafts d
        WHERE d.unit_id = p_unit_id
        AND d.lecturer_id = p_lecturer_id
        ON CONFLICT (unit_id, student_id)
        DO UPDATE SET
            marks = EXCLUDED.marks,
            status = 'final',
            updated_at = NOW(),
            last_modified_by = EXCLUDED.last_modified_by
        RETURNING *
    )
    SELECT COUNT(*) INTO v_count FROM moved_drafts;

    -- Clean up committed drafts
    DELETE FROM cat_result_drafts
    WHERE unit_id = p_unit_id
    AND lecturer_id = p_lecturer_id;

    RETURN QUERY SELECT true, 'Successfully committed ' || v_count || ' marks', v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get grid view data with both CATs
CREATE OR REPLACE FUNCTION get_marks_grid_data(
    p_unit_id UUID,
    p_lecturer_id UUID
) RETURNS TABLE (
    student_id UUID,
    email TEXT,
    student_name TEXT,
    cat1_marks NUMERIC,
    cat2_marks NUMERIC,
    cat1_status mark_status,
    cat2_status mark_status,
    has_draft BOOLEAN,
    last_modified TIMESTAMP WITH TIME ZONE,
    modified_by TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id as student_id,
        u.email,
        u.name as student_name,
        cat1.marks as cat1_marks,
        cat2.marks as cat2_marks,
        cat1.status as cat1_status,
        cat2.status as cat2_status,
        (crd.id IS NOT NULL) as has_draft,
        GREATEST(cat1.updated_at, cat2.updated_at) as last_modified,
        um.name as modified_by
    FROM students s
    JOIN users u ON u.id = s.user_id
    LEFT JOIN cat_results cat1 ON 
        cat1.student_id = s.id AND 
        cat1.unit_id = p_unit_id AND 
        cat1.cat_number = 'CAT1'
    LEFT JOIN cat_results cat2 ON 
        cat2.student_id = s.id AND 
        cat2.unit_id = p_unit_id AND 
        cat2.cat_number = 'CAT2'
    LEFT JOIN cat_result_drafts crd ON 
        crd.student_id = s.id AND 
        crd.unit_id = p_unit_id
    LEFT JOIN users um ON um.id = COALESCE(cat1.last_modified_by, cat2.last_modified_by)
    WHERE EXISTS (
        SELECT 1 FROM student_units su
        WHERE su.student_id = s.id
        AND su.unit_id = p_unit_id
    )
    ORDER BY u.email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_cat_results_updated_at
    BEFORE UPDATE ON cat_results
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_excel_imports_updated_at
    BEFORE UPDATE ON cat_excel_imports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create helper function to get student results
CREATE OR REPLACE FUNCTION get_student_results(p_student_id UUID)
RETURNS TABLE (
    unit_id UUID,
    unit_name TEXT,
    marks NUMERIC,
    lecturer_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cr.unit_id,
        u.name as unit_name,
        cr.marks,
        l.name as lecturer_name,
        cr.created_at
    FROM cat_results cr
    JOIN units u ON u.id = cr.unit_id
    JOIN lecturers l ON l.id = cr.lecturer_id
    WHERE cr.student_id = p_student_id
    ORDER BY cr.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create helper function to get unit results
CREATE OR REPLACE FUNCTION get_unit_results(p_unit_id UUID)
RETURNS TABLE (
    student_id UUID,
    student_name TEXT,
    marks NUMERIC,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cr.student_id,
        u.name as student_name,
        cr.marks,
        cr.created_at
    FROM cat_results cr
    JOIN students s ON s.id = cr.student_id
    JOIN users u ON u.id = s.user_id
    WHERE cr.unit_id = p_unit_id
    ORDER BY u.name ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create helper function for bulk mark entry
CREATE OR REPLACE FUNCTION bulk_insert_marks(
    p_lecturer_id UUID,
    p_unit_id UUID,
    p_cat_number cat_number,
    p_marks JSONB
) RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    affected_rows INTEGER
) AS $$
DECLARE
    v_count INTEGER := 0;
    v_batch_id UUID := uuid_generate_v4();
BEGIN
    -- Validate lecturer access to unit
    IF NOT EXISTS (
        SELECT 1 FROM lecturer_units
        WHERE lecturer_id = p_lecturer_id
        AND unit_id = p_unit_id
    ) THEN
        RETURN QUERY SELECT false, 'Unauthorized access to unit', 0;
        RETURN;
    END IF;

    -- Insert marks
    INSERT INTO cat_results (
        unit_id,
        student_id,
        lecturer_id,
        cat_number,
        marks,
        batch_id
    )
    SELECT
        p_unit_id,
        (value->>'student_id')::UUID,
        p_lecturer_id,
        p_cat_number,
        (value->>'marks')::NUMERIC,
        v_batch_id
    FROM jsonb_array_elements(p_marks)
    ON CONFLICT (unit_id, student_id, cat_number)
    DO UPDATE SET
        marks = EXCLUDED.marks,
        updated_at = NOW();

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN QUERY SELECT true, 'Successfully inserted/updated ' || v_count || ' marks', v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search students in a unit
CREATE OR REPLACE FUNCTION search_unit_students(
    p_unit_id UUID,
    p_search_term TEXT
) RETURNS TABLE (
    student_id UUID,
    email TEXT,
    student_name TEXT,
    cat1_marks NUMERIC,
    cat2_marks NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id as student_id,
        u.email,
        u.name as student_name,
        cat1.marks as cat1_marks,
        cat2.marks as cat2_marks
    FROM students s
    JOIN users u ON u.id = s.user_id
    LEFT JOIN cat_results cat1 ON 
        cat1.student_id = s.id AND 
        cat1.unit_id = p_unit_id AND 
        cat1.cat_number = 'CAT1'
    LEFT JOIN cat_results cat2 ON 
        cat2.student_id = s.id AND 
        cat2.unit_id = p_unit_id AND 
        cat2.cat_number = 'CAT2'
    WHERE (
        u.name ILIKE '%' || p_search_term || '%'
        OR u.email ILIKE '%' || p_search_term || '%'
    )
    ORDER BY u.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get registered students for a unit
CREATE OR REPLACE FUNCTION get_registered_students(p_unit_id UUID)
RETURNS TABLE (
    student_id UUID,
    student_name TEXT,
    email TEXT,
    registration_number TEXT,
    registration_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id as student_id,
        u.name as student_name,
        u.email,
        s.registration_number,
        su.registration_date
    FROM student_units su
    JOIN students s ON s.id = su.student_id
    JOIN users u ON u.id = s.user_id
    WHERE su.unit_id = p_unit_id
    ORDER BY u.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
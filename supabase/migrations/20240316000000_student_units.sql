-- Drop existing table if exists
DROP TABLE IF EXISTS student_units CASCADE;

-- Create student_units table
CREATE TABLE IF NOT EXISTS student_units (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    student_id uuid NOT NULL REFERENCES students(id),
    unit_id uuid NOT NULL REFERENCES units(id),
    year text NOT NULL,
    semester text NOT NULL,
    status text DEFAULT 'registered' CHECK (status IN ('registered', 'dropped', 'completed')),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(student_id, unit_id, year, semester)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_student_units_student_id ON student_units(student_id);
CREATE INDEX IF NOT EXISTS idx_student_units_unit_id ON student_units(unit_id); 
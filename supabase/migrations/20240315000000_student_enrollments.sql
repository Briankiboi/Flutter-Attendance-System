-- Create student_unit_enrollments table
CREATE TABLE student_unit_enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id),
    unit_code TEXT NOT NULL,
    department TEXT NOT NULL,
    course TEXT NOT NULL,
    year TEXT NOT NULL,
    semester TEXT NOT NULL,
    enrollment_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, unit_code, semester)
);

-- Create indexes for enrollment lookups
CREATE INDEX idx_enrollments_student ON student_unit_enrollments(student_id);
CREATE INDEX idx_enrollments_unit ON student_unit_enrollments(unit_code);
CREATE INDEX idx_enrollments_active ON student_unit_enrollments(is_active);

-- Create function to verify student enrollment
CREATE OR REPLACE FUNCTION verify_student_enrollment(
    p_student_id UUID,
    p_unit_code TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM student_unit_enrollments
        WHERE student_id = p_student_id
        AND unit_code = p_unit_code
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql; 
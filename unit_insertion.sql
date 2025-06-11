-- First ensure departments exist
INSERT INTO departments (name) VALUES
('Engineering'),
('Computer Science'),
('Business'),
('Education')
ON CONFLICT (name) DO NOTHING;

-- Insert courses with correct department references
INSERT INTO courses (name, department_id) VALUES
('Computer Science', (SELECT id FROM departments WHERE name = 'Computer Science')),
('Civil Engineering', (SELECT id FROM departments WHERE name = 'Engineering')),
('Business Administration', (SELECT id FROM departments WHERE name = 'Business')),
('Math/bio', (SELECT id FROM departments WHERE name = 'Education'))
ON CONFLICT (name, department_id) DO NOTHING;

-- Now insert units with correct course relationships
INSERT INTO units (code, name, course_id, year, semester) VALUES
-- Computer Science Units
('CS111', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science'), '1', '1'),
('CS112', 'Computer Organization', (SELECT id FROM courses WHERE name = 'Computer Science'), '1', '1'),
('CS121', 'Data Structures and Algorithms', (SELECT id FROM courses WHERE name = 'Computer Science'), '1', '2'),
('CS122', 'Discrete Mathematics', (SELECT id FROM courses WHERE name = 'Computer Science'), '1', '2'),
('CS211', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Computer Science'), '2', '1'),
('CS212', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science'), '2', '1'),
('CS221', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science'), '2', '2'),
('CS222', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science'), '2', '2'),
('CS311', 'Software Engineering', (SELECT id FROM courses WHERE name = 'Computer Science'), '3', '1'),
('CS312', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science'), '3', '1'),
('CS321', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science'), '3', '2'),
('CS322', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science'), '3', '2'),
('CS411', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science'), '4', '1'),
('CS412', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science'), '4', '1'),
('CS421', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science'), '4', '2'),
('CS422', 'Project Management', (SELECT id FROM courses WHERE name = 'Computer Science'), '4', '2'),

-- Civil Engineering Units
('CE111', 'Engineering Mathematics I', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '1', '1'),
('CE112', 'Engineering Drawing', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '1', '1'),
('CE121', 'Engineering Mathematics II', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '1', '2'),
('CE122', 'Structural Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '1', '2'),
('CE211', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '2', '1'),
('CE212', 'Construction Materials', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '2', '1'),
('CE221', 'Soil Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '2', '2'),
('CE222', 'Surveying', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '2', '2'),
('CE311', 'Structural Analysis', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '3', '1'),
('CE312', 'Transportation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '3', '1'),
('CE321', 'Foundation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '3', '2'),
('CE322', 'Environmental Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '3', '2'),
('CE411', 'Construction Management', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '4', '1'),
('CE412', 'Steel Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '4', '1'),
('CE421', 'Concrete Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '4', '2'),
('CE422', 'Highway Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering'), '4', '2'),

-- Business Administration Units
('BA111', 'Principles of Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '1', '1'),
('BA112', 'Business Mathematics', (SELECT id FROM courses WHERE name = 'Business Administration'), '1', '1'),
('BA121', 'Financial Accounting', (SELECT id FROM courses WHERE name = 'Business Administration'), '1', '2'),
('BA122', 'Business Communication', (SELECT id FROM courses WHERE name = 'Business Administration'), '1', '2'),
('BA211', 'Marketing Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '2', '1'),
('BA212', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '2', '1'),
('BA221', 'Business Law', (SELECT id FROM courses WHERE name = 'Business Administration'), '2', '2'),
('BA222', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '2', '2'),
('BA311', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '3', '1'),
('BA312', 'International Business', (SELECT id FROM courses WHERE name = 'Business Administration'), '3', '1'),
('BA321', 'Entrepreneurship', (SELECT id FROM courses WHERE name = 'Business Administration'), '3', '2'),
('BA322', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business Administration'), '3', '2'),
('BA411', 'Project Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '4', '1'),
('BA412', 'Risk Management', (SELECT id FROM courses WHERE name = 'Business Administration'), '4', '1'),
('BA421', 'Business Analytics', (SELECT id FROM courses WHERE name = 'Business Administration'), '4', '2'),
('BA422', 'Digital Business', (SELECT id FROM courses WHERE name = 'Business Administration'), '4', '2'),

-- Math/Bio Units
('MB111', 'Calculus I', (SELECT id FROM courses WHERE name = 'Math/bio'), '1', '1'),
('MB112', 'General Biology', (SELECT id FROM courses WHERE name = 'Math/bio'), '1', '1'),
('MB121', 'Calculus II', (SELECT id FROM courses WHERE name = 'Math/bio'), '1', '2'),
('MB122', 'Cell Biology', (SELECT id FROM courses WHERE name = 'Math/bio'), '1', '2'),
('MB211', 'Linear Algebra', (SELECT id FROM courses WHERE name = 'Math/bio'), '2', '1'),
('MB212', 'Genetics', (SELECT id FROM courses WHERE name = 'Math/bio'), '2', '1'),
('MB221', 'Differential Equations', (SELECT id FROM courses WHERE name = 'Math/bio'), '2', '2'),
('MB222', 'Molecular Biology', (SELECT id FROM courses WHERE name = 'Math/bio'), '2', '2'),
('MB311', 'Statistics', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '1'),
('MB312', 'Ecology', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '1'),
('MB321', 'Complex Analysis', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '2'),
('MB322', 'Evolution', (SELECT id FROM courses WHERE name = 'Math/bio'), '3', '2'),
('MB411', 'Abstract Algebra', (SELECT id FROM courses WHERE name = 'Math/bio'), '4', '1'),
('MB412', 'Biotechnology', (SELECT id FROM courses WHERE name = 'Math/bio'), '4', '1'),
('MB421', 'Number Theory', (SELECT id FROM courses WHERE name = 'Math/bio'), '4', '2'),
('MB422', 'Bioinformatics', (SELECT id FROM courses WHERE name = 'Math/bio'), '4', '2')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    year = EXCLUDED.year,
    semester = EXCLUDED.semester,
    updated_at = NOW();

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_units_course_year_sem ON units(course_name, year, semester);

-- Refresh the materialized view if exists
REFRESH MATERIALIZED VIEW IF EXISTS units_view; 
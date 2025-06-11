-- First ensure departments exist (these are already in your DB from the screenshot)
INSERT INTO departments (name) VALUES
('Engineering'),
('Computer Science'),
('Business'),
('Education')
ON CONFLICT (name) DO NOTHING;

-- Insert courses with correct department references (these match your screenshot)
INSERT INTO courses (name, department_id) VALUES
('Computer Science', (SELECT id FROM departments WHERE name = 'Computer Science')),
('Civil Engineering', (SELECT id FROM departments WHERE name = 'Engineering')),
('Business Administration', (SELECT id FROM departments WHERE name = 'Business')),
('Math/bio', (SELECT id FROM departments WHERE name = 'Education'))
ON CONFLICT (name, department_id) DO NOTHING;

-- Now insert units with correct course relationships
INSERT INTO units (code, name, course_id) VALUES
-- Computer Science Units
('CS111', 'Introduction to Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS112', 'Computer Organization', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS121', 'Data Structures and Algorithms', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS122', 'Discrete Mathematics', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS211', 'Object-Oriented Programming', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS212', 'Database Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS221', 'Operating Systems', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS222', 'Computer Networks', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS311', 'Software Engineering', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS312', 'Artificial Intelligence', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS321', 'Web Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS322', 'Mobile Development', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS411', 'Cloud Computing', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS412', 'Machine Learning', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS421', 'Cybersecurity', (SELECT id FROM courses WHERE name = 'Computer Science')),
('CS422', 'Project Management', (SELECT id FROM courses WHERE name = 'Computer Science')),

-- Civil Engineering Units
('CE111', 'Engineering Mathematics I', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE112', 'Engineering Drawing', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE121', 'Engineering Mathematics II', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE122', 'Structural Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE211', 'Fluid Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE212', 'Construction Materials', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE221', 'Soil Mechanics', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE222', 'Surveying', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE311', 'Structural Analysis', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE312', 'Transportation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE321', 'Foundation Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE322', 'Environmental Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE411', 'Construction Management', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE412', 'Steel Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE421', 'Concrete Structures', (SELECT id FROM courses WHERE name = 'Civil Engineering')),
('CE422', 'Highway Engineering', (SELECT id FROM courses WHERE name = 'Civil Engineering')),

-- Business Administration Units
('BA111', 'Principles of Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA112', 'Business Mathematics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA121', 'Financial Accounting', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA122', 'Business Communication', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA211', 'Marketing Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA212', 'Human Resource Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA221', 'Business Law', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA222', 'Operations Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA311', 'Strategic Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA312', 'International Business', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA321', 'Entrepreneurship', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA322', 'Business Ethics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA411', 'Project Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA412', 'Risk Management', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA421', 'Business Analytics', (SELECT id FROM courses WHERE name = 'Business Administration')),
('BA422', 'Digital Business', (SELECT id FROM courses WHERE name = 'Business Administration')),

-- Math/Bio Units
('MB111', 'Calculus I', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB112', 'General Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB121', 'Calculus II', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB122', 'Cell Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB211', 'Linear Algebra', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB212', 'Genetics', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB221', 'Differential Equations', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB222', 'Molecular Biology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB311', 'Statistics', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB312', 'Ecology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB321', 'Complex Analysis', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB322', 'Evolution', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB411', 'Abstract Algebra', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB412', 'Biotechnology', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB421', 'Number Theory', (SELECT id FROM courses WHERE name = 'Math/bio')),
('MB422', 'Bioinformatics', (SELECT id FROM courses WHERE name = 'Math/bio'))
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    course_id = EXCLUDED.course_id,
    updated_at = NOW();
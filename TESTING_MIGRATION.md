# Testing the Supabase Migration

This guide outlines how to test the new Supabase implementation for the login screen and student dashboard.

## Prerequisites

Before you begin testing, make sure you have:

1. Created the Supabase tables using the schema in `supabase_schema.sql`
2. Created a `.env` file with your Supabase credentials:

```
SUPABASE_URL=https://vaaqnexxyzzmjwquhpry.supabase.co
SUPABASE_ANON_KEY=your_actual_anon_key_here
```

3. Added test users to your Supabase database:
   - You can add a user manually through the Supabase dashboard
   - Or use the API to create test users (see below)

## Adding Test Users to Supabase

You can add test users using the Supabase dashboard or execute the following SQL in the Supabase SQL Editor:

```sql
-- Insert a test user
INSERT INTO users (email, user_type, name, password)
VALUES ('test@student.tharaka.ac.ke', 'student', 'Test Student', 'password123');

-- Get the inserted user's ID
WITH new_user AS (
  SELECT id FROM users WHERE email = 'test@student.tharaka.ac.ke'
)
-- Insert student details
INSERT INTO students (user_id, department, course, year, semester)
SELECT id, 'Computer Science', 'BSc Computer Science', '4', '2'
FROM new_user;

-- Insert user preferences
WITH new_user AS (
  SELECT id FROM users WHERE email = 'test@student.tharaka.ac.ke'
)
INSERT INTO user_preferences (user_id, dark_mode_enabled, has_completed_onboarding)
SELECT id, false, true
FROM new_user;
```

## Testing the Login Screen

1. Run the application with:
   ```
   flutter run
   ```

2. Navigate to the student login screen

3. Test with valid credentials:
   - Email: `test@student.tharaka.ac.ke`
   - Password: `password123`
   - Expected outcome: Successful login, redirection to verification screen

4. Test with invalid credentials:
   - Email: `test@student.tharaka.ac.ke`
   - Password: `wrongpassword`
   - Expected outcome: Error message "Invalid credentials"

5. Test with non-existent user:
   - Email: `nonexistent@student.tharaka.ac.ke`
   - Password: `password123`
   - Expected outcome: Error message indicating the user doesn't exist

## Testing the Student Dashboard

1. Login with valid credentials
2. Check that student data is loaded correctly:
   - Verify name, email, department, course, year, and semester are displayed
   - Verify dark mode preference is saved when toggled

3. Test dark mode toggle:
   - Toggle dark mode on
   - Navigate away from dashboard and back
   - Expected outcome: Dark mode setting should persist

4. Test profile picture upload:
   - Attempt to upload a profile picture
   - Navigate away and back
   - Expected outcome: Profile picture should be visible and persist

5. Test logout:
   - Sign out of the account
   - Try to navigate back to the dashboard
   - Expected outcome: Should be redirected to login screen

## Testing QR Code Scanning Functionality

1. Create a test session in Supabase:

```sql
-- First get the lecturer ID (you'll need to create a lecturer first)
WITH test_lecturer AS (
  SELECT id FROM lecturers LIMIT 1
)
-- Insert a test session
INSERT INTO sessions (lecturer_id, unit_code, unit_name, date, start_time, end_time, location, session_data)
SELECT 
  id, 
  'CS400', 
  'Advanced Programming', 
  TO_CHAR(NOW(), 'YYYY-MM-DD'), 
  TO_CHAR(NOW(), 'HH24:MI'), 
  TO_CHAR(NOW() + INTERVAL '2 HOURS', 'HH24:MI'),
  'Room 101',
  jsonb_build_object(
    'unitCode', 'CS400',
    'unitName', 'Advanced Programming',
    'date', TO_CHAR(NOW(), 'YYYY-MM-DD'),
    'startTime', TO_CHAR(NOW(), 'HH24:MI'),
    'endTime', TO_CHAR(NOW() + INTERVAL '2 HOURS', 'HH24:MI'),
    'location', 'Room 101',
    'year', '4',
    'semester', '2',
    'course', 'BSc Computer Science',
    'timestamp', extract(epoch from now()) * 1000
  )
FROM test_lecturer;
```

2. Login as a student
3. Check for the QR notification on the dashboard
4. Navigate to the Scan QR screen
5. Test scanning a QR code (you'll need to generate one for testing)

## Troubleshooting

If you encounter issues during testing:

1. Check the console logs for error messages
2. Verify your Supabase credentials in the `.env` file
3. Verify that the Supabase schema is set up correctly
4. Check that RLS (Row-Level Security) policies are allowing proper access

## Reporting Issues

If you find any issues during testing:

1. Document the steps to reproduce
2. Note any error messages
3. Describe the expected vs. actual behavior
4. File an issue in the project repository 
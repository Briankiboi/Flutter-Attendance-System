# CAT Marks Entry - Database Relationships Reference

## 1. Lecturer-Unit Assignment
- **lecturer_assigned_units**: Contains `lecturer_id`, `unit_code` (text), `unit_id` (uuid), and other metadata.
- **lecturer_units**: Contains `lecturer_id` (uuid), `unit_id` (uuid), and is the main table for linking lecturers to units.
- **units**: Contains `id` (uuid), `code` (text, e.g., 'CE422'), `name`, and other metadata.
- **lecturers**: Contains `id` (uuid), `user_id` (uuid), `name`.

## 2. Student-Unit Registration
- **student_units**: Contains `student_id` (uuid), `unit_id` (uuid), and other metadata.
- **students**: Contains `id` (uuid), `user_id` (uuid), `department`, `course`, etc.
- **users**: Contains `id` (uuid), `email`, `name`, etc.

## 3. Key Relationships
- To get all students for a unit:
  1. Find the `unit_id` for the desired unit (e.g., 'CE422') from the `units` table.
  2. Query `student_units` for all rows with that `unit_id`.
  3. For each `student_id` in `student_units`, join to `students` to get `user_id`.
  4. For each `user_id`, join to `users` to get `email` and `name`.
- To get all units for a lecturer:
  1. Use `lecturer_units` to find all `unit_id` for a given `lecturer_id`.
  2. Join to `units` to get the `code` and `name`.

## 4. Example: Find Students for CE422
- Get `unit_id` for 'CE422' from `units` table (e.g., `1c5eca7e-27aa-4f86-b3c0-f3e2650bf668`).
- Query `student_units` where `unit_id = '1c5eca7e-27aa-4f86-b3c0-f3e2650bf668'`.
- For each result, get `student_id` and join to `students`.
- For each student, get `user_id` and join to `users` for email/name.

## 5. Notes
- Always use `unit_id` (uuid) for joins, not `unit_code` (text).
- The `users` table is the source of email and name for both students and lecturers.
- The `cat_results` table uses `unit_id`, `student_id`, and `lecturer_id` as foreign keys.

---
This file is a reference for correct table relationships and queries for CAT marks entry. Use it to debug and implement future features. 
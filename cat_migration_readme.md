# CAT Marks Implementation Documentation

This document provides a detailed overview of the CAT marks entry and management system implementation in our Flutter application.

## 📁 Database Schema Design

### Tables Overview

#### 1. cat_results
```sql
CREATE TABLE cat_results (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  unit_id UUID REFERENCES units(id),
  student_id UUID REFERENCES students(id),
  lecturer_id UUID REFERENCES lecturers(id),
  cat_number VARCHAR(4) CHECK (cat_number IN ('CAT1', 'CAT2')),
  marks DECIMAL(5,2) CHECK (marks >= 0 AND marks <= 30),
  status VARCHAR(10) DEFAULT 'draft' CHECK (status IN ('draft', 'final', 'pending')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster queries
CREATE INDEX idx_cat_results_unit_student ON cat_results(unit_id, student_id);
CREATE INDEX idx_cat_results_lecturer ON cat_results(lecturer_id);
```

#### 2. lecturer_assigned_units
```sql
CREATE TABLE lecturer_assigned_units (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  lecturer_id UUID REFERENCES lecturers(id),
  unit_id UUID REFERENCES units(id),
  unit_code VARCHAR(10) NOT NULL,
  unit_name VARCHAR(100) NOT NULL,
  department VARCHAR(100) NOT NULL,
  course_name VARCHAR(100) NOT NULL,
  year INTEGER NOT NULL,
  semester INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(lecturer_id, unit_id)
);

-- Index for faster unit lookups
CREATE INDEX idx_lecturer_units ON lecturer_assigned_units(lecturer_id);
```

### Key Relationships
- `cat_results.unit_id` → `units.id`: Links CAT marks to specific units
- `cat_results.student_id` → `students.id`: Links marks to students
- `cat_results.lecturer_id` → `lecturers.id`: Tracks which lecturer entered marks
- `lecturer_assigned_units`: Maps lecturers to their assigned units

## 🔗 Supabase Integration

### Data Flow Architecture
```
Flutter App ←→ Supabase Client ←→ Supabase Backend ←→ PostgreSQL Database
```

### Key Operations

#### 1. Fetching Assigned Units
```dart
final units = await _supabase
  .from('lecturer_assigned_units')
  .select('''
    unit_code,
    unit_name,
    unit_id,
    department,
    course_name,
    year,
    semester
  ''')
  .eq('lecturer_id', lecturerId)
  .order('unit_code', ascending: true);
```

#### 2. Saving CAT Marks
```dart
// Check existing record
final existingRecords = await _supabase
  .from('cat_results')
  .select()
  .eq('unit_id', unitId)
  .eq('student_id', studentId)
  .eq('cat_number', catType)
  .order('updated_at', ascending: false)
  .limit(1);

// Update or Insert logic
if (existingRecord != null) {
  await _supabase
    .from('cat_results')
    .update({
      'marks': mark,
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    })
    .eq('id', existingRecord['id']);
} else {
  await _supabase
    .from('cat_results')
    .insert({
      'unit_id': unitId,
      'student_id': studentId,
      'lecturer_id': lecturerId,
      'cat_number': catType,
      'marks': mark,
      'status': 'draft'
    });
}
```

## 🧩 CAT Entry Page Flow

### 1. Page Initialization
- Load lecturer profile
- Fetch assigned units
- Initialize state variables for CAT type selection

### 2. Unit Selection
- Display dropdown with assigned units
- On unit selection:
  - Clear existing student data
  - Fetch enrolled students
  - Load any existing CAT marks

### 3. Mark Entry Interface
- Grid layout showing:
  - Student name
  - Registration number
  - Mark input field
  - Status indicator
- Real-time validation:
  - Marks between 0-30
  - Only numbers allowed
  - Auto-save on valid input

### 4. Mark Management
- Draft vs Final states
- Bulk finalization option
- PDF report generation

## ✅ Key Features Implemented

### 1. Mark Entry
- Individual mark entry with validation
- Auto-save functionality
- Status tracking (draft/final)

### 2. Data Management
- Efficient data loading with pagination
- Real-time updates
- Data persistence

### 3. PDF Report Generation
- Professional layout with university branding
- Multi-page support for large datasets
- Summary statistics
- Proper pagination

## 🔄 Reusable Components

### 1. Data Fetching Layer
```dart
class CatService {
  Future<List<Map<String, dynamic>>> getUnitStudents(String unitId) async {
    // Reusable student fetching logic
  }
  
  Future<void> finalizeMarks(String unitId, String lecturerId, CatType catType) async {
    // Reusable mark finalization logic
  }
}
```

### 2. UI Components
- `CatGridWidget`: Reusable grid for displaying student data
- `CatSearchField`: Reusable search component
- PDF generation logic

## 📌 Next Steps

### Immediate Tasks
1. Implement student-side CAT marks viewing page
   - Use similar data fetching patterns
   - Implement read-only view of marks
   - Add filters for CAT1/CAT2

### Future Extensions
- Schedule management using similar patterns
- QR code attendance system integration
- Marks notification system

## ⚠️ Important Notes

1. Data Validation
   - Always validate marks (0-30 range)
   - Check user permissions
   - Verify unit assignments

2. Error Handling
   - Network errors
   - Invalid data
   - Concurrent updates

3. Performance
   - Pagination for large datasets
   - Efficient data loading
   - Proper indexing

## SQL Scripts Used

### Create Indexes
```sql
-- Improve CAT marks query performance
CREATE INDEX IF NOT EXISTS idx_cat_marks_lookup 
ON cat_results (unit_id, student_id, cat_number);

-- Improve unit assignment lookups
CREATE INDEX IF NOT EXISTS idx_unit_assignments 
ON lecturer_assigned_units (lecturer_id, unit_id);
```

### Status Update Function
```sql
-- Function to update mark status
CREATE OR REPLACE FUNCTION update_cat_mark_status()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for automatic timestamp updates
CREATE TRIGGER cat_mark_status_update
BEFORE UPDATE ON cat_results
FOR EACH ROW
EXECUTE FUNCTION update_cat_mark_status();
```

This implementation serves as a template for other similar features in the application, particularly for:
- Schedule management
- Attendance tracking
- Student performance monitoring
- Mark notifications

The modular approach and clear separation of concerns make it easy to adapt this pattern for other features while maintaining consistency across the application. 
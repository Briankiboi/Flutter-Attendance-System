# final_project

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# QR Code Attendance System with Location Verification

## Current System Features
- ✅ QR Code Generation by Lecturers
- ✅ Basic QR Code Scanning by Students
- ✅ Backup Key System
- ✅ Session Management
- ✅ Unit Registration Verification
- ✅ Student Authentication

## Planned Location-Based Enhancements

### Database Schema Updates

#### 1. `attendance_sessions` Table
```sql
CREATE TABLE attendance_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lecturer_id UUID REFERENCES lecturers(id),
    unit_code TEXT NOT NULL,
    qr_code_url TEXT,
    qr_code_data JSONB,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    backup_key TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    radius_meters INTEGER,
    location_required BOOLEAN DEFAULT true
);

-- Add index for faster queries
CREATE INDEX idx_active_sessions ON attendance_sessions(is_active, unit_code);
```

#### 2. `attendance_records` Table
```sql
CREATE TABLE attendance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES attendance_sessions(id),
    student_id UUID REFERENCES students(id),
    marked_at TIMESTAMPTZ DEFAULT NOW(),
    attendance_method TEXT, -- 'QR_CODE' or 'BACKUP_KEY'
    student_latitude DECIMAL(10, 8),
    student_longitude DECIMAL(11, 8),
    distance_meters DECIMAL(10, 2),
    is_within_radius BOOLEAN,
    device_info JSONB
);
```

### Flow Diagram

```
Lecturer Side (Create QR)
------------------------
1. Create QR Code
2. Set Location Parameters
3. Save to attendance_sessions
   - Session Details
   - Location Details
   - Time Window
   - Active Status

Student Side (Scan QR)
---------------------
1. Scan QR/Enter Backup Key
2. Verify:
   - Unit Registration
   - Session Active Status
   - Time Window
   - Location Match
3. Record Attendance
```

### Validation Checks

#### Time-based Validation
- Server-side timestamp comparison
- Session start/end time validation
- Automatic session deactivation
- Rate limiting for multiple attempts

#### Location Validation
- Haversine distance calculation
- Configurable radius check
- GPS accuracy verification
- Mock location detection

#### Unit Registration
- Student enrollment verification
- Unit schedule matching
- Semester/academic year validation

### Security Measures

1. **QR Code Security**
   - Encrypted session data
   - Time-based expiration
   - Single-use validation

2. **Location Security**
   - GPS spoofing detection
   - Accuracy threshold checks
   - Server-side validation

3. **Session Security**
   - Real-time status updates
   - Automatic timeout
   - Device fingerprinting

### Implementation Status

#### Completed
- ✅ Basic QR generation
- ✅ QR scanning interface
- ✅ Session management
- ✅ Backup key system
- ✅ Student authentication

#### In Progress
- 🟡 Location validation
- 🟡 Time-based expiration
- 🟡 GPS integration
- 🟡 Distance calculation

#### Pending
- ⭕ Mock location detection
- ⭕ Advanced security measures
- ⭕ Offline support
- ⭕ Analytics dashboard

### Usage Flow

1. **Lecturer Creates Session**
   ```
   Create QR Code
   └── Set Parameters
       ├── Unit Details
       ├── Time Window
       ├── Location
       └── Radius
   ```

2. **Student Marks Attendance**
   ```
   Scan QR/Enter Key
   └── Validation Checks
       ├── Unit Registration
       ├── Time Window
       ├── Location
       └── Previous Attendance
   ```

3. **System Verification**
   ```
   Validate Request
   └── Check
       ├── Session Active
       ├── Time Valid
       ├── Location Match
       └── Student Eligible
   ```

### Error Handling

- Invalid location data
- Expired sessions
- Network issues
- GPS accuracy problems
- Unit registration mismatches
- Time synchronization errors

### Best Practices

1. **Location Services**
   - Request permissions early
   - Clear user communication
   - Fallback mechanisms
   - Accuracy indicators

2. **Time Management**
   - Server time synchronization
   - Grace periods
   - Time zone handling
   - Buffer windows

3. **User Experience**
   - Clear error messages
   - Status indicators
   - Progress feedback
   - Retry options

### Configuration Options

```json
{
  "location": {
    "minRadius": 1,
    "maxRadius": 100,
    "accuracyThreshold": 20,
    "updateInterval": 30
  },
  "session": {
    "graceperiod": 5,
    "maxRetries": 3,
    "backupKeyLength": 11
  }
}
```

## Next Steps
1. Implement location validation in QR scanning
2. Add radius configuration in session creation
3. Create location verification middleware
4. Update database schema
5. Add real-time session status updates
6. Implement server-side time validation
7. Add location spoofing detection
8. Create comprehensive error handling

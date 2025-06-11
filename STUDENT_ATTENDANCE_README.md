# Student Attendance System with Location Verification

## Database Updates
First, we need to safely add location columns to the existing `attendance_sessions` table:

```sql
-- Safe migration script that won't affect existing data
ALTER TABLE attendance_sessions 
ADD COLUMN IF NOT EXISTS class_latitude DECIMAL(10, 8) NULL,
ADD COLUMN IF NOT EXISTS class_longitude DECIMAL(11, 8) NULL,
ADD COLUMN IF NOT EXISTS radius_meters INTEGER DEFAULT 100,
ADD COLUMN IF NOT EXISTS location_required BOOLEAN DEFAULT false;

-- Add index for faster location queries
CREATE INDEX IF NOT EXISTS idx_attendance_location 
ON attendance_sessions(class_latitude, class_longitude) 
WHERE class_latitude IS NOT NULL AND class_longitude IS NOT NULL;
```

## Student Attendance Flow

### 1. QR Code Scanning
- Open app and navigate to attendance section
- Scan QR code using device camera
- System validates:
  - Session is active
  - Within time window (start_time to end_time)
  - Not already marked present
  - Location verification (if enabled)

### 2. Backup Key Entry
- Alternative to QR scanning
- Enter provided backup key
- Same validations as QR code
- Rate-limited to prevent brute force

### 3. Location Verification
When location is required:
- Get student's current GPS location
- Calculate distance from class location
- Verify within allowed radius
- Check for mock locations
- Record accuracy metrics

### 4. Attendance States
```dart
enum AttendanceStatus {
  SUCCESS,              // Successfully marked
  OUTSIDE_RADIUS,       // Location too far
  SESSION_EXPIRED,      // Outside time window
  ALREADY_MARKED,       // Previously recorded
  INVALID_LOCATION,     // GPS issues
  MOCK_LOCATION,        // Fake location detected
  NETWORK_ERROR        // Connection issues
}
```

## Implementation Roadmap

### Phase 1: Basic Attendance
- [x] QR Code scanning
- [x] Session validation
- [x] Backup key system
- [x] Basic success/failure states

### Phase 2: Location Integration (Current)
- [x] Add location columns
- [x] Location pinning by lecturer
- [ ] Student location verification
- [ ] Distance calculation
- [ ] Radius compliance check

### Phase 3: Security & Validation
- [ ] Mock location detection
- [ ] GPS accuracy validation
- [ ] Rate limiting for backup keys
- [ ] Session state management
- [ ] Offline handling

### Phase 4: UI/UX Improvements
- [ ] Status indicators
- [ ] Error messages
- [ ] Loading states
- [ ] Success animations
- [ ] Location accuracy indicator
- [ ] Distance display

## Location Verification Logic

```dart
Future<AttendanceResult> verifyAttendance({
  required String sessionId,
  required Position studentLocation,
  String? backupKey,
}) async {
  try {
    // 1. Verify session is active
    final session = await getActiveSession(sessionId);
    if (session == null) {
      return AttendanceResult(
        status: AttendanceStatus.SESSION_EXPIRED,
        message: 'Session has ended or is invalid'
      );
    }

    // 2. Check if location verification required
    if (session.locationRequired) {
      final distance = calculateDistance(
        studentLat: studentLocation.latitude,
        studentLng: studentLocation.longitude,
        classLat: session.classLatitude,
        classLng: session.classLongitude
      );

      if (distance > session.radiusMeters) {
        return AttendanceResult(
          status: AttendanceStatus.OUTSIDE_RADIUS,
          message: 'You are too far from class location',
          distance: distance
        );
      }
    }

    // 3. Mark attendance
    await markAttendance(
      sessionId: sessionId,
      studentLocation: studentLocation,
      backupKey: backupKey
    );

    return AttendanceResult(
      status: AttendanceStatus.SUCCESS,
      message: 'Attendance marked successfully'
    );

  } catch (e) {
    return AttendanceResult(
      status: AttendanceStatus.NETWORK_ERROR,
      message: 'Error marking attendance: $e'
    );
  }
}
```

## Best Practices

1. **Location Accuracy**
   - Minimum accuracy requirement: 20 meters
   - Retry on poor GPS signal
   - Show accuracy indicator to student

2. **Security**
   - Validate all data server-side
   - Check for mock locations
   - Rate limit backup key attempts
   - Encrypt location data

3. **User Experience**
   - Clear error messages
   - Show distance from class
   - Quick retry options
   - Offline support

4. **Performance**
   - Efficient distance calculations
   - Optimize location updates
   - Cache session data
   - Background location updates

## Error Handling

1. **Location Errors**
   - GPS disabled
   - Poor accuracy
   - Mock location detected
   - Network issues

2. **Session Errors**
   - Expired session
   - Already marked
   - Invalid backup key
   - Server errors

## Testing Checklist

- [ ] QR code scanning works
- [ ] Backup key entry functions
- [ ] Location verification accurate
- [ ] All error states handled
- [ ] Network issues managed
- [ ] Mock locations detected
- [ ] Distance calculation correct
- [ ] Session validation works 
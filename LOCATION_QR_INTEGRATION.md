# QR Code Attendance with Location Pinning

## Overview
This integration adds location verification to the existing attendance system by modifying the `attendance_sessions` table. Lecturers can now pin their location when creating attendance sessions, and students must be within the specified radius when scanning QR codes or using backup keys.

## System Updates

### 1. Database Modifications

We'll modify the existing `attendance_sessions` table to include location data:

```sql
ALTER TABLE attendance_sessions
ADD COLUMN class_latitude DECIMAL(10, 8),
ADD COLUMN class_longitude DECIMAL(11, 8),
ADD COLUMN radius_meters INTEGER DEFAULT 50,
ADD COLUMN location_required BOOLEAN DEFAULT false;
```

### 2. Features

#### For Lecturers
- Pin location when creating attendance session
- Set custom radius for attendance (default 50m)
- Toggle location requirement per session
- View students' attendance with location verification status

#### For Students
- Scan QR code or enter backup key as usual
- App automatically checks location if required
- See distance from class location
- Receive clear feedback on location verification

### 3. Implementation Flow

#### Creating Attendance Session (Lecturer)
1. Open attendance creation page
2. Fill in regular session details
3. Toggle "Require Location" switch
4. If enabled:
   - Use "Pin Location" button to capture current position
   - Adjust radius if needed (10m - 200m)
5. Generate QR code and backup key

```dart
Future<void> createAttendanceSession({
  required String unitCode,
  required DateTime startTime,
  required DateTime endTime,
  required bool locationRequired,
  double? latitude,
  double? longitude,
  int? radiusMeters,
}) async {
  await db.insert('attendance_sessions', {
    'unit_code': unitCode,
    'start_time': startTime,
    'end_time': endTime,
    'location_required': locationRequired,
    'class_latitude': latitude,
    'class_longitude': longitude,
    'radius_meters': radiusMeters ?? 50,
  });
}
```

#### Marking Attendance (Student)
1. Open scanner or backup key page
2. If location is required for session:
   - App requests location permission
   - Verifies student is within radius
3. Process attendance marking
4. Show success/error message

```dart
Future<AttendanceResult> markAttendance({
  required String sessionId,
  required String studentId,
  required String verificationMethod, // 'QR_CODE' or 'BACKUP_KEY'
}) async {
  final session = await getSession(sessionId);
  
  if (session.locationRequired) {
    final position = await getCurrentLocation();
    final distance = calculateDistance(
      position.latitude,
      position.longitude,
      session.classLatitude,
      session.classLongitude
    );
    
    if (distance > session.radiusMeters) {
      return AttendanceResult(
        success: false,
        message: 'Too far from class location',
        distance: distance
      );
    }
  }
  
  // Mark attendance in database
  return await recordAttendance(
    sessionId: sessionId,
    studentId: studentId,
    verificationMethod: verificationMethod
  );
}
```

### 4. Error Handling

```dart
class AttendanceResult {
  final bool success;
  final String message;
  final double? distance;
  
  AttendanceResult({
    required this.success,
    required this.message,
    this.distance,
  });
}

const attendanceErrors = {
  'LOCATION_REQUIRED': 'Location verification is required for this session',
  'TOO_FAR': 'You are too far from the class location',
  'PERMISSION_DENIED': 'Location permission is required',
  'LOCATION_ERROR': 'Unable to get your location',
};
```

### 5. Implementation Steps

1. **Database Update**
   - Add new columns to attendance_sessions table
   - Update existing queries to handle location data

2. **UI Updates**
   - Add location toggle and pin button to session creation
   - Show location status in attendance marking
   - Display distance information to students

3. **Location Services**
   - Implement location permission handling
   - Add distance calculation
   - Handle location errors

4. **Testing**
   - Test with location enabled/disabled
   - Verify radius restrictions
   - Check error scenarios

### 6. Best Practices

1. **Location Handling**
   - Request permissions when needed
   - Show loading indicators
   - Cache location data briefly
   - Handle timeout scenarios

2. **User Experience**
   - Clear error messages
   - Visual indicators for location status
   - Show distance from class
   - Quick retry options

3. **Performance**
   - Optimize location checks
   - Minimize battery usage
   - Handle offline scenarios

### 7. Security

- Validate location data server-side
- Implement timeout for location checks
- Encrypt location data in transit
- Follow privacy guidelines 
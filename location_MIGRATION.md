# Location-Based QR Code Attendance Migration Guide

## Overview
This migration adds location-based validation while preserving the existing QR code attendance system's time management. We use Geolocator for location services without requiring Google Maps API.

## Database Schema

### 1. Location Sessions Table
```sql
CREATE TABLE location_attendance_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES attendance_sessions(id),
    class_latitude DECIMAL(10, 8),
    class_longitude DECIMAL(11, 8),
    radius_meters INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_session 
        FOREIGN KEY (session_id) 
        REFERENCES attendance_sessions(id)
);

-- Index for faster lookups
CREATE INDEX idx_location_session ON location_attendance_sessions(session_id);
CREATE INDEX idx_active_sessions ON location_attendance_sessions(is_active);
```

### 2. Location-Based Attendance Table
```sql
CREATE TABLE university_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES attendance_sessions(id),
    student_id UUID,
    student_latitude DECIMAL(10, 8),
    student_longitude DECIMAL(11, 8),
    distance_from_class DECIMAL(10, 2),
    is_within_radius BOOLEAN,
    gps_accuracy_meters DECIMAL(6, 2),
    is_mock_location BOOLEAN DEFAULT false,
    attendance_status TEXT CHECK (attendance_status IN (
        'SUCCESS',
        'OUTSIDE_RADIUS',
        'INVALID_LOCATION',
        'MOCK_LOCATION_DETECTED',
        'NOT_ENROLLED',
        'SESSION_EXPIRED'
    )),
    verification_notes TEXT,
    device_info JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_session 
        FOREIGN KEY (session_id) 
        REFERENCES attendance_sessions(id)
);

-- Indexes for performance
CREATE INDEX idx_attendance_student ON university_attendance(student_id);
CREATE INDEX idx_attendance_session ON university_attendance(session_id);
CREATE INDEX idx_attendance_status ON university_attendance(attendance_status);
```

## Location Implementation

### 1. Required Package
```yaml
# Add to pubspec.yaml
dependencies:
  geolocator: ^10.1.0
```

### 2. App Permissions
```xml
<!-- Android: Add to android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- iOS: Add to ios/Runner/Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location to verify your class attendance.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to location to verify your class attendance.</string>
```

### 3. Location Services
```dart
// Location permission handler
Future<bool> handleLocationPermission() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return false;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return false;
    }
  }
  
  return permission != LocationPermission.deniedForever;
}

// Get current location
Future<Position?> getCurrentLocation() async {
  if (!await handleLocationPermission()) {
    throw 'Location permissions are denied';
  }

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 5)
  );
}

// Calculate distance
double calculateDistance(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude,
) {
  return Geolocator.distanceBetween(
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude
  );
}

// Check for mock locations
Future<bool> isMockLocationOn() async {
  try {
    Position position = await Geolocator.getCurrentPosition();
    return position.isMocked;
  } catch (e) {
    return true; // Assume mock location if error
  }
}
```

## Implementation Functions

### 1. Location Recording
```typescript
async function addLocationToSession(sessionId: string, locationData: LocationData) {
    const { data, error } = await supabase
        .from('location_attendance_sessions')
        .insert({
            session_id: sessionId,
            class_latitude: locationData.latitude,
            class_longitude: locationData.longitude,
            radius_meters: locationData.radius,
            is_active: true
        })
        .select();

    return { data, error };
}
```

### 2. Attendance Verification
```typescript
async function verifyAndRecordAttendance(sessionId: string, studentId: string, location: Position) {
    // 1. Check enrollment
    const isEnrolled = await checkEnrollment(studentId, sessionId);
    if (!isEnrolled) {
        return { error: 'Not enrolled in this unit' };
    }

    // 2. Get session location
    const { data: sessionData } = await supabase
        .from('location_attendance_sessions')
        .select('*')
        .eq('session_id', sessionId)
        .single();

    // 3. Calculate distance
    const distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        sessionData.class_latitude,
        sessionData.class_longitude
    );

    // 4. Record attendance
    const { data, error } = await supabase
        .from('university_attendance')
        .insert({
            session_id: sessionId,
            student_id: studentId,
            student_latitude: location.latitude,
            student_longitude: location.longitude,
            distance_from_class: distance,
            is_within_radius: distance <= sessionData.radius_meters,
            gps_accuracy_meters: location.accuracy,
            is_mock_location: location.isMocked,
            attendance_status: getAttendanceStatus(distance, sessionData.radius_meters, location)
        })
        .select();

    return { data, error };
}

function getAttendanceStatus(distance: number, radius: number, location: Position): string {
    if (location.isMocked) return 'MOCK_LOCATION_DETECTED';
    if (location.accuracy > 30) return 'INVALID_LOCATION';
    if (distance > radius) return 'OUTSIDE_RADIUS';
    return 'SUCCESS';
}
```

## User Interface Components

### 1. Lecturer's Location Setter
```dart
class LocationSetter extends StatefulWidget {
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Class Location')),
      body: Column(
        children: [
          FutureBuilder<Position?>(
            future: getCurrentLocation(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              
              return Column(
                children: [
                  Text('Current Location:'),
                  Text('Latitude: ${snapshot.data?.latitude}'),
                  Text('Longitude: ${snapshot.data?.longitude}'),
                  Text('Accuracy: ${snapshot.data?.accuracy} meters'),
                  
                  Slider(
                    min: 10,
                    max: 200,
                    divisions: 19,
                    label: 'Radius: ${_radius}m',
                    onChanged: (value) => setState(() => _radius = value),
                  ),
                  
                  ElevatedButton(
                    onPressed: () => saveLocation(snapshot.data!),
                    child: Text('Set as Class Location')
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### 2. Student's Attendance Marker
```dart
class AttendanceMarker extends StatefulWidget {
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<Position?>(
          future: getCurrentLocation(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Text('Getting your location...');
            }

            return FutureBuilder<bool>(
              future: validateAttendance(sessionId, snapshot.data!),
              builder: (context, validationSnapshot) {
                if (!validationSnapshot.hasData) {
                  return CircularProgressIndicator();
                }

                return Column(
                  children: [
                    Icon(
                      validationSnapshot.data! 
                        ? Icons.check_circle 
                        : Icons.error,
                      color: validationSnapshot.data! 
                        ? Colors.green 
                        : Colors.red,
                      size: 48,
                    ),
                    Text(
                      validationSnapshot.data!
                        ? 'Attendance Marked Successfully!'
                        : 'You are not in the correct location'
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
```

## Error Messages

1. **Location Errors**
   - "GPS accuracy too low (must be under 30m)"
   - "You're too far from the class location"
   - "Mock location detected"
   - "Please enable location services"

2. **System Messages**
   - "Location set successfully"
   - "Attendance marked successfully"
   - "You're in the right place!"

## Best Practices

1. **Location Accuracy**
   - Use high accuracy for initial location
   - Verify GPS signal strength
   - Check for mock locations

2. **Battery Optimization**
   - Only get location when needed
   - Don't keep GPS running
   - Use appropriate timeouts

3. **Security**
   - Validate all locations
   - Check for mock locations
   - Store validation history

## Rollback Plan

```sql
-- Remove location components
DROP TABLE IF EXISTS university_attendance CASCADE;
DROP TABLE IF EXISTS location_attendance_sessions CASCADE;
```

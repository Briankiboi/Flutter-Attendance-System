# Pin Location Feature for QR Code Attendance System

## Overview
This guide explains how to implement location-based validation alongside the existing QR code attendance system. Lecturers can set a specific location pin and radius for each class session, which will be used to validate student attendance in conjunction with QR codes.

## Features
- Pin location selection using interactive map
- Customizable attendance radius
- Integration with existing QR code system
- Location validation during attendance marking
- Support for multiple class locations

## Database Updates

### Add Location Fields to Attendance Sessions
```sql
ALTER TABLE attendance_sessions
ADD COLUMN latitude DECIMAL(10, 8),
ADD COLUMN longitude DECIMAL(11, 8),
ADD COLUMN radius_meters INTEGER DEFAULT 100,
ADD COLUMN location_required BOOLEAN DEFAULT false;
```

## Implementation Steps

### 1. Location Selection Screen
Add a new screen for location selection with these features:
- Interactive map view
- Current location detection
- Pin dropping capability
- Radius adjustment slider (10-200 meters)
- Location save functionality

```dart
class LocationSelectionScreen extends StatefulWidget {
  final String sessionId;
  final Function(LocationData) onLocationSelected;

  // ... widget implementation
}

class LocationData {
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String locationName;
}
```

### 2. Integration with QR Code Generation
Update the QR code generation flow to include location data:

```dart
class SessionData {
  final String sessionId;
  final DateTime timestamp;
  final LocationData? location;  // Optional location data
  
  String generateQRPayload() {
    return jsonEncode({
      'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'location': location != null ? {
        'lat': location.latitude,
        'lng': location.longitude,
        'radius': location.radiusMeters
      } : null
    });
  }
}
```

### 3. Attendance Validation Flow
```dart
Future<bool> validateAttendance(String sessionId, String qrData) async {
  // 1. Validate QR code first
  final qrValid = await validateQRCode(qrData);
  if (!qrValid) return false;

  // 2. Check if location validation is required
  final session = await getSessionDetails(sessionId);
  if (!session.locationRequired) return true;

  // 3. Validate location if required
  final userLocation = await getCurrentLocation();
  final distance = calculateDistance(
    userLocation.latitude,
    userLocation.longitude,
    session.latitude,
    session.longitude
  );

  return distance <= session.radiusMeters;
}
```

## UI Integration

### 1. Session Creation Flow
Add location option in the session creation:

```dart
class CreateSessionScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Existing QR code settings
        // ...

        // New location toggle
        SwitchListTile(
          title: Text('Require Location Validation'),
          value: _locationRequired,
          onChanged: _handleLocationToggle,
        ),

        // Location selection button (visible when location is required)
        if (_locationRequired)
          ElevatedButton(
            onPressed: _showLocationPicker,
            child: Text('Set Class Location'),
          ),
      ],
    );
  }
}
```

### 2. Student Attendance Flow
Update the attendance marking process:

```dart
Future<void> markAttendance(String qrData) async {
  try {
    // 1. Decode QR data
    final sessionData = decodeQRData(qrData);

    // 2. Check if location validation is needed
    if (sessionData.hasLocation) {
      final locationValid = await validateLocation(
        sessionData.latitude,
        sessionData.longitude,
        sessionData.radius
      );
      
      if (!locationValid) {
        throw 'You must be within the class location to mark attendance';
      }
    }

    // 3. Proceed with existing attendance marking
    await markAttendanceInDatabase(sessionData.sessionId);
    
  } catch (e) {
    // Handle errors
  }
}
```

## Best Practices

1. **Location Accuracy**
   - Use high accuracy for location services
   - Implement retry logic for poor GPS signals
   - Show accuracy indicator to users

2. **User Experience**
   - Clear error messages for location issues
   - Visual radius indicator on map
   - Simple one-tap location selection
   - Save frequently used locations

3. **Performance**
   - Cache location data when appropriate
   - Optimize location updates
   - Minimize battery usage

4. **Error Handling**
   - Handle GPS permission denials
   - Manage offline scenarios
   - Provide clear feedback for location errors

## Testing

1. Test location selection with:
   - Different radius sizes
   - Various campus locations
   - Edge cases (building boundaries)

2. Verify attendance marking:
   - Inside radius
   - Outside radius
   - Poor GPS signal
   - Mock locations

## Security Considerations

1. Validate all location data server-side
2. Implement mock location detection
3. Store location history for audit purposes
4. Encrypt location data in transit

## Migration Notes

1. Existing sessions without location data will work as before
2. Location requirement can be enabled/disabled per session
3. Backward compatible with existing QR code functionality

## Troubleshooting

Common issues and solutions:
1. GPS accuracy issues
2. Permission handling
3. Location service availability
4. Radius calculation edge cases

## Future Enhancements

1. Multiple location support for same session
2. Geofencing notifications
3. Location history analytics
4. Custom shape boundaries instead of circles 
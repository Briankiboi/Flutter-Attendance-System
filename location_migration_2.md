# Location-Based QR Code Attendance Migration Guide 2.0

## Overview
This migration enhances the existing location-based validation system by integrating Flutter Map with OpenStreetMap as a free alternative to Google Maps, while maintaining the existing QR code attendance system's time management and location validation features.

## New Dependencies
```yaml
dependencies:
  # Existing dependencies
  geolocator: ^11.0.0
  
  # New mapping dependencies
  flutter_map: ^8.1.1
  latlong2: ^0.9.0
```

## Database Schema
[Previous schema remains unchanged]

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

## Map Implementation

### 1. Basic Map Widget
```dart
class LocationMap extends StatefulWidget {
  final Location? initialLocation;
  final Function(Location)? onLocationSelected;

  const LocationMap({
    Key? key,
    this.initialLocation,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  final MapController _mapController = MapController();
  
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.initialLocation?.latLng ?? const LatLng(0, 0),
        initialZoom: 13,
        onTap: (tapPosition, point) {
          // Handle map tap for location selection
          if (widget.onLocationSelected != null) {
            widget.onLocationSelected!(
              Location(
                latitude: point.latitude,
                longitude: point.longitude,
              ),
            );
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.your.app',
        ),
        // Add markers, circles for radius, etc.
      ],
    );
  }
}
```

### 2. Location Selection with Radius
```dart
class LocationSelector extends StatefulWidget {
  final String sessionId;
  final Function(Location, double) onLocationSet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LocationMap(
            onLocationSelected: (location) {
              setState(() {
                _selectedLocation = location;
              });
            },
          ),
        ),
        if (_selectedLocation != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('Selected Location:'),
                Text('Lat: ${_selectedLocation!.latitude}'),
                Text('Lng: ${_selectedLocation!.longitude}'),
                Slider(
                  min: 30,
                  max: 200,
                  divisions: 17,
                  value: _radius,
                  label: 'Radius: ${_radius.round()}m',
                  onChanged: (value) {
                    setState(() {
                      _radius = value;
                    });
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onLocationSet(_selectedLocation!, _radius);
                  },
                  child: Text('Set Location'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

### 3. Student Location Verification
```dart
class LocationVerifier extends StatelessWidget {
  final String sessionId;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: getCurrentLocation(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            message: 'Could not access location: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return LoadingView(
            message: 'Getting your location...',
          );
        }

        return LocationMap(
          initialLocation: Location(
            latitude: snapshot.data!.latitude,
            longitude: snapshot.data!.longitude,
          ),
          child: Column(
            children: [
              Text('Your current location:'),
              Text('Accuracy: ${snapshot.data!.accuracy} meters'),
              ElevatedButton(
                onPressed: () => verifyAndRecordAttendance(
                  sessionId,
                  studentId,
                  snapshot.data!,
                ),
                child: Text('Verify Location'),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## Location Services
[Previous location services implementation remains unchanged]

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
[Previous implementation functions remain unchanged]

## Migration Steps

1. Update `pubspec.yaml` with new dependencies
2. Run `flutter pub get`
3. Implement the new map widgets
4. Update existing location-based views to use the new map implementation
5. Test the integration thoroughly

## Benefits of This Migration

1. **Cost Effective**: 
   - No API key required
   - No usage limits
   - Free and open-source solution

2. **Enhanced User Experience**:
   - Visual map interface for location selection
   - Interactive radius selection
   - Real-time location visualization

3. **Improved Accuracy**:
   - Visual confirmation of location
   - Better radius visualization
   - More accurate location selection

4. **Maintainability**:
   - Simpler implementation
   - No API key management
   - Reduced dependency on third-party services

## Notes

1. The OpenStreetMap tile server has usage policies. For production use, consider:
   - Setting up your own tile server
   - Using a commercial tile provider
   - Implementing proper caching

2. The map implementation includes:
   - Basic map display
   - Location selection
   - Radius visualization
   - Current location display

3. Existing location verification logic remains unchanged, only the UI layer is enhanced. 
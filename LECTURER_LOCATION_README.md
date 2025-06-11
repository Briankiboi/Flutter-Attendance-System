# Lecturer Location Pinning Guide

## Overview
This guide explains how to add location-based validation to your existing QR code attendance sessions. After creating a QR code for attendance, lecturers can set a specific location and radius for the class, ensuring students are physically present within the specified area.

## Database Updates

Add location fields to the existing attendance_sessions table (safe script that won't affect existing data):

```sql
-- Safe script that preserves existing data
ALTER TABLE attendance_sessions 
ADD COLUMN IF NOT EXISTS class_latitude DECIMAL(10, 8) NULL,
ADD COLUMN IF NOT EXISTS class_longitude DECIMAL(11, 8) NULL,
ADD COLUMN IF NOT EXISTS radius_meters INTEGER DEFAULT 100,
ADD COLUMN IF NOT EXISTS location_required BOOLEAN DEFAULT false;
```

## Active Sessions Dropdown

### What Makes a Session "Active"?
- Session's end time hasn't passed yet
- Created by the current lecturer
- Has a valid QR code already generated

### Getting Active Sessions
```dart
// Function to get active sessions for dropdown
Future<List<ActiveSessionData>> getActiveSessions() async {
  final now = DateTime.now();
  final currentLecturerId = await getCurrentLecturerId();
  
  final result = await supabase
    .from('attendance_sessions')
    .select('''
      id,
      unit_code,
      unit_name,
      start_time,
      end_time
    ''')
    .eq('lecturer_id', currentLecturerId)
    .gte('end_time', now.toIso8601String())
    .order('start_time', ascending: true);
    
  return result.map((session) => ActiveSessionData.fromJson(session)).toList();
}

// Example display format
String formatSessionDisplay(ActiveSessionData session) {
  final startTime = DateFormat('HH:mm').format(session.startTime);
  return '${session.unitCode} - $startTime';
}
```

### Dropdown Implementation
```dart
// Add this at the top of your existing pin_location_page.dart
Widget buildSessionDropdown() {
  return Container(
    padding: EdgeInsets.all(16),
    child: DropdownButton<String>(
      hint: Text('Select Active Session'),
      value: selectedSessionId,
      isExpanded: true,
      items: activeSessions.map((session) {
        return DropdownMenuItem(
          value: session.sessionId,
          child: Text(formatSessionDisplay(session)),
        );
      }).toList(),
      onChanged: (value) => _onSessionSelected(value),
    ),
  );
}
```

### Example Session Display
If a lecturer created these QR codes:
```
Current Time: 4:12 PM

Sessions:
✓ CSC 101: 4:30 PM - 5:30 PM (shows in dropdown)
✓ CSC 205: 5:00 PM - 6:00 PM (shows in dropdown)
✗ CSC 301: 2:00 PM - 3:00 PM (won't show - already ended)
```

## Implementation Steps

### 1. Update Pin Location Page
Add the dropdown while keeping existing UI:

```dart
class _PinLocationPageState extends State<PinLocationPage> {
  // Add new variables
  String? selectedSessionId;
  List<ActiveSessionData> activeSessions = [];

  @override
  void initState() {
    super.initState();
    _loadActiveSessions();
    // Keep existing initState code
  }

  Future<void> _loadActiveSessions() async {
    final sessions = await getActiveSessions();
    setState(() {
      activeSessions = sessions;
    });
  }

  // Add this to your existing build method, just below AppBar
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pin Location'),
        // ... existing AppBar code
      ),
      body: Column(
        children: [
          buildSessionDropdown(), // Add dropdown here
          Expanded(
            child: Stack(
              children: [
                // Your existing Google Maps implementation
                // ... rest of your existing code
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

### 2. Update Save Location Logic
Modify the existing save function:

```dart
Future<void> _saveLocation() async {
  if (selectedSessionId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please select a session first'))
    );
    return;
  }

  if (_currentPosition == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please wait for location to be fetched'))
    );
    return;
  }

  try {
    await supabase
      .from('attendance_sessions')
      .update({
        'class_latitude': _currentPosition!.latitude,
        'class_longitude': _currentPosition!.longitude,
        'radius_meters': _selectedRadius,
        'location_required': true
      })
      .eq('id', selectedSessionId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location saved successfully'),
        backgroundColor: Colors.green,
      )
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error saving location: $e'),
        backgroundColor: Colors.red,
      )
    );
  }
}
```

## Lecturer's Flow

1. **Create QR Code** (Existing process)
   - Create QR code as normal
   - System saves session to database

2. **Pin Location** (When in class)
   - Open Pin Location page
   - Select active session from dropdown
   - Current location loads automatically
   - Adjust pin if needed
   - Set radius (defaults to 100m)
   - Click Save

3. **Verification**
   - System confirms save
   - Location is linked to session
   - Ready for student attendance

## Testing Checklist

- [ ] Dropdown shows only current/future sessions
- [ ] Each session shows correct unit code and time
- [ ] Expired sessions don't appear
- [ ] Map and location features work as before
- [ ] Save updates correct session in database
- [ ] Error handling works properly

## Troubleshooting

1. **Dropdown Empty**
   - Check if any active sessions exist
   - Verify lecturer is logged in
   - Check session end times

2. **Session Not Appearing**
   - Verify session wasn't created
   - Check if session already ended
   - Confirm lecturer permissions

3. **Save Issues**
   - Verify session selected
   - Check location is valid
   - Confirm database connection 
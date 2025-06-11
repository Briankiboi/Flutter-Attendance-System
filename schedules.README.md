# Schedules Feature Implementation Guide

## Overview
The schedules feature implements a WhatsApp-style chat interface for lecturers to send schedules and announcements to students. It combines easy unit selection (like CAT marks entry) with real-time messaging and read receipts.

## Core Features

### 1. Lecturer Interface (WhatsApp-style)
- Unit selection dropdown at the top (reusing CAT marks entry pattern)
- Simple message input field for announcements
- Schedule creation with date and time pickers
- Real-time read receipts (who read and when)
- Message history with read status
- Total students and read percentage statistics

### 2. Student Interface (Auto-organized)
- No unit selection needed (like WhatsApp)
- Messages automatically grouped by units
- Clear "No schedules for today" message when appropriate
- Real-time notifications for new messages
- Messages marked as read automatically when opened
- Past messages retained with clear timestamps

### Example: Student View
```
[Software Engineering]
Today (March 14, 2024):
   "No classes scheduled for today"

Previous Messages:
   March 13, 2024
   - "Class at 11:00 AM" [Read]
   - "Assignment due next week" [Read]

[Database Systems]
Today (March 14, 2024):
   10:28 AM: "Next class at 11:00" [New]
   
Previous Messages:
   March 13, 2024
   - "Quiz postponed to next week" [Read]
```

### Example: Lecturer Read Receipts
When a lecturer taps on a message, they see:
```
Message: "Next class at 11:00"
Unit: Database Systems
Sent: March 14, 2024 10:28 AM

Read by:
- John Doe (Read at 10:30 AM)
- Jane Smith (Read at 10:35 AM)
- 15 more students...

Statistics:
- Total Students: 45
- Read by: 17 (37.8%)
- Last read: 2 minutes ago
```

## Database Schema

```sql
-- Main messages table
CREATE TABLE schedule_messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    schedule_id UUID REFERENCES schedules(id),
    unit_id UUID REFERENCES units(id),
    message_type varchar,
    content text,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    schedule_date DATE
);

-- Read status tracking
CREATE TABLE message_read_status (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES schedule_messages(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id),
    read_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    device_info JSONB,
    UNIQUE(message_id, student_id)
);
```

## Implementation Details

### 1. Lecturer Side
   ```dart
// Unit Selection (like CAT marks)
DropdownButton<String>(
  hint: Text('Select Unit'),
  value: _selectedUnitId,
  items: _units.map((unit) => DropdownMenuItem(
    value: unit['id'],
    child: Text('${unit['code']} - ${unit['name']} (${unit['unread_count']} unread)'),
  )).toList(),
  onChanged: (unitId) => _selectUnit(unitId),
)

// Message Input
TextField(
  controller: _messageController,
  decoration: InputDecoration(
    hintText: _selectedUnitId == null 
      ? 'Select a unit first'
      : 'Type announcement for ${_selectedUnit['code']}',
  ),
)

// Read Receipt Dialog
void showReadReceipts(String messageId) {
  showDialog(
    context: context,
    builder: (context) => ReadReceiptDialog(messageId: messageId),
  );
}
```

### 2. Student Side
```dart
// Auto-grouped messages by unit
ListView.builder(
  itemCount: _units.length,
  itemBuilder: (context, index) {
    final unit = _units[index];
    return UnitMessagesSection(
      unitCode: unit['code'],
      messages: _messagesByUnit[unit['id']] ?? [],
      showEmptyMessage: true,
    );
  },
)

// Message Card
class MessageCard extends StatelessWidget {
  final Message message;

     @override
     Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(message.text),
        subtitle: Text(DateFormat.jm().format(message.timestamp)),
        trailing: message.isRead 
          ? Icon(Icons.done_all, color: Colors.blue)
          : Icon(Icons.done),
         ),
       );
     }
}
```

### 3. Real-time Updates
```dart
// Subscribe to messages
final subscription = supabase
  .from('schedule_messages')
  .stream(primaryKey: ['id'])
  .eq('unit_id', unitId)
  .listen((messages) {
    // Update UI
  });

// Mark as read
Future<void> markAsRead(String messageId) async {
  await supabase.from('message_read_status').upsert({
    'message_id': messageId,
    'student_id': _studentId,
    'device_info': {
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    }
  });
}
```

## Security Considerations

1. Row Level Security ensures:
   - Lecturers can only manage their own messages
   - Students can only read messages for their registered units
   - Students can only manage their own read status

2. Fallback Support:
   - System checks `student_units` first
   - Falls back to `student_registered_units` if needed
   - Ensures no student misses important announcements

## Testing Checklist

1. Lecturer Side:
   - [ ] Unit dropdown shows all assigned units
   - [ ] Can send both schedules and announcements
   - [ ] Can see read receipts for each message
   - [ ] Gets real-time updates when students read

2. Student Side:
   - [ ] Sees all messages from registered units
   - [ ] Messages properly grouped by unit
   - [ ] "No schedules" shown when appropriate
   - [ ] Messages marked as read automatically
   - [ ] Gets real-time notifications
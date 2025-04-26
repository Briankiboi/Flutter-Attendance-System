import 'package:flutter/material.dart';
import 'analysis.dart';
import 'package:intl/intl.dart';

class PrintAttendance extends StatefulWidget {
  final String unitCode;
  final String unitName;
  final String date;
  final String time;
  final List<Student> students;
  final String? department;
  final String? course;
  final String? semester;

  const PrintAttendance({
    Key? key,
    required this.unitCode,
    required this.unitName,
    required this.date,
    required this.time,
    required this.students,
    this.department,
    this.course,
    this.semester,
  }) : super(key: key);

  @override
  _PrintAttendanceState createState() => _PrintAttendanceState();
}

class _PrintAttendanceState extends State<PrintAttendance> {
  List<Student> _presentStudents = [];
  List<Student> _absentStudents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize present and absent students lists
    _updateAttendanceLists();
  }

  void _updateAttendanceLists() {
    _presentStudents = widget.students.where((student) => student.isPresent).toList();
    _absentStudents = widget.students.where((student) => !student.isPresent).toList();
  }

  void _navigateToAnalysis() {
    // Prepare the session data with all required information
    final sessionData = {
      'unitCode': widget.unitCode,
      'unitName': widget.unitName,
      'date': widget.date,
      'startTime': widget.time,
      'endTime': _calculateEndTime(widget.time),
      'sessionDuration': _calculateSessionDuration(),
      'attendees': _presentStudents.map((student) => {
        'studentName': student.name,
        'studentEmail': student.email,
        'registrationNumber': student.email.split('@')[0],
        'timestamp': student.timeMarked, // Add timestamp when student was marked
      }).toList(),
      'absentees': _absentStudents.map((student) => {
        'name': student.name,
        'email': student.email,
        'registrationNumber': student.email.split('@')[0],
      }).toList(),
      'selectedStudents': widget.students.map((student) => {
        'name': student.name,
        'email': student.email,
        'registrationNumber': student.email.split('@')[0],
      }).toList(),
      'totalStudents': widget.students.length,
      'presentCount': _presentStudents.length,
      'absentCount': _absentStudents.length,
      'department': _getDepartmentFromUnitCode(widget.unitCode),
      'course': _getCourseFromUnitCode(widget.unitCode),
      'year': _getYearFromUnitCode(widget.unitCode),
      'semester': _getSemesterFromUnitCode(widget.unitCode),
    };
    
    // Use the attendanceUtils to fetch related sessions for this unit code
    final relatedSessions = _fetchRelatedSessions(widget.unitCode);

    // Show loading overlay while preparing data
    setState(() {
      _isLoading = true;
    });

    // Use delayed future to show loading state before navigation
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Navigate to analysis page with the complete session data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisPage(
              sessionData: sessionData,
              relatedSessions: relatedSessions,
            ),
          ),
        );
      }
    });
  }
  
  // Helper method to calculate session duration in hours (e.g., "2 hours")
  String _calculateSessionDuration() {
    // Default to 2 hours for most classes
    return "2 hours";
  }
  
  // Helper method to calculate end time based on start time (e.g., "14:00" -> "16:00")
  String _calculateEndTime(String startTime) {
    try {
      // Parse the start time
      final format = DateFormat("HH:mm");
      final dateTime = format.parse(startTime);
      
      // Add 2 hours (default class duration)
      final endTime = dateTime.add(Duration(hours: 2));
      
      // Format back to string
      return format.format(endTime);
    } catch (e) {
      // If parsing fails, add 2 hours manually (assuming format "14:00")
      if (startTime.contains(':')) {
        final parts = startTime.split(':');
        if (parts.length == 2) {
          int hour = int.tryParse(parts[0]) ?? 0;
          hour = (hour + 2) % 24;  // Add 2 hours, wrap around at 24
          return '${hour.toString().padLeft(2, '0')}:${parts[1]}';
        }
      }
      return startTime;  // Return original if we can't parse
    }
  }
  
  // Helper method to extract department from unit code
  String _getDepartmentFromUnitCode(String unitCode) {
    if (unitCode.contains('ED')) {
      return 'Education';
    } else if (unitCode.contains('ACSC')) {
      return 'Applied Computer Science';
    } else if (unitCode.contains('COSC')) {
      return 'Computer Science';
    } else if (unitCode.contains('STAT')) {
      return 'Statistics';
    } else if (unitCode.contains('MATH')) {
      return 'Mathematics';
    }
    return 'Department of Computing and Information Technology';
  }
  
  // Helper method to extract course from unit code
  String _getCourseFromUnitCode(String unitCode) {
    if (unitCode.contains('ED')) {
      return 'Bachelor of Education';
    } else if (unitCode.contains('ACSC')) {
      return 'Bachelor of Science in Applied Computer Science';
    } else if (unitCode.contains('COSC')) {
      return 'Bachelor of Science in Computer Science';
    } else if (unitCode.contains('STAT')) {
      return 'Bachelor of Science in Statistics';
    } else if (unitCode.contains('MATH')) {
      return 'Bachelor of Science in Mathematics';
    }
    return 'Bachelor of Science in Information Technology';
  }
  
  // Helper method to extract year from unit code
  String _getYearFromUnitCode(String unitCode) {
    if (unitCode.length >= 3) {
      // Extract the numeric part (e.g., "208" from "ACSC208")
      final numericPart = RegExp(r'[0-9]+').stringMatch(unitCode) ?? '';
      if (numericPart.isNotEmpty && numericPart.length >= 1) {
        // First digit typically indicates the year
        final yearDigit = int.tryParse(numericPart[0]);
        if (yearDigit != null) {
          return 'Year $yearDigit';
        }
      }
    }
    return 'Year 2';  // Default to Year 2 if we can't determine
  }
  
  // Helper method to extract semester from unit code
  String _getSemesterFromUnitCode(String unitCode) {
    // Some universities encode semester in unit code, but if not, default to current
    return 'Semester 2';  // Default to Semester 2
  }
  
  // Helper method to fetch related session data for the same unit
  List<Map<String, dynamic>> _fetchRelatedSessions(String unitCode) {
    // This would typically fetch from a database or API
    // For this example, we'll create some mock data for ED102 only
    
    if (unitCode == 'ED102') {
      return [
        {
          'unitCode': 'ED102',
          'unitName': 'Biology Teaching Methods',
          'date': '2025-03-07', // Previous Friday session
          'startTime': '17:00',
          'endTime': '19:00',
          'sessionDuration': '2 hours',
          'attendees': [
            {
              'studentName': 'Pauline Wakio Njeru',
              'studentEmail': 'abt5.06240.23@student.tharaka.ac.ke',
              'registrationNumber': 'abt5.06240.23',
              'timestamp': 1720537823000, // A timestamp (ms)
            },
            {
              'studentName': 'Julius nzioka',
              'studentEmail': 'abt5.06241.23@student.tharaka.ac.ke',
              'registrationNumber': 'abt5.06241.23',
              'timestamp': 1720538123000, // A timestamp (ms)
            },
          ],
          'department': 'Education',
          'course': 'Bachelor of Education',
          'year': 'Year 1',
          'semester': 'Semester 2',
        }
      ];
    }
    
    // Return empty list for other unit codes
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Print Attendance'),
        actions: [
          // Analysis button
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _isLoading ? null : _navigateToAnalysis,
            tooltip: 'Analyze Attendance',
          ),
          // Print button
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isLoading ? null : () {
              // Your existing print functionality
            },
            tooltip: 'Print Attendance',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Your existing attendance display widget
          // ... rest of your existing body code ...

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

// Student model class (add this if you don't have it already)
class Student {
  final String name;
  final String email;
  final bool isPresent;
  final String? timeMarked;

  Student({
    required this.name,
    required this.email,
    required this.isPresent,
    this.timeMarked,
  });
} 
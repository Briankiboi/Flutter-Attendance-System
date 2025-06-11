import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../utils/attendance_utils.dart';

class AnalysisPage extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  final List<Map<String, dynamic>>? relatedSessions;

  const AnalysisPage({
    super.key, 
    required this.sessionData, 
    this.relatedSessions
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceData = [];
  Map<String, int> _attendanceTrends = {};
  Map<String, double> _timeOfDayTrends = {};
  List<String> _mostAbsentDays = [];
  List<String> _mostAttendedDays = [];
  int _totalStudents = 0;
  int _presentCount = 0;
  int _absentCount = 0;
  
  // Add new variables for eligibility tracking
  final Map<String, Map<String, dynamic>> _studentEligibility = {};
  final int _totalRequiredHours = 36;
  final int _minimumRequiredHours = 25;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _analyzeData();
  }
  
  @override
  void initState() {
    super.initState();
    // Add debug prints to verify data
    print('Initializing analysis with session data:');
    print('Unit Code: ${widget.sessionData['unitCode']}');
    print('Unit Name: ${widget.sessionData['unitName']}');
    print('Date: ${widget.sessionData['date']}');
    print('Time: ${widget.sessionData['time']}');
    print('Total Students: ${widget.sessionData['totalStudents']}');
    print('Present: ${widget.sessionData['presentCount']}');
    print('Absent: ${widget.sessionData['absentCount']}');
    print('Attendees: ${widget.sessionData['attendees']}');
    print('Absentees: ${widget.sessionData['absentees']}');
    
    _analyzeData();
  }
  
  void _analyzeData() {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get exact data from print attendance
      final data = Map<String, dynamic>.from(widget.sessionData);
      
      // Special handling for units known to have format issues
      final unitCode = data['unitCode'] as String?;
      print('Processing unit: $unitCode');
      
      // Print debug info to diagnose data format issues
      print('Debug Session Data: ${data.toString().substring(0, data.toString().length > 500 ? 500 : data.toString().length)}');
      
      // Extract course information for debugging
      final department = data['department'] as String?;
      final course = data['course'] as String?;
      final year = data['year'];
      final semester = data['semester'];
      print('Course Info Extracted: department=$department, course=$course, year=$year, semester=$semester');
      
      // Extract week and day information from print attendance
      String week = 'Unknown';
      String day = 'Unknown';
      
      // First try to get directly if available
      if (data['week'] != null) {
        week = data['week'].toString();
      } else if (data.containsKey('weekInfo') && data['weekInfo'] != null) {
        week = data['weekInfo'].toString();
      }
      
      if (data['day'] != null) {
        day = data['day'].toString();
      } else if (data.containsKey('dayInfo') && data['dayInfo'] != null) {
        day = data['dayInfo'].toString();
      }
      
      // If still unknown, try to extract from date
      if (week == 'Unknown' || day == 'Unknown') {
        final date = data['date'] as String?;
        if (date != null && date.isNotEmpty) {
          try {
            final parsedDate = DateFormat('yyyy-MM-dd').parse(date);
            
            // Get day of week
            if (day == 'Unknown') {
              day = DateFormat('EEEE').format(parsedDate); // e.g., "Friday"
            }
            
            // If week is still unknown, try to calculate the week of month
            if (week == 'Unknown') {
              final weekOfMonth = ((parsedDate.day - 1) ~/ 7) + 1;
              final month = DateFormat('MMMM').format(parsedDate); // e.g., "March"
              week = 'Week $weekOfMonth of $month';
            }
          } catch (e) {
            print('Error parsing date for week/day: $e');
          }
        }
      }
      
      // Update session data with extracted week and day
      widget.sessionData['week'] = week;
      widget.sessionData['day'] = day;
      
      print('Extracted week: $week, day: $day');
      
      // Extract attendance lists with null safety
      final List<dynamic> attendees = data['attendees'] ?? [];
      final List<dynamic> selectedStudents = data['selectedStudents'] ?? [];
      
      // Get session duration in hours (default to 2 hours if not specified)
      final sessionDuration = data['sessionDuration'] != null 
          ? _parseDurationToHours(data['sessionDuration'].toString()) 
          : 2.0;
      
      print('Session duration in hours: $sessionDuration');
      
      // Get explicit counts if available - these are more reliable
      int explicitTotal = 0;
      int explicitPresent = 0;
      int explicitAbsent = 0;
      
      if (data.containsKey('totalStudents') && data['totalStudents'] != null) {
        explicitTotal = data['totalStudents'] is int 
            ? data['totalStudents'] 
            : int.tryParse(data['totalStudents'].toString()) ?? 0;
      }
      
      if (data.containsKey('presentCount') && data['presentCount'] != null) {
        explicitPresent = data['presentCount'] is int 
            ? data['presentCount'] 
            : int.tryParse(data['presentCount'].toString()) ?? 0;
      }
      
      if (data.containsKey('absentCount') && data['absentCount'] != null) {
        explicitAbsent = data['absentCount'] is int 
            ? data['absentCount'] 
            : int.tryParse(data['absentCount'].toString()) ?? 0;
      }
      
      // Calculate from explicit total/absent/present values first if available
      if (explicitTotal > 0 || explicitPresent > 0 || explicitAbsent > 0) {
        if (explicitTotal > 0) {
          _totalStudents = explicitTotal;
          if (explicitPresent > 0) {
            _presentCount = explicitPresent;
            _absentCount = _totalStudents - _presentCount;
          } else if (explicitAbsent > 0) {
            _absentCount = explicitAbsent;
            _presentCount = _totalStudents - _absentCount;
          } else {
            _presentCount = attendees.length;
            _absentCount = _totalStudents - _presentCount;
          }
        } else {
          // If we don't have total but have present and absent
          if (explicitPresent > 0 && explicitAbsent > 0) {
            _presentCount = explicitPresent;
            _absentCount = explicitAbsent;
            _totalStudents = _presentCount + _absentCount;
          } else if (explicitPresent > 0) {
            _presentCount = explicitPresent;
            _absentCount = selectedStudents.length - explicitPresent;
            _totalStudents = selectedStudents.isNotEmpty ? selectedStudents.length : _presentCount;
          } else if (explicitAbsent > 0) {
            _absentCount = explicitAbsent;
            _presentCount = attendees.length;
            _totalStudents = _presentCount + _absentCount;
          }
        }
      } else {
        // Fall back to calculating from attendees/selectedStudents
        _presentCount = attendees.length;
        
        if (selectedStudents.isNotEmpty) {
          _totalStudents = selectedStudents.length;
          _absentCount = _totalStudents - _presentCount;
        } else if (data.containsKey('attendeeDetails') && data['attendeeDetails'] is List) {
          // Calculate from attendee details
          final attendeeDetails = data['attendeeDetails'] as List;
          _totalStudents = attendeeDetails.length;
          
          int presentCount = 0;
          int absentCount = 0;
          
          for (var attendee in attendeeDetails) {
            if (attendee is Map<String, dynamic>) {
              final details = attendee['details'];
              bool isAbsent = false;
              
              if (details is Map) {
                if (details.containsKey('status') && details['status'] == 'absent') {
                  isAbsent = true;
                } else if (details.containsKey('timestamp') && details['timestamp'] == null) {
                  isAbsent = true;
                }
              }
              
              if (isAbsent) {
                absentCount++;
              } else {
                presentCount++;
              }
            }
          }
          
          if (presentCount > 0 || absentCount > 0) {
            _presentCount = presentCount;
            _absentCount = absentCount;
            _totalStudents = presentCount + absentCount;
          } else {
            // Try to extract from other data like "Total Students: N" string
            String dataStr = data.toString();
            RegExp totalRegex = RegExp(r'Total Students: (\d+)');
            RegExp presentRegex = RegExp(r'Present: (\d+)');
            RegExp absentRegex = RegExp(r'Absent: (\d+)');
            
            Match? totalMatch = totalRegex.firstMatch(dataStr);
            Match? presentMatch = presentRegex.firstMatch(dataStr);
            Match? absentMatch = absentRegex.firstMatch(dataStr);
            
            if (totalMatch != null) {
              _totalStudents = int.tryParse(totalMatch.group(1) ?? '0') ?? 0;
            } else if (presentMatch != null && absentMatch != null) {
              int presentCount = int.tryParse(presentMatch.group(1) ?? '0') ?? 0;
              int absentCount = int.tryParse(absentMatch.group(1) ?? '0') ?? 0;
              _presentCount = presentCount > 0 ? presentCount : _presentCount;
              _absentCount = absentCount;
              _totalStudents = _presentCount + _absentCount;
              print('Extracted from regex - Present: $_presentCount, Absent: $_absentCount, Total: $_totalStudents');
            } else {
              _totalStudents = _presentCount;
              _absentCount = 0;
            }
          }
        } else {
          // Last resort: set total to present count (no absent students)
          _totalStudents = _presentCount;
          _absentCount = 0;
        }
      }
      
      // Safety check to ensure absent count isn't negative
      if (_absentCount < 0) _absentCount = 0;
      // Ensure total students is at least the sum of present and absent
      if (_totalStudents < (_presentCount + _absentCount)) {
        _totalStudents = _presentCount + _absentCount;
      }
      
      print('Final counts - Present: $_presentCount, Absent: $_absentCount, Total: $_totalStudents');
      
      // Process attendance data maintaining exact format
      List<Map<String, dynamic>> realAttendanceData = [];
      
      // Add present students with their actual time marks
      for (var student in attendees) {
        if (student is Map<String, dynamic>) {
          final timestamp = student['timestamp'];
          String timeMarked;
          
          if (timestamp is int) {
            // Handle integer timestamp (milliseconds since epoch)
            timeMarked = DateTime.fromMillisecondsSinceEpoch(timestamp)
                .toString().split(' ')[1].substring(0, 5);
          } else if (timestamp is String) {
            // Handle string timestamp (either ISO format or already formatted)
            try {
              if (timestamp.contains('T')) {
                // ISO format like "2025-03-21T15:09:47.767158"
                final parsedTime = DateTime.parse(timestamp);
                timeMarked = "${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}";
              } else {
                // Already formatted time string
                timeMarked = timestamp;
              }
            } catch (e) {
              print('Time parsing error: $e');
              timeMarked = data['startTime'] ?? 'N/A';
            }
          } else {
            // Fallback to session start time
            timeMarked = data['startTime'] ?? 'N/A';
          }
              
          // Special handling for ACSC208 and COSC101 students who may have different field names
          final studentName = student['studentName'] ?? 
                       student['name'] ?? 
                       'Unknown Student';
                       
          final studentEmail = student['studentEmail'] ?? 
                        student['email'] ?? 
                        '';
                        
          final studentYear = student['year'];
          final yearString = studentYear != null ? studentYear.toString() : '';
          final regNumber = student['registrationNumber'] ?? 
                       studentEmail.toString().split('@')[0] ?? '';
          
          // Update student eligibility data for this session
          final studentId = regNumber.isNotEmpty ? regNumber : studentEmail;
          if (studentId.isNotEmpty) {
            if (!_studentEligibility.containsKey(studentId)) {
              _studentEligibility[studentId] = {
                'name': studentName,
                'email': studentEmail,
                'registrationNumber': regNumber,
                'attendedHours': 0.0,
                'attendedSessions': 0,
                'sessionsData': [],
              };
            }
            
            // Check if this session was already counted for this student
            final sessionDate = data['date'] ?? '';
            final sessionTime = data['startTime'] ?? '';
            final sessionId = '$unitCode-$sessionDate-$sessionTime';
            
            bool alreadyCounted = false;
            for (var session in _studentEligibility[studentId]!['sessionsData']) {
              if (session['sessionId'] == sessionId) {
                alreadyCounted = true;
                break;
              }
            }
            
            if (!alreadyCounted) {
              _studentEligibility[studentId]!['attendedHours'] += sessionDuration;
              _studentEligibility[studentId]!['attendedSessions']++;
              _studentEligibility[studentId]!['sessionsData'].add({
                'sessionId': sessionId,
                'date': sessionDate,
                'time': sessionTime,
                'duration': sessionDuration,
          });
        }
      }
      
          realAttendanceData.add({
            'name': studentName,
            'email': studentEmail,
            'status': 'Present',
            'timeMarked': timeMarked,
            'registrationNumber': regNumber,
            'year': yearString,
            'eligibility': _calculateEligibilityPercent(_studentEligibility[studentId]?['attendedHours'] ?? 0.0),
          });
        }
      }
      
      // Add absent students from selected students list who aren't in attendees
      final attendeeEmails = attendees
          .map((a) => a is Map<String, dynamic> 
               ? (a['studentEmail'] ?? a['email'] ?? '').toString().toLowerCase() 
               : '')
          .toSet();
      
      // Process absent students with different approaches to ensure they are included
      // First, get any explicit absentees list
      final List<dynamic> absenteesList = data['absentees'] ?? [];
      for (var student in absenteesList) {
        if (student is Map<String, dynamic>) {
          final email = (student['studentEmail'] ?? student['email'] ?? '').toString().toLowerCase();
          if (email.isNotEmpty && !attendeeEmails.contains(email)) {
            final studentName = student['studentName'] ?? student['name'] ?? 'Unknown Student';
            final studentYear = student['year'];
            final yearString = studentYear != null ? studentYear.toString() : '';
            final regNumber = student['registrationNumber'] ?? 
                         (email.isNotEmpty ? email.split('@')[0] : '');
            
            // Check eligibility for absent student too
            final studentId = regNumber.isNotEmpty ? regNumber : email;
            final attendedHours = _studentEligibility[studentId]?['attendedHours'] ?? 0.0;
            
            realAttendanceData.add({
              'name': studentName,
              'email': email,
              'status': 'Absent',
              'timeMarked': 'null', // Exact format from print attendance
              'registrationNumber': regNumber,
              'year': yearString,
              'eligibility': _calculateEligibilityPercent(attendedHours),
            });
          }
        }
      }
      
      // Then, try to get absent students from selectedStudents list
      for (var student in selectedStudents) {
        if (student is Map<String, dynamic>) {
          final email = (student['email'] ?? '').toString().toLowerCase();
          if (email.isNotEmpty && !attendeeEmails.contains(email)) {
            // Check if already added from absentees list
            bool alreadyAdded = false;
            for (var existingStudent in realAttendanceData) {
              final existingEmail = (existingStudent['email'] ?? '').toString().toLowerCase();
              if (existingEmail == email) {
                alreadyAdded = true;
                break;
              }
            }
            
            if (!alreadyAdded) {
              final studentName = student['name'] ?? 'Unknown Student';
              final studentYear = student['year'];
              final yearString = studentYear != null ? studentYear.toString() : '';
              final regNumber = student['registrationNumber'] ?? 
                            (email.isNotEmpty ? email.split('@')[0] : '');
              
              // Check eligibility for absent student too
              final studentId = regNumber.isNotEmpty ? regNumber : email;
              final attendedHours = _studentEligibility[studentId]?['attendedHours'] ?? 0.0;
              
              realAttendanceData.add({
                'name': studentName,
                'email': email,
                'status': 'Absent',
                'timeMarked': 'null', // Exact format from print attendance
                'registrationNumber': regNumber,
                'year': yearString,
                'eligibility': _calculateEligibilityPercent(attendedHours),
              });
            }
          }
        }
      }
      
      // Create placeholder absent students if we still need more
      final int absentStudentsNeeded = _absentCount - realAttendanceData.where((s) => s['status'] == 'Absent').length;
      if (absentStudentsNeeded > 0) {
        // Get absent students from session data directly
        final absenteesList = data['absentees'] as List<dynamic>? ?? [];
        
        // Use the previously defined set of attendee emails
        final knownAttendeeEmails = attendeeEmails;
        
        // Add missing absentees from the absentees list
        for (var absentee in absenteesList) {
          if (absentee is Map<String, dynamic>) {
            final email = (absentee['email'] ?? absentee['studentEmail'] ?? '').toString().toLowerCase();
            
            if (email.isNotEmpty && !knownAttendeeEmails.contains(email)) {
              // Check if already added from previous loop
              bool alreadyAdded = false;
              for (var existingStudent in realAttendanceData) {
                if ((existingStudent['email'] ?? '').toString().toLowerCase() == email) {
                  alreadyAdded = true;
                  break;
                }
              }
              
              if (!alreadyAdded) {
                final studentName = absentee['name'] ?? absentee['studentName'] ?? 'Unknown Student';
                final regNumber = absentee['registrationNumber'] ?? (email.isNotEmpty ? email.split('@')[0] : '');
                
                // Check eligibility for absent student too
                final studentId = regNumber.isNotEmpty ? regNumber : email;
                final attendedHours = _studentEligibility[studentId]?['attendedHours'] ?? 0.0;
                
                realAttendanceData.add({
                  'name': studentName,
                  'email': email,
                  'status': 'Absent',
                  'timeMarked': 'null',
                  'registrationNumber': regNumber,
                  'year': '0.0',
                  'eligibility': _calculateEligibilityPercent(attendedHours),
                });
              }
            }
          }
        }
        
        // If we still need more absent students, check attendeeDetails for records marked as absent
        if (realAttendanceData.where((s) => s['status'] == 'Absent').length < _absentCount && 
            data.containsKey('attendeeDetails')) {
          final attendeeDetails = data['attendeeDetails'] as List<dynamic>? ?? [];
          
          for (var attendee in attendeeDetails) {
            if (attendee is Map<String, dynamic>) {
              final details = attendee['details'];
              bool isAbsent = false;
              
              if (details is Map) {
                if (details.containsKey('status') && details['status'] == 'absent') {
                  isAbsent = true;
                } else if (details.containsKey('timestamp') && details['timestamp'] == null) {
                  isAbsent = true;
                }
              }
              
              if (isAbsent) {
                final email = (attendee['email'] ?? '').toString().toLowerCase();
                
                // Check if already added
                bool alreadyAdded = false;
                for (var existingStudent in realAttendanceData) {
                  if ((existingStudent['email'] ?? '').toString().toLowerCase() == email) {
                    alreadyAdded = true;
                    break;
                  }
                }
                
                if (!alreadyAdded && email.isNotEmpty) {
                  final studentName = details is Map ? (details['name'] ?? details['studentName'] ?? 'Unknown Student') : 'Unknown Student';
                  final regNumber = attendee['registrationNumber'] ?? (email.isNotEmpty ? email.split('@')[0] : '');
                  
                  // Check eligibility for absent student too
                  final studentId = regNumber.isNotEmpty ? regNumber : email;
                  final attendedHours = _studentEligibility[studentId]?['attendedHours'] ?? 0.0;
                  
                  realAttendanceData.add({
                    'name': studentName,
                    'email': email,
                    'status': 'Absent',
                    'timeMarked': 'null',
                    'registrationNumber': regNumber,
                    'year': '0.0',
                    'eligibility': _calculateEligibilityPercent(attendedHours),
                  });
                }
              }
            }
          }
        }
      }
      
      print('Added ${realAttendanceData.where((s) => s['status'] == 'Absent').length} absent students out of required $_absentCount');
      
      // Update state with actual data
      setState(() {
        _attendanceData = realAttendanceData;
        _attendanceTrends = {
          'Present': _presentCount,
          'Absent': _absentCount,
        };
        
        // Process related sessions eligibility if available
        if (widget.relatedSessions != null && widget.relatedSessions!.isNotEmpty) {
          for (var relatedSession in widget.relatedSessions!) {
            // Process related session attendance for eligibility
            _processRelatedSessionForEligibility(relatedSession);
          }
        }
        
        // Day analysis based on actual date
        final date = data['date'] as String?;
        if (date != null && date.isNotEmpty) {
          try {
            final parsedDate = DateFormat('yyyy-MM-dd').parse(date);
            final dayOfWeek = DateFormat('EEEE').format(parsedDate);
            
            // Set attendance patterns based on actual data
            if (_absentCount > _presentCount) {
              _mostAbsentDays = [dayOfWeek];
              _mostAttendedDays = [];
            } else if (_presentCount > _absentCount) {
              _mostAttendedDays = [dayOfWeek];
              _mostAbsentDays = [];
            } else {
              // Equal attendance
              _mostAttendedDays = [dayOfWeek];
              _mostAbsentDays = [dayOfWeek];
        }
      } catch (e) {
            print('Date parsing error: $e');
            _mostAbsentDays = [];
            _mostAttendedDays = [];
          }
        } else {
          _mostAbsentDays = [];
          _mostAttendedDays = [];
        }
        
        _isLoading = false;
      });
      
    } catch (e) {
      print('Analysis error: $e');
      if (mounted) {
      setState(() {
          _isLoading = false;
          _attendanceData = [];
          _totalStudents = 0;
          _presentCount = 0;
          _absentCount = 0;
          _attendanceTrends = {'Present': 0, 'Absent': 0};
        _timeOfDayTrends = {
            'Morning (8AM-12PM)': 0.0,
            'Afternoon (12PM-4PM)': 0.0,
            'Evening (4PM-8PM)': 0.0,
          };
          _mostAbsentDays = [];
          _mostAttendedDays = [];
        });
      }
    }
  }
  
  // Helper method to process related sessions for eligibility
  void _processRelatedSessionForEligibility(Map<String, dynamic> sessionData) {
    try {
      final unitCode = sessionData['unitCode'] as String?;
      final List<dynamic> attendees = sessionData['attendees'] ?? [];
      final sessionDate = sessionData['date'] ?? '';
      final sessionTime = sessionData['startTime'] ?? '';
      final sessionId = '$unitCode-$sessionDate-$sessionTime';
      
      // Get session duration in hours (default to 2 hours if not specified)
      final sessionDuration = sessionData['sessionDuration'] != null 
          ? _parseDurationToHours(sessionData['sessionDuration'].toString()) 
          : 2.0;
      
      // Process attendees
      for (var student in attendees) {
        if (student is Map<String, dynamic>) {
          final studentName = student['studentName'] ?? 
                       student['name'] ?? 
                       'Unknown Student';
                       
          final studentEmail = student['studentEmail'] ?? 
                        student['email'] ?? 
                        '';
                        
          final regNumber = student['registrationNumber'] ?? 
                       studentEmail.toString().split('@')[0] ?? '';
                       
          // Update student eligibility
          final studentId = regNumber.isNotEmpty ? regNumber : studentEmail;
          if (studentId.isNotEmpty) {
            if (!_studentEligibility.containsKey(studentId)) {
              _studentEligibility[studentId] = {
                'name': studentName,
                'email': studentEmail,
                'registrationNumber': regNumber,
                'attendedHours': 0.0,
                'attendedSessions': 0,
                'sessionsData': [],
              };
            }
            
            // Check if this session was already counted
            bool alreadyCounted = false;
            for (var session in _studentEligibility[studentId]!['sessionsData']) {
              if (session['sessionId'] == sessionId) {
                alreadyCounted = true;
                break;
              }
            }
            
            if (!alreadyCounted) {
              _studentEligibility[studentId]!['attendedHours'] += sessionDuration;
              _studentEligibility[studentId]!['attendedSessions']++;
              _studentEligibility[studentId]!['sessionsData'].add({
                'sessionId': sessionId,
                'date': sessionDate,
                'time': sessionTime,
                'duration': sessionDuration,
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error processing related session: $e');
    }
  }
  
  // Helper to parse duration string to hours
  double _parseDurationToHours(String durationStr) {
    try {
      // Handle common formats like "2 hours", "1.5 hours", "90 minutes"
      durationStr = durationStr.toLowerCase();
      if (durationStr.contains('hour')) {
        // Format like "2 hours" or "2.5 hours"
        final hourValue = double.tryParse(durationStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        return hourValue;
      } else if (durationStr.contains('min')) {
        // Format like "90 minutes"
        final minuteValue = double.tryParse(durationStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        return minuteValue / 60.0;
      } else {
        // Try to parse as just a number (assume hours)
        return double.tryParse(durationStr) ?? 2.0;
      }
    } catch (e) {
      print('Duration parsing error: $e');
      return 2.0; // Default to 2 hours
    }
  }
  
  // Calculate eligibility percentage
  double _calculateEligibilityPercent(double attendedHours) {
    return (attendedHours / _totalRequiredHours) * 100.0;
  }
  
  // Check if student is eligible for exam
  bool _isEligibleForExam(double attendedHours) {
    return attendedHours > _minimumRequiredHours;
  }
  
  // Helper to get PDF color for eligibility
  PdfColor _getPdfEligibilityColor(double percent) {
    if (percent >= 70) return PdfColors.green;
    if (percent >= 40) return PdfColors.orange;
    return PdfColors.red;
  }
  
  // Helper to extract student reg number from email
  String _extractRegNumber(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    return parts[0];
  }
  
  Future<void> _printAnalysis() async {
    final pdf = pw.Document();
    
    // Extract session data
    final unitCode = widget.sessionData['unitCode'] ?? 'Unknown Unit';
    final unitName = widget.sessionData['unitName'] ?? 'Unknown';
    final dateStr = widget.sessionData['date'] ?? 'Unknown Date';
    
    // Extract department, course, year and semester data
    final department = widget.sessionData['department'] ?? 'Computer Science';
    final course = widget.sessionData['course'] ?? 'Computer Science';
    final year = widget.sessionData['year']?.toString() ?? '3';
    final semester = widget.sessionData['semester']?.toString() ?? '2';
    
    // Extract attendees and calculate counts
    int presentCount = 0;
    int absentCount = 0;
    
    for (var student in _attendanceData) {
      if (student['status'] == 'Present') {
        presentCount++;
      } else {
        absentCount++;
      }
    }
    
    int totalStudents = presentCount + absentCount;
    
    // Safely try to load logo, but continue if it fails
    pw.MemoryImage? logoImage;
    pw.MemoryImage? qrCodeLogo;
    
    try {
      // Load university logo
      final ByteData logoData = await rootBundle.load('assets/images/university_logo.png');
      if (logoData != null) {
        final Uint8List logoBytes = logoData.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoBytes);
      }
      
      // Load QR Code app logo/icon
      final ByteData qrCodeData = await rootBundle.load('assets/images/icons.png');
      if (qrCodeData != null) {
        final Uint8List qrCodeBytes = qrCodeData.buffer.asUint8List();
        qrCodeLogo = pw.MemoryImage(qrCodeBytes);
      }
    } catch (e) {
      print('Logo loading error: $e');
      // Continue without logo
    }
    
    // First page - Main report
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 10, // Support up to 10 pages if needed
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Header(
              level: 0,
              child: pw.Text('ATTENDANCE ANALYSIS REPORT - Continued', 
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)
              )
            );
          }
          return pw.Container(); // No header on first page
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                color: PdfColors.grey700,
                fontSize: 10,
              ),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Header with logo - stretch to fit full width
            pw.Center(
              child: logoImage != null 
                  ? pw.Container(
                      width: 500, // Full width of the page (with margins)
                      child: pw.Image(logoImage, fit: pw.BoxFit.fitWidth)
                    )
                  : pw.Container(
                      width: 500,
                      height: 65,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(),
                      ),
                      child: pw.Center(
                        child: pw.Text('UNIVERSITY LOGO', style: pw.TextStyle(fontSize: 12)),
                      ),
                    ),
            ),
            
              pw.SizedBox(height: 20),
            
            // Report title
              pw.Center(
                child: pw.Text(
                'ATTENDANCE ANALYSIS REPORT',
                  style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Unit information and attendance requirements
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Unit Code: $unitCode'),
                    pw.Text('Unit Title: $unitName'),
              pw.Text('Date: $dateStr'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total Students: $totalStudents'),
                    pw.Text('Required Attendance: 70%'),
                    pw.Text('Required Hours: $_minimumRequiredHours of $_totalRequiredHours'),
                  ],
                ),
              ],
            ),
            
              pw.SizedBox(height: 20),
              
            // Department, Course, Year and Semester information box
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              padding: pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Department: $department'),
                  pw.Text('Course: $course'),
                  pw.Text('Year: $year, Semester: $semester'),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Attendance Summary
            pw.Text('Attendance Summary:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)
              ),
              pw.SizedBox(height: 10),
              
            // Attendance Overview box
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              padding: pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Add label for the chart
                  pw.Text('Present vs Absent Students:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  // Visual representation of attendance
                  pw.Container(
                    height: 20,
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: presentCount,
                          child: pw.Container(color: PdfColors.green),
                        ),
                        pw.Expanded(
                          flex: absentCount,
                          child: pw.Container(color: PdfColors.red),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(width: 10, height: 10, color: PdfColors.green),
                          pw.SizedBox(width: 5),
                          pw.Text('Present: ${totalStudents > 0 ? ((presentCount / totalStudents) * 100).toStringAsFixed(0) : 0}%', 
                            style: pw.TextStyle(color: PdfColors.green, fontSize: 9)),
                        ]
                      ),
                      pw.Row(
                        children: [
                          pw.Container(width: 10, height: 10, color: PdfColors.red),
                          pw.SizedBox(width: 5),
                          pw.Text('Absent: ${totalStudents > 0 ? ((absentCount / totalStudents) * 100).toStringAsFixed(0) : 0}%', 
                            style: pw.TextStyle(color: PdfColors.red, fontSize: 9)),
                        ]
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 10),
            
            // Table showing attendance categories
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Padding(
                padding: pw.EdgeInsets.all(8),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Eligible for Exams (>70%)', style: pw.TextStyle(fontSize: 10)),
                        pw.Text('${_getEligibleCount()} / $totalStudents (${totalStudents > 0 ? ((_getEligibleCount() / totalStudents) * 100).toStringAsFixed(0) : 0}%)', 
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.green)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('At Risk Students (<70%)', style: pw.TextStyle(fontSize: 10)),
                        pw.Text('${_getAtRiskCount()} / $totalStudents (${totalStudents > 0 ? ((_getAtRiskCount() / totalStudents) * 100).toStringAsFixed(0) : 0}%)', 
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.orange)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Full Attendance', style: pw.TextStyle(fontSize: 10)),
                        pw.Text('$presentCount / $totalStudents (${totalStudents > 0 ? ((presentCount / totalStudents) * 100).toStringAsFixed(0) : 0}%)', 
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.blue)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Low Attendance', style: pw.TextStyle(fontSize: 10)),
                        pw.Text('$absentCount / $totalStudents (${totalStudents > 0 ? ((absentCount / totalStudents) * 100).toStringAsFixed(0) : 0}%)', 
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.red)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Student Attendance Details
            pw.Text('Student Attendance Details:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)
              ),
              pw.SizedBox(height: 10),
              
              // Table showing individual student attendance
              pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  // Header row
                  pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Student Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Email', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Attendance %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Hours', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(5),
                      child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                    ]
                  ),
                  
                // If no students, show empty row
                if (_attendanceData.isEmpty)
                  pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                        child: pw.Text('No Data', style: pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                        child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                        child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
                      ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                        child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                        child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                        child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
                      ),
                    ]
                  ),
                
                // Data rows - show all students
                ...List<pw.TableRow>.from(_attendanceData.map((student) {
                  final studentId = student['registrationNumber'] ?? student['email'] ?? '';
                  final attendedHours = _studentEligibility[studentId]?['attendedHours'] ?? 0.0;
                  final isEligible = _isEligibleForExam(attendedHours);
                  final eligibilityPercent = _calculateEligibilityPercent(attendedHours);
                  final status = student['status'] as String;
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(student['name'], style: pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(student['email'], style: pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('${eligibilityPercent.toStringAsFixed(0)}%', style: pw.TextStyle(fontSize: 10)),
                  ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(attendedHours.toStringAsFixed(1), style: pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(
                          isEligible ? 'Eligible' : (eligibilityPercent >= 50 ? 'At Risk' : 'Low'),
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(
                          status,
                          style: pw.TextStyle(
                            color: status == 'Present' ? PdfColors.green : PdfColors.red,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList()),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
            // Session Details
            pw.Text('Session Details:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)
              ),
              pw.SizedBox(height: 10),
              
            // Session details table
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              padding: pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Start Time: ${widget.sessionData['startTime'] ?? 'Unknown'}'),
                          pw.Text('End Time: ${widget.sessionData['endTime'] ?? 'Unknown'}'),
                          pw.Text('Duration: ${widget.sessionData['sessionDuration'] ?? '2 hours'}'),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Week: ${widget.sessionData['week']}'),
                          pw.Text('Day: ${widget.sessionData['day']}'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
              
              pw.SizedBox(height: 20),
              
              // Recommendations
            pw.Text('Recommendations:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)
              ),
              pw.SizedBox(height: 10),
            
            // Recommendations box
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              padding: pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('1. Students with attendance below 70% are at risk of being barred from examinations.', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 5),
                  pw.Text('2. Consider conducting intervention sessions for students with low attendance.', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 5),
                  pw.Text('3. Review teaching strategies for sessions with generally low attendance.', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 5),
                  pw.Text('4. Required minimum attendance for exams: $_minimumRequiredHours hours out of $_totalRequiredHours hours.', style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 40),
            
            // Generation info at the bottom left
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}', 
                  style: pw.TextStyle(fontSize: 8)),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // QR Code App logo and ISO certification centered at the very bottom
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('Approved', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  qrCodeLogo != null 
                  ? pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      padding: pw.EdgeInsets.all(10),
                      child: pw.Image(qrCodeLogo)
                    )
                  : pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      padding: pw.EdgeInsets.all(10),
                      child: pw.Center(
                        child: pw.Text('QrCode\nApp', textAlign: pw.TextAlign.center)
                      )
                    ),
                  pw.SizedBox(height: 5),
                  pw.Text('TUN is ISO 9001:2015 Certified.', 
                    style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                ],
              ),
            ),
          ];
        },
      ),
    );
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save()
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isLoading ? null : _printAnalysis,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
            children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing attendance data...'),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Session info card
                _buildSessionInfoCard(),
              SizedBox(height: 16),
                _buildStudentDetailsSection(),
                SizedBox(height: 16),
                // Attendance summary card with dynamic data
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Summary',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                color: Colors.green,
                                value: _presentCount.toDouble(),
                                  title: 'Present\n$_presentCount',
                                radius: 80,
                                titleStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              PieChartSectionData(
                                color: Colors.red,
                                value: _absentCount > 0 ? _absentCount.toDouble() : 0.01, // Ensure visible even if 0 for UI
                                title: 'Absent\n$_absentCount',
                                radius: 80,
                                titleStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 0,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                        // Attendance percentage
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              'Attendance Rate: ${_calculateAttendanceRate()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _getAttendanceColor(_calculateAttendanceRate()),
                              ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                        // Detailed breakdown
                      Text(
                          'Detailed Breakdown',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                        _buildAttendanceDetailTile(
                          'Present Students',
                          _presentCount,
                          _totalStudents,
                          Colors.green,
                        ),
                        _buildAttendanceDetailTile(
                          'Absent Students',
                          _absentCount,
                          _totalStudents,
                          Colors.red,
                        ),
                        
                        // Time information
                        SizedBox(height: 16),
                              Text(
                          'Session Timing',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Duration: ${widget.sessionData['sessionDuration'] ?? 'Unknown'}'),
                        Text('Start Time: ${widget.sessionData['startTime'] ?? 'Unknown'}'),
                        Text('End Time: ${widget.sessionData['endTime'] ?? 'Unknown'}'),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Exam Eligibility Card (replacing Time of Day chart)
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXAM ELIGIBILITY ANALYSIS',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Students need to attend more than $_minimumRequiredHours hours out of $_totalRequiredHours total hours to be eligible for the end of semester exam.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Eligibility progress bar
                      LinearProgressIndicator(
                        value: _getAverageEligibilityRate() / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_getEligibilityColor(_getAverageEligibilityRate())),
                        minHeight: 10,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0 hours'),
                          Text(
                            'Average: ${_getAverageEligibilityRate().toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('$_totalRequiredHours hours'),
                        ],
                      ),
                      SizedBox(height: 20),
                      
                      // Eligibility summary
                      Text(
                        'ELIGIBILITY SUMMARY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildEligibilityDetailTile(
                        'Eligible Students',
                        _getEligibleCount(),
                        _totalStudents,
                        Colors.green,
                      ),
                      _buildEligibilityDetailTile(
                        'At Risk Students',
                        _getAtRiskCount(),
                        _totalStudents,
                        Colors.orange,
                      ),
                      _buildEligibilityDetailTile(
                        'Ineligible Students',
                        _getIneligibleCount(),
                        _totalStudents,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
    );
  }

  // Helper methods for eligibility statistics
  double _getAverageEligibilityRate() {
    if (_studentEligibility.isEmpty) return 0.0;
    
    double totalHours = 0.0;
    for (var student in _studentEligibility.values) {
      totalHours += student['attendedHours'] as double;
    }
    
    return (totalHours / (_studentEligibility.length * _totalRequiredHours)) * 100.0;
  }
  
  int _getEligibleCount() {
    int eligibleCount = 0;
    for (var student in _studentEligibility.values) {
      double hours = student['attendedHours'] as double;
      if (_isEligibleForExam(hours)) {
        eligibleCount++;
      }
    }
    return eligibleCount;
  }
  
  int _getAtRiskCount() {
    int atRiskCount = 0;
    for (var student in _studentEligibility.values) {
      double hours = student['attendedHours'] as double;
      if (!_isEligibleForExam(hours) && hours >= _minimumRequiredHours * 0.7) {
        atRiskCount++;
      }
    }
    return atRiskCount;
  }
  
  int _getIneligibleCount() {
    int ineligibleCount = 0;
    for (var student in _studentEligibility.values) {
      double hours = student['attendedHours'] as double;
      if (!_isEligibleForExam(hours) && hours < _minimumRequiredHours * 0.7) {
        ineligibleCount++;
      }
    }
    return ineligibleCount;
  }
  
  Color _getEligibilityColor(double percent) {
    if (percent >= 70) return Colors.green;
    if (percent >= 40) return Colors.orange;
    return Colors.red;
  }
  
  Widget _buildEligibilityDetailTile(String title, int count, int total, Color color) {
    double percentage = 0.0;
    if (total > 0) {
      percentage = (count / total * 100);
      percentage = percentage.isNaN ? 0.0 : percentage.roundToDouble();
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDetailsSection() {
    return Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Attendance Details',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
            
            // Table header in light gray background
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Reg. No', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Hours', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Eligible', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            
            // Present students section - keep as is
                      ..._attendanceData
                        .where((student) => student['status'] == 'Present')
              .map((student) {
                final studentId = student['registrationNumber'] ?? student['email'] ?? '';
                final attendedHours = _studentEligibility[studentId]?['attendedHours'] ?? 0.0;
                final isEligible = _isEligibleForExam(attendedHours);
                final eligibilityPercent = _calculateEligibilityPercent(attendedHours);
                
                return Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(student['name'])),
                      Expanded(flex: 2, child: Text(_extractRegNumber(student['email']))),
                      Expanded(flex: 1, child: Text('2.0')), // Year shown as 2.0 like in screenshot
                      Expanded(flex: 1, child: Text('${attendedHours.toStringAsFixed(1)}')),
                      Expanded(
                        flex: 1, 
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Present',
                            style: TextStyle(color: Colors.green[800], fontSize: 12),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isEligible ? Colors.green[100] : Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${eligibilityPercent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: isEligible ? Colors.green[800] : Colors.red[800],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            
            // Divider between present and absent students
            if (_presentCount > 0 && _absentCount > 0) Divider(height: 32),
            
            // Absent students section
            ..._buildAbsentStudentsList(),
          ],
        ),
      ),
    );
  }

  // New helper method to generate absent student widgets
  List<Widget> _buildAbsentStudentsList() {
    // Make sure we have the correct count of absent students
    List<Map<String, dynamic>> absentStudents = _attendanceData
        .where((student) => student['status'] == 'Absent')
        .toList();
    
    // If we don't have enough absent students in the data, create placeholders as needed
    if (absentStudents.length < _absentCount) {
      print('Not enough absent students in data: ${absentStudents.length} < $_absentCount');
      
      // Get data from the real session data instead of hardcoding
      final absenteesList = widget.sessionData['absentees'] as List<dynamic>? ?? [];
      
      for (var absentee in absenteesList) {
        if (absentee is Map<String, dynamic>) {
          final name = absentee['name'] ?? absentee['studentName'] ?? '';
          final email = absentee['email'] ?? absentee['studentEmail'] ?? '';
          
          // Check if student is already in the list
          bool alreadyAdded = absentStudents.any((s) => 
            (s['email'] == email) || (s['name'] == name && name.isNotEmpty));
            
          if (!alreadyAdded && name.isNotEmpty) {
            final regNumber = email.contains('@') ? email.split('@')[0] : '';
            
            absentStudents.add({
              'name': name,
              'email': email,
              'status': 'Absent',
              'timeMarked': 'null',
              'registrationNumber': regNumber,
              'year': '0.0',
              'eligibility': 0.0,
            });
          }
        }
      }
      
      // If still missing students, check attendeeDetails for more absent students
      if (absentStudents.length < _absentCount && widget.sessionData.containsKey('attendeeDetails')) {
        final attendeeDetails = widget.sessionData['attendeeDetails'] as List<dynamic>? ?? [];
        
        for (var attendee in attendeeDetails) {
          if (attendee is Map<String, dynamic>) {
            final details = attendee['details'] as Map<String, dynamic>? ?? {};
            
            if (details.containsKey('status') && details['status'] == 'absent') {
              final name = details['name'] ?? details['studentName'] ?? 'Student';
              final email = attendee['email'] ?? '';
              
              // Check if student is already in the list
              bool alreadyAdded = absentStudents.any((s) => 
                (s['email'] == email) || (s['name'] == name && name.isNotEmpty));
                
              if (!alreadyAdded) {
                final regNumber = email.contains('@') ? email.split('@')[0] : '';
                
                absentStudents.add({
                  'name': name,
                  'email': email,
                  'status': 'Absent',
                  'timeMarked': 'null',
                  'registrationNumber': regNumber,
                  'year': '0.0',
                  'eligibility': 0.0,
                });
              }
            }
          }
        }
      }
    }
    
    print('Rendering ${absentStudents.length} absent students');
    
    // Map the absent students to widgets
    return absentStudents.map((student) {
      final studentId = student['registrationNumber'] ?? student['email'] ?? '';
      final attendedHours = _studentEligibility[studentId]?['attendedHours'] ?? 0.0;
      final isEligible = _isEligibleForExam(attendedHours);
      final eligibilityPercent = _calculateEligibilityPercent(attendedHours);
      
      return Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          color: Colors.red[50], // Light red background
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(student['name'], style: TextStyle(color: Colors.red[900]))),
            Expanded(flex: 2, child: Text(_extractRegNumber(student['email']), style: TextStyle(color: Colors.red[900]))),
            Expanded(flex: 1, child: Text('0.0', style: TextStyle(color: Colors.red[900]))), // 0.0 for absent students
            Expanded(flex: 1, child: Text('${attendedHours.toStringAsFixed(1)}', style: TextStyle(color: Colors.red[900]))),
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Absent',
                  style: TextStyle(color: Colors.red[900], fontSize: 12),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isEligible ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${eligibilityPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isEligible ? Colors.green[800] : Colors.red[800],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSessionInfoCard() {
    // Extract course information properly from session data
    final department = widget.sessionData['department'] ?? 'Computer Science';
    final course = widget.sessionData['course'] ?? 'Computer Science';
    
    // Extract the year and semester directly from original session data
    String year = widget.sessionData['year']?.toString() ?? '3';  // Default to 3 as shown in screenshot
    String semester = widget.sessionData['semester']?.toString() ?? '2';  // Default to 2 as shown in screenshot
    
    print("Using Year: $year, Semester: $semester");
    
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Department: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  department,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Course: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  course,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Year: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  year,
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  ', Semester: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  semester,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            ],
          ),
        ),
    );
  }

  double _calculateAttendanceRate() {
    if (_totalStudents == 0) return 0.0;
    double rate = (_presentCount / _totalStudents * 100);
    return rate.isNaN ? 0.0 : rate.roundToDouble();
  }

  Color _getAttendanceColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildAttendanceDetailTile(String title, int count, int total, Color color) {
    double percentage = 0.0;
    if (total > 0) {
      percentage = (count / total * 100);
      percentage = percentage.isNaN ? 0.0 : percentage.roundToDouble();
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 
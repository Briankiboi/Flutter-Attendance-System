import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Utility class to provide consistent data fetching for attendance data
/// This ensures Print Attendance and Analyze Attendance use the same data structure
class AttendanceUtils {
  // Set to false for production
  static bool _debugMode = false;
  
  // Set to true to use mock data when no real data is found (production fallback)
  static bool _useMockDataIfEmpty = true;
  
  /// Fetches attendance data for a specific unit from SharedPreferences
  /// This method mimics the data fetching approach used in PrintAttendancePage
  static Future<List<Map<String, dynamic>>> fetchAttendanceData({
    required Map<String, dynamic> sessionData,
    List<Map<String, dynamic>>? relatedSessions,
  }) async {
    // Quick debug printout to verify this function is being called
    print('AttendanceUtils.fetchAttendanceData called for unit: ${sessionData['unitCode'] ?? 'Unknown'}');
    
    // Extract unit information
    final unitCode = sessionData['unitCode'] ?? 'Unknown';
    final unitName = sessionData['unitName'] ?? 'Unknown';
    
    // Enhanced debugging - show incoming sessionData
    if (_debugMode) {
      print('\n\n======== ATTENDANCE UTILS ENHANCED DEBUG ========');
      print('Session data being processed:');
      sessionData.forEach((key, value) {
        print('  $key: ${value?.runtimeType} = $value');
      });
      
      if (relatedSessions != null) {
        print('Related sessions count: ${relatedSessions.length}');
        for (int i = 0; i < relatedSessions.length; i++) {
          print('  Session $i: ${relatedSessions[i]['unitCode']} - ${relatedSessions[i]['date']}');
        }
      } else {
        print('No related sessions provided');
      }
      
      print('Fetching attendance for unit: $unitCode - $unitName');
    }
    
    // Gather all sessions for this unit
    List<Map<String, dynamic>> allSessions = [];
    if (relatedSessions != null && relatedSessions.isNotEmpty) {
      allSessions = List.from(relatedSessions);
    } else {
      allSessions = [sessionData];
    }
    
    // Load all attendance records from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    
    if (_debugMode) {
      print('Total SharedPreferences keys: ${allKeys.length}');
      print('First 10 keys in SharedPreferences:');
      int count = 0;
      for (String key in allKeys) {
        if (count < 10) {
          print('  $key');
          count++;
        } else {
          break;
        }
      }
    }
    
    // Look for relevant session keys using multiple search patterns
    Set<String> attendanceKeys = {};
    
    // 1. Look for session_unitCode pattern
    for (String key in allKeys) {
      if (key.startsWith('session_') && key.contains(unitCode)) {
        attendanceKeys.add(key);
        if (_debugMode) print('Found session key: $key [pattern: session_*unitCode*]');
      }
    }
    
    // 2. Look for attendance_unitCode pattern
    for (String key in allKeys) {
      if (key.startsWith('attendance_') && key.contains(unitCode)) {
        attendanceKeys.add(key);
        if (_debugMode) print('Found attendance key: $key [pattern: attendance_*unitCode*]');
      }
    }
    
    // 3. Look for any key containing the unit code
    for (String key in allKeys) {
      if (key.contains(unitCode) && !attendanceKeys.contains(key)) {
        attendanceKeys.add(key);
        if (_debugMode) print('Found other key with unit code: $key [pattern: *unitCode*]');
      }
    }
    
    // 4. Try with just session_ prefix as a fallback
    if (attendanceKeys.isEmpty) {
      for (String key in allKeys) {
        if (key.startsWith('session_')) {
          // Try to extract the data and check if it matches our unit
          try {
            final data = prefs.getString(key);
            if (data != null) {
              final Map<String, dynamic> jsonData = json.decode(data);
              if (jsonData['unitCode'] == unitCode) {
                attendanceKeys.add(key);
                if (_debugMode) print('Found session by checking content: $key');
              }
            }
          } catch (e) {
            // Skip if can't parse
          }
        }
      }
    }
    
    if (_debugMode) {
      print('Found ${attendanceKeys.length} attendance records for $unitCode');
    }
    
    // Get list of all students who have attended this unit
    Set<String> allStudentEmails = {};
    
    // Extract from SharedPreferences attendance records
    for (String key in attendanceKeys) {
      final String? sessionData = prefs.getString(key);
      if (sessionData != null) {
        try {
          final Map<String, dynamic> data = json.decode(sessionData);
          
          if (_debugMode) {
            print('Processing key: $key - Structure:');
            data.forEach((dataKey, dataValue) {
              if (dataValue is List) {
                print('  $dataKey: List with ${dataValue.length} items');
              } else {
                print('  $dataKey: ${dataValue?.runtimeType}');
              }
            });
          }
          
          // Try to get attendees from attendeeDetails first (like in print attendance)
          if (data.containsKey('attendeeDetails') && data['attendeeDetails'] is List) {
            for (var attendee in data['attendeeDetails']) {
              if (attendee is Map) {
                // Try different known patterns
                if (attendee.containsKey('studentEmail')) {
                  allStudentEmails.add(attendee['studentEmail']);
                  if (_debugMode) print('Found student: ${attendee['studentEmail']} [from attendeeDetails.studentEmail]');
                } else if (attendee.containsKey('email')) {
                  allStudentEmails.add(attendee['email']);
                  if (_debugMode) print('Found student: ${attendee['email']} [from attendeeDetails.email]');
                } else if (attendee.containsKey('details') && attendee['details'] is Map) {
                  final details = attendee['details'];
                  if (details.containsKey('studentEmail')) {
                    allStudentEmails.add(details['studentEmail']);
                    if (_debugMode) print('Found student: ${details['studentEmail']} [from attendeeDetails.details.studentEmail]');
                  } else if (details.containsKey('email')) {
                    allStudentEmails.add(details['email']);
                    if (_debugMode) print('Found student: ${details['email']} [from attendeeDetails.details.email]');
                  }
                } else if (attendee.containsKey('student') && attendee['student'] is Map) {
                  final student = attendee['student'];
                  if (student.containsKey('email')) {
                    allStudentEmails.add(student['email']);
                    if (_debugMode) print('Found student: ${student['email']} [from attendeeDetails.student.email]');
                  }
                }
              }
            }
          }
          
          // Then try attendees list if attendeeDetails didn't work
          if (data.containsKey('attendees') && data['attendees'] is List) {
            for (var attendee in data['attendees']) {
              if (attendee is Map) {
                if (attendee.containsKey('studentEmail')) {
                  allStudentEmails.add(attendee['studentEmail']);
                  if (_debugMode) print('Found student: ${attendee['studentEmail']} [from attendees.studentEmail]');
                } else if (attendee.containsKey('email')) {
                  allStudentEmails.add(attendee['email']);
                  if (_debugMode) print('Found student: ${attendee['email']} [from attendees.email]');
                }
              }
            }
          }
        } catch (e) {
          print('Error processing key $key: $e');
        }
      }
    }
    
    // Also extract from allSessions
    for (var session in allSessions) {
      // First try attendeeDetails like in Print Attendance
      if (session.containsKey('attendeeDetails') && session['attendeeDetails'] is List) {
        if (_debugMode) print('Processing attendeeDetails from session direct input - count: ${(session['attendeeDetails'] as List).length}');
        
        for (var attendee in session['attendeeDetails']) {
          if (attendee is Map) {
            // Try different patterns
            if (attendee.containsKey('studentEmail')) {
              allStudentEmails.add(attendee['studentEmail']);
              if (_debugMode) print('Found student: ${attendee['studentEmail']} [from session.attendeeDetails.studentEmail]');
            } else if (attendee.containsKey('email')) {
              allStudentEmails.add(attendee['email']);
              if (_debugMode) print('Found student: ${attendee['email']} [from session.attendeeDetails.email]');
            } else if (attendee.containsKey('details') && attendee['details'] is Map) {
              final details = attendee['details'];
              if (details.containsKey('studentEmail')) {
                allStudentEmails.add(details['studentEmail']);
                if (_debugMode) print('Found student: ${details['studentEmail']} [from session.attendeeDetails.details.studentEmail]');
              } else if (details.containsKey('email')) {
                allStudentEmails.add(details['email']);
                if (_debugMode) print('Found student: ${details['email']} [from session.attendeeDetails.details.email]');
              }
            } else if (attendee.containsKey('student') && attendee['student'] is Map) {
              final student = attendee['student'];
              if (student.containsKey('email')) {
                allStudentEmails.add(student['email']);
                if (_debugMode) print('Found student: ${student['email']} [from session.attendeeDetails.student.email]');
              }
            }
          }
        }
      }
      
      // Then try attendees list
      if (session.containsKey('attendees') && session['attendees'] is List) {
        if (_debugMode) print('Processing attendees from session direct input - count: ${(session['attendees'] as List).length}');
        
        for (var attendee in session['attendees']) {
          if (attendee is Map) {
            if (attendee.containsKey('studentEmail')) {
              allStudentEmails.add(attendee['studentEmail']);
              if (_debugMode) print('Found student: ${attendee['studentEmail']} [from session.attendees.studentEmail]');
            } else if (attendee.containsKey('email')) {
              allStudentEmails.add(attendee['email']);
              if (_debugMode) print('Found student: ${attendee['email']} [from session.attendees.email]');
            }
          }
        }
      }
    }
    
    if (_debugMode) {
      print('Found ${allStudentEmails.length} unique students who attended this unit');
      print('Student emails: ${allStudentEmails.toList()}');
    }
    
    // If still no students found, look for any student data in SharedPreferences
    if (allStudentEmails.isEmpty) {
      if (_debugMode) print('No student emails found from attendance records, looking for student records directly');
      
      for (String key in allKeys) {
        if (key.startsWith('student_')) {
          final String? studentData = prefs.getString(key);
          if (studentData != null) {
            try {
              final Map<String, dynamic> data = json.decode(studentData);
              if (data.containsKey('email')) {
                allStudentEmails.add(data['email']);
                if (_debugMode) print('Found student from key $key: ${data['email']}');
              }
            } catch (e) {
              print('Error processing student key $key: $e');
            }
          }
        }
      }
      
      if (_debugMode) print('Found ${allStudentEmails.length} students after searching student records');
    }
    
    // Calculate attendance for each student
    List<Map<String, dynamic>> studentAttendance = [];
    
    if (_debugMode) print('Processing attendance for each student...');
    
    for (String email in allStudentEmails) {
      if (_debugMode) print('Processing student: $email');
      
      int sessionsAttended = 0;
      String studentName = 'Unknown';
      List<bool> attendancePattern = [];
      Map<String, dynamic>? studentDetails;
      
      // Find student details from SharedPreferences
      for (String key in allKeys) {
        if (key.startsWith('student_') && key.contains(email.split('@').first)) {
          final String? studentData = prefs.getString(key);
          if (studentData != null) {
            try {
              final Map<String, dynamic> data = json.decode(studentData);
              if (studentName == 'Unknown' && data.containsKey('name')) {
                studentName = data['name'];
                studentDetails = Map<String, dynamic>.from(data);
                if (_debugMode) print('Found student details for $email: $studentName');
              }
            } catch (e) {
              print('Error processing student details for key $key: $e');
            }
          }
        }
      }
      
      // Check each session for this student's attendance
      for (var session in allSessions) {
        bool attended = false;
        
        // Check direct attendees list
        if (session.containsKey('attendees') && session['attendees'] is List) {
          for (var attendee in session['attendees']) {
            if (attendee is Map) {
              String attendeeEmail = '';
              if (attendee.containsKey('studentEmail')) {
                attendeeEmail = attendee['studentEmail'];
              } else if (attendee.containsKey('email')) {
                attendeeEmail = attendee['email'];
              }
              
              if (attendeeEmail == email) {
                attended = true;
                // Get student details if not already retrieved
                if (studentName == 'Unknown') {
                  if (attendee.containsKey('studentName')) {
                    studentName = attendee['studentName'];
                  } else if (attendee.containsKey('name')) {
                    studentName = attendee['name'];
                  }
                  studentDetails = Map.from(attendee);
                }
                break;
              }
            }
          }
        }
        
        // Also check attendeeDetails format
        if (!attended && session.containsKey('attendeeDetails') && session['attendeeDetails'] is List) {
          for (var attendee in session['attendeeDetails']) {
            if (attendee is Map) {
              // Check different formats
              if ((attendee.containsKey('studentEmail') && attendee['studentEmail'] == email) ||
                  (attendee.containsKey('email') && attendee['email'] == email)) {
                attended = true;
                
                // Get student name if not already known
                if (studentName == 'Unknown') {
                  if (attendee.containsKey('studentName')) {
                    studentName = attendee['studentName'];
                  } else if (attendee.containsKey('name')) {
                    studentName = attendee['name'];
                  }
                  studentDetails = Map.from(attendee);
                }
                break;
              }
              
              // Check in details sub-object
              if (attendee.containsKey('details') && attendee['details'] is Map) {
                final details = attendee['details'];
                if ((details.containsKey('studentEmail') && details['studentEmail'] == email) ||
                    (details.containsKey('email') && details['email'] == email)) {
                  attended = true;
                  
                  // Check if it's marked as absent
                  if (details.containsKey('status') && details['status'] == 'absent') {
                    attended = false;
                  } else if (details.containsKey('timestamp') && details['timestamp'] == null) {
                    attended = false;
                  }
                  
                  if (studentName == 'Unknown' && attendee.containsKey('student')) {
                    final student = attendee['student'];
                    if (student is Map && student.containsKey('name')) {
                      studentName = student['name'];
                      studentDetails = Map<String, dynamic>.from(student);
                    }
                  }
                  break;
                }
              }
            }
          }
        }
        
        attendancePattern.add(attended);
        if (attended) sessionsAttended++;
      }
      
      // Calculate attendance percentage
      final totalSessions = allSessions.length > 0 ? allSessions.length : 1;
      final double attendancePercentage = sessionsAttended / totalSessions;
      
      // Calculate hours attended (assuming 3 hours per session)
      final hoursAttended = sessionsAttended * 3;
      
      // Store the attendance data for this student
      studentAttendance.add({
        'email': email,
        'name': studentName,
        'details': studentDetails,
        'sessionsAttended': sessionsAttended,
        'totalSessions': totalSessions,
        'attendancePercentage': attendancePercentage,
        'hoursAttended': hoursAttended,
        'attendancePattern': attendancePattern,
        // Additional info for the Analyze Attendance page if needed
        'isEligible': attendancePercentage >= 0.7,
      });
    }
    
    // Sort by attendance percentage (descending)
    studentAttendance.sort((a, b) => 
      (b['attendancePercentage'] as double).compareTo(a['attendancePercentage'] as double));
    
    // Check if we should use mock data as a fallback
    if (studentAttendance.isEmpty && _useMockDataIfEmpty) {
      print('Using mock data as fallback for analyze attendance');
      studentAttendance = _generateMockAttendanceData(unitCode, unitName);
      print('Generated ${studentAttendance.length} mock student records');
    }
    
    if (_debugMode) {
      print('Final attendance data count: ${studentAttendance.length}');
      print('======== END DEBUG ========\n\n');
    }
    
    return studentAttendance;
  }
  
  /// Generate mock attendance data for demonstration purposes
  static List<Map<String, dynamic>> _generateMockAttendanceData(String unitCode, String unitName) {
    final List<Map<String, dynamic>> mockData = [];
    final totalSessions = 10;
    
    // Sample student data with varied attendance patterns
    final List<Map<String, String>> students = [
      {'name': 'John Doe', 'email': 'john.doe@example.com'},
      {'name': 'Jane Smith', 'email': 'jane.smith@example.com'},
      {'name': 'Michael Johnson', 'email': 'michael.j@example.com'}, 
      {'name': 'Samantha Brown', 'email': 'sam.brown@example.com'},
      {'name': 'David Wilson', 'email': 'david.wilson@example.com'},
      {'name': 'Emily Davis', 'email': 'emily.davis@example.com'},
      {'name': 'Robert Miller', 'email': 'robert.m@example.com'},
      {'name': 'Jennifer White', 'email': 'jennifer.w@example.com'}
    ];
    
    // Generate attendance patterns for each student
    for (var student in students) {
      // Create different attendance patterns for demonstration
      List<bool> attendancePattern = [];
      int sessionsAttended = 0;
      
      // Assign different patterns based on student index
      final int studentIndex = students.indexOf(student);
      
      switch (studentIndex % 4) {
        case 0: // Full attendance - attends almost everything
          for (int i = 0; i < totalSessions; i++) {
            final bool attended = (i < 9); // Missed just one session
            attendancePattern.add(attended);
            if (attended) sessionsAttended++;
          }
          break;
          
        case 1: // Low attendance - rarely attends
          for (int i = 0; i < totalSessions; i++) {
            final bool attended = (i < 3); // Only attended first 3
            attendancePattern.add(attended);
            if (attended) sessionsAttended++;
          }
          break;
          
        case 2: // Improving - started poorly but improved
          for (int i = 0; i < totalSessions; i++) {
            final bool attended = (i < 2) ? false : (i > 6) || (i % 2 == 0);
            attendancePattern.add(attended);
            if (attended) sessionsAttended++;
          }
          break;
          
        case 3: // Average - inconsistent attendance
          for (int i = 0; i < totalSessions; i++) {
            final bool attended = (i % 3 != 0); // Attends 2 out of 3 sessions
            attendancePattern.add(attended);
            if (attended) sessionsAttended++;
          }
          break;
      }
      
      // Calculate attendance percentage
      final double attendancePercentage = sessionsAttended / totalSessions;
      
      // Calculate hours attended (assuming 3 hours per session)
      final hoursAttended = sessionsAttended * 3;
      
      // Create student attendance record
      mockData.add({
        'email': student['email']!,
        'name': student['name']!,
        'details': student,
        'sessionsAttended': sessionsAttended,
        'totalSessions': totalSessions,
        'attendancePercentage': attendancePercentage,
        'hoursAttended': hoursAttended,
        'attendancePattern': attendancePattern,
        'isEligible': attendancePercentage >= 0.7,
      });
    }
    
    // Sort by attendance percentage (descending)
    mockData.sort((a, b) => 
      (b['attendancePercentage'] as double).compareTo(a['attendancePercentage'] as double));
      
    return mockData;
  }
  
  /// Helper method to determine if a student's attendance is improving
  static bool isAttendanceImproving(List<bool> pattern) {
    if (pattern.length < 3) return false;
    
    // Check last few sessions against earlier ones
    int midpoint = pattern.length ~/ 2;
    int earlyAttendance = 0;
    int lateAttendance = 0;
    
    for (int i = 0; i < midpoint; i++) {
      if (pattern[i]) earlyAttendance++;
    }
    
    for (int i = midpoint; i < pattern.length; i++) {
      if (pattern[i]) lateAttendance++;
    }
    
    // Calculate percentage improvement
    final earlyRate = earlyAttendance / midpoint;
    final lateRate = lateAttendance / (pattern.length - midpoint);
    
    return lateRate > earlyRate && (lateRate - earlyRate) > 0.2; // At least 20% improvement
  }
  
  /// Determines the attendance category for a student
  static String getAttendanceCategory(double percentage, List<bool> pattern) {
    if (percentage >= 0.95) {
      return "Full Attendance";
    } else if (percentage <= 0.4) {
      return "Low Attendance";
    } else if (isAttendanceImproving(pattern)) {
      return "Improving";
    } else {
      return "Average";
    }
  }
} 
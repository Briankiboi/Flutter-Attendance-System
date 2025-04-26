import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'analysis.dart';
import 'dart:async';

// PrintAttendancePage for displaying and printing formatted attendance
class PrintAttendancePage extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  final List<Map<String, dynamic>>? relatedSessions;

  PrintAttendancePage({
    Key? key, 
    required this.sessionData, 
    this.relatedSessions
  }) : super(key: key);

  @override
  _PrintAttendancePageState createState() => _PrintAttendancePageState();
}

class _PrintAttendancePageState extends State<PrintAttendancePage> {
  final GlobalKey _printKey = GlobalKey();
  bool _isLoading = false;
  int _selectedSessionIndex = 0;
  bool _combinedPrintMode = false;

  @override
  Widget build(BuildContext context) {
    // Use either selected session or primary session data
    Map<String, dynamic> currentSession = widget.sessionData;
    List<Map<String, dynamic>> allSessions = [];
    
    // Ensure course information exists and is properly extracted
    if (currentSession.containsKey('attendees') && 
        currentSession['attendees'] is List && 
        currentSession['attendees'].isNotEmpty) {
      // Try to get department from the first attendee
      final firstAttendee = currentSession['attendees'][0];
      if (firstAttendee is Map) {
        if ((currentSession['department'] == null || currentSession['department'].isEmpty) && 
            firstAttendee.containsKey('department')) {
          currentSession['department'] = firstAttendee['department'];
        }
        if ((currentSession['course'] == null || currentSession['course'].isEmpty) && 
            firstAttendee.containsKey('course')) {
          currentSession['course'] = firstAttendee['course'];
        }
        if ((currentSession['year'] == null || currentSession['year'].toString().isEmpty) && 
            firstAttendee.containsKey('year')) {
          currentSession['year'] = firstAttendee['year'];
        }
        if ((currentSession['semester'] == null || currentSession['semester'].toString().isEmpty) && 
            firstAttendee.containsKey('semester')) {
          currentSession['semester'] = firstAttendee['semester'];
        }
      }
    }
    
    // If there are related sessions, use them for navigation
    if (widget.relatedSessions != null && widget.relatedSessions!.isNotEmpty) {
      allSessions = List.from(widget.relatedSessions!);
      
      // Sort sessions chronologically (oldest to newest) for printing
      allSessions.sort((a, b) {
        DateTime aDate = DateTime.now();
        DateTime bDate = DateTime.now();
        
        if (a.containsKey('date')) {
          try {
            aDate = DateTime.parse(a['date']);
          } catch (e) {}
        } else if (a.containsKey('timestamp')) {
          final timestamp = a['timestamp'];
          if (timestamp is int) {
            aDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String && int.tryParse(timestamp) != null) {
            aDate = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
          }
        }
        
        if (b.containsKey('date')) {
          try {
            bDate = DateTime.parse(b['date']);
          } catch (e) {}
        } else if (b.containsKey('timestamp')) {
          final timestamp = b['timestamp'];
          if (timestamp is int) {
            bDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String && int.tryParse(timestamp) != null) {
            bDate = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
          }
        }
        
        return aDate.compareTo(bDate);
      });
      
      // Find the index of the current session
      _selectedSessionIndex = allSessions.indexWhere((session) => 
        session['sessionId'] == currentSession['sessionId']);
      if (_selectedSessionIndex == -1) _selectedSessionIndex = 0;
    }
    
    // Debug print to check course information
    print("Course Info Debug: department=${currentSession['department']}, course=${currentSession['course']}, year=${currentSession['year']}, semester=${currentSession['semester']}");
    
    // Calculate week and day information for the current session
    if (currentSession.containsKey('date') && !currentSession.containsKey('weekInfo')) {
      try {
        final date = DateTime.parse(currentSession['date']);
        final weekOfMonth = _getWeekOfMonth(date);
        final monthName = DateFormat('MMMM').format(date);
        final dayOfWeek = DateFormat('EEEE').format(date);
        
        currentSession['weekInfo'] = 'Week $weekOfMonth of $monthName';
        currentSession['dayInfo'] = '$dayOfWeek, ${date.day}';
      } catch (e) {
        print('Error calculating week info: $e');
      }
    }
    
    final unitCode = currentSession['unitCode'] ?? 'Unknown Unit Code';
    final unitName = currentSession['unitName'] ?? 'Unknown Unit Name';
    final course = currentSession['course'] ?? '';
    final year = currentSession['year'] ?? '';
    final semester = currentSession['semester'] ?? '';
    final timeStr = currentSession.containsKey('startTime') && currentSession.containsKey('endTime')
      ? '${currentSession['startTime']} - ${currentSession['endTime']}'
      : '';
    
    // Format date from timestamp
    String dateStr = '';
    if (currentSession.containsKey('date')) {
      dateStr = currentSession['date'];
    } else if (currentSession.containsKey('timestamp')) {
      try {
        final timestamp = currentSession['timestamp'];
        DateTime date;
        if (timestamp is int) {
          date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp is String) {
          if (int.tryParse(timestamp) != null) {
            date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
          } else {
            date = DateTime.parse(timestamp);
          }
        } else {
          // If no valid timestamp, try to get date from sessionId
          final sessionId = currentSession['sessionId']?.toString();
          if (sessionId != null && int.tryParse(sessionId) != null) {
            date = DateTime.fromMillisecondsSinceEpoch(int.parse(sessionId));
          } else {
            date = DateTime.now();
          }
        }
        dateStr = DateFormat('yyyy-MM-dd').format(date);
      } catch (e) {
        dateStr = DateTime.now().toString().substring(0, 10);
      }
    } else {
      // If no date or timestamp, try to get date from sessionId
      final sessionId = currentSession['sessionId']?.toString();
      if (sessionId != null && int.tryParse(sessionId) != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(int.parse(sessionId));
        dateStr = DateFormat('yyyy-MM-dd').format(date);
      } else {
        dateStr = DateTime.now().toString().substring(0, 10);
      }
    }
    
    // Get attendee list and calculate present/absent counts
    final attendeeDetails = currentSession['attendeeDetails'] as List<dynamic>? ?? [];
    
    // Properly calculate present and absent counts from the actual attendee details
    int presentCount = 0;
    int absentCount = 0;
    
    for (var attendee in attendeeDetails) {
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
    
    final totalExpected = presentCount + absentCount;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Print Attendance'),
        backgroundColor: Colors.blue,
        actions: [
          // Add Analyze button
          IconButton(
            icon: Icon(Icons.analytics),
            tooltip: 'Analyze',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnalysisPage(
                    sessionData: currentSession,
                    relatedSessions: widget.relatedSessions,
                  ),
                ),
              );
            },
          ),
          // Add session navigation if there are multiple sessions
          if (allSessions.length > 1)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios),
                  onPressed: _selectedSessionIndex > 0
                    ? () {
                        setState(() {
                          _selectedSessionIndex--;
                        });
                      }
                    : null,
                  tooltip: 'Previous session',
                ),
                Text('${_selectedSessionIndex + 1}/${allSessions.length}'),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios),
                  onPressed: _selectedSessionIndex < allSessions.length - 1
                    ? () {
                        setState(() {
                          _selectedSessionIndex++;
                        });
                      }
                    : null,
                  tooltip: 'Next session',
                ),
              ],
            ),
          // Add combined print option if there are multiple sessions
          if (allSessions.length > 1)
            PopupMenuButton<String>(
              icon: Icon(Icons.print),
              tooltip: 'Print options',
              onSelected: (String value) {
                if (value == 'current') {
                  _printScreen();
                } else if (value == 'combined') {
                  _printMultipleSessions();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'current',
                  child: Row(
                    children: [
                      Icon(Icons.file_present, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Print current session'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'combined',
                  child: Row(
                    children: [
                      Icon(Icons.library_books, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Print all sessions'),
                    ],
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: Icon(Icons.print),
              onPressed: _isLoading ? null : () => _printScreen(),
              tooltip: 'Print Attendance',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: RepaintBoundary(
          key: _printKey,
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // University header with logo
                Center(
                  child: Image.asset(
                    'assets/images/university_logo.png',
                    width: double.infinity,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 20),
                
                // Attendance record header
                Center(
                  child: Text(
                    'ATTENDANCE RECORD',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Course and unit information - Make course info stand out more
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (currentSession['department'] != null) 
                            Text('Department: ${currentSession['department']}', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue.shade800
                              )),
                          if (currentSession['course'] != null) 
                            Text('Course: ${currentSession['course']}', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue.shade800
                              )),
                          // Always display year and semester
                          Text('Year: ${currentSession['year'] ?? "3"}, Semester: ${currentSession['semester'] ?? "2"}', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.blue.shade800
                            )),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 8),
                
                // Unit information
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Unit Code: $unitCode', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Unit Title: $unitName', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (currentSession.containsKey('weekInfo')) 
                            Text(currentSession['weekInfo'], style: TextStyle(fontWeight: FontWeight.bold)),
                          if (currentSession.containsKey('dayInfo')) 
                            Text(currentSession['dayInfo'], style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Date: $dateStr', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (timeStr.isNotEmpty) Text('Time: $timeStr'),
                          Text('Total Students: $totalExpected'),
                          Text('Present: $presentCount | Absent: $absentCount', 
                            style: TextStyle(
                              color: absentCount > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                
                // Attendance table
                Table(
                  border: TableBorder.all(),
                  columnWidths: {
                    0: FlexColumnWidth(0.5),  // No.
                    1: FlexColumnWidth(3),    // Name
                    2: FlexColumnWidth(3),    // Email
                    3: FlexColumnWidth(1.5),  // Time
                    4: FlexColumnWidth(1),    // Status
                  },
                  children: [
                    // Table header
                    TableRow(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                      ),
                      children: [
                        _tableCell('No.', isHeader: true),
                        _tableCell('Student Name', isHeader: true),
                        _tableCell('Email', isHeader: true),
                        _tableCell('Time Marked', isHeader: true),
                        _tableCell('Status', isHeader: true),
                      ],
                    ),
                    // Table data rows
                    ...List.generate(attendeeDetails.length, (index) {
                      final attendee = attendeeDetails[index];
                      final details = attendee['details'];
                      
                      // Extract email
                      final String email = attendee['email'] ?? '';
                      
                      // Extract student name with fallback to email username
                      String name;
                      if (details is Map) {
                        name = details['name'] ?? details['studentName'] ?? '';
                        
                        // Replace generic "Student" with better info
                        if (name == 'Student' || name.isEmpty || name == 'Unknown') {
                          // Use email username as fallback
                          name = email.contains('@') ? email.split('@').first : email;
                          
                          // Then try to look up real name from SharedPreferences
                          SharedPreferences.getInstance().then((prefs) {
                            final userData = prefs.getString(email);
                            if (userData != null) {
                              try {
                                final Map<String, dynamic> user = json.decode(userData);
                                if (user.containsKey('name') && user['name'] != null && 
                                    user['name'].toString().isNotEmpty && user['name'] != 'Student') {
                                  // This won't change current display but will update the data for next render
                                  details['name'] = user['name'];
                                  details['studentName'] = user['name'];
                                }
                              } catch (e) {
                                print('Error parsing user data for $email: $e');
                              }
                            }
                          });
                        }
                      } else {
                        name = email.contains('@') ? email.split('@').first : email;
                      }
                      
                      // Determine if student is absent
                      bool isAbsent = false;
                      if (details is Map) {
                        if (details.containsKey('status') && details['status'] == 'absent') {
                          isAbsent = true;
                        } else if (details.containsKey('timestamp') && details['timestamp'] == null) {
                          isAbsent = true;
                        }
                      }
                      
                      // Extract time
                      String timeMarked = '';
                      if (details is Map) {
                        if (isAbsent) {
                          timeMarked = 'null';
                        } else if (details.containsKey('timestamp')) {
                        try {
                          final timestamp = details['timestamp'];
                          DateTime dateTime;
                          if (timestamp is int) {
                            dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                          } else if (timestamp is String) {
                            dateTime = DateTime.parse(timestamp);
                          } else {
                            dateTime = DateTime.now();
                          }
                          timeMarked = '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                        } catch (e) {
                          timeMarked = 'Unknown';
                          }
                        }
                      }
                      
                      return TableRow(
                        decoration: BoxDecoration(
                          color: isAbsent 
                              ? Colors.red.withOpacity(0.1) 
                              : (index % 2 == 0 ? Colors.white : Colors.grey.shade50),
                        ),
                        children: [
                          _tableCell('${index + 1}'),
                          _tableCell(name, isAbsent: isAbsent),
                          _tableCell(email, isAbsent: isAbsent),
                          _tableCell(timeMarked, isAbsent: isAbsent),
                          _tableCell(isAbsent ? 'Absent' : 'Present', 
                            isAbsent: isAbsent, 
                            textAlign: TextAlign.center
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                
                SizedBox(height: 40),
                
                // Approved section with QR code
                Center(
                  child: Column(
                    children: [
                      Text('Approved', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Image.asset(
                        'assets/images/icon.png',
                        width: 100,
                        height: 100,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 40),
                
                Center(
                  child: Text(
                    'TUN is ISO 9001:2015 Certified.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method to create table cells
  Widget _tableCell(String text, {bool isHeader = false, bool isAbsent = false, TextAlign textAlign = TextAlign.left}) {
    return Container(
      padding: EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.center : textAlign,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isAbsent ? Colors.red : null,
          fontStyle: isAbsent ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  // Method to handle printing
  Future<void> _printScreen() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create PDF document directly rather than taking a screenshot
      final pdf = pw.Document();
      
      // Get current session data
      final session = widget.relatedSessions?[_selectedSessionIndex] ?? widget.sessionData;
      
      // Load logo image for PDF
      final ByteData? logoData = await rootBundle.load('assets/images/university_logo.png');
      final Uint8List? logoBytes = logoData?.buffer.asUint8List();
      final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
      
      // Load QR code image for PDF
      final ByteData? qrData = await rootBundle.load('assets/images/icon.png');
      final Uint8List? qrBytes = qrData?.buffer.asUint8List();
      final pw.MemoryImage? qrImage = qrBytes != null ? pw.MemoryImage(qrBytes) : null;
      
      // Format date and extract other session info
      String dateStr = '';
      if (session.containsKey('date')) {
        dateStr = session['date'];
      } else if (session.containsKey('timestamp')) {
        try {
          final timestamp = session['timestamp'];
          DateTime date;
          if (timestamp is int) {
            date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String) {
            if (int.tryParse(timestamp) != null) {
              date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
            } else {
              date = DateTime.parse(timestamp);
            }
          } else {
            date = DateTime.now();
          }
          dateStr = DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          dateStr = DateTime.now().toString().substring(0, 10);
        }
      }
      
      // Extract other session info
      final unitCode = session['unitCode'] ?? 'Unknown Unit Code';
      final unitName = session['unitName'] ?? 'Unknown Unit Name';
      
      // Print debug information to identify course data issues
      print('Debug Session Data: ${json.encode(session)}');
      
      // Try to get course information from session, then from attendees if needed
      String department = session['department'] ?? '';
      String course = session['course'] ?? '';
      String year = session['year']?.toString() ?? '';
      String semester = session['semester']?.toString() ?? '';
      
      // If department, course, year or semester is missing, try to get it from attendees
      if (department.isEmpty || course.isEmpty || year.isEmpty || semester.isEmpty) {
        if (session.containsKey('attendees') && session['attendees'] is List && session['attendees'].isNotEmpty) {
          final attendees = session['attendees'];
          for (var attendee in attendees) {
            if (attendee is Map) {
              if (department.isEmpty && attendee.containsKey('department')) {
                department = attendee['department'] ?? '';
              }
              if (course.isEmpty && attendee.containsKey('course')) {
                course = attendee['course'] ?? '';
              }
              if (year.isEmpty && attendee.containsKey('year')) {
                year = attendee['year']?.toString() ?? '';
              }
              if (semester.isEmpty && attendee.containsKey('semester')) {
                semester = attendee['semester']?.toString() ?? '';
              }
              
              // Break if we've found all the information we need
              if (department.isNotEmpty && course.isNotEmpty && 
                  year.isNotEmpty && semester.isNotEmpty) {
                break;
              }
            }
          }
        }
      }
      
      // If still missing, don't set defaults, leave as extracted
      print('Course Info Extracted: department=$department, course=$course, year=$year, semester=$semester');
      
      // Get time info
      final timeStr = session.containsKey('startTime') && session.containsKey('endTime')
        ? '${session['startTime']} - ${session['endTime']}'
        : '';
        
      // Get attendee list and calculate present/absent counts
      final attendeeDetails = session['attendeeDetails'] as List<dynamic>? ?? [];
      
      // Calculate present and absent counts
      int presentCount = 0;
      int absentCount = 0;
      
      for (var attendee in attendeeDetails) {
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
      
      final totalExpected = presentCount + absentCount;
      
      // Add page to PDF document
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            // Get the date string for this session
            String dateStr;
            if (session.containsKey('date')) {
              dateStr = session['date'];
            } else if (session.containsKey('timestamp')) {
              try {
                final timestamp = session['timestamp'];
                DateTime date;
                if (timestamp is int) {
                  date = DateTime.fromMillisecondsSinceEpoch(timestamp);
                } else if (timestamp is String) {
                  if (int.tryParse(timestamp) != null) {
                    date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
                  } else {
                    date = DateTime.parse(timestamp);
                  }
                } else {
                  final sessionId = session['sessionId']?.toString();
                  if (sessionId != null && int.tryParse(sessionId) != null) {
                    date = DateTime.fromMillisecondsSinceEpoch(int.parse(sessionId));
                  } else {
                    date = DateTime.now();
                  }
                }
                dateStr = DateFormat('yyyy-MM-dd').format(date);
              } catch (e) {
                dateStr = DateTime.now().toString().substring(0, 10);
              }
            } else {
              final sessionId = session['sessionId']?.toString();
              if (sessionId != null && int.tryParse(sessionId) != null) {
                final date = DateTime.fromMillisecondsSinceEpoch(int.parse(sessionId));
                dateStr = DateFormat('yyyy-MM-dd').format(date);
              } else {
                dateStr = DateTime.now().toString().substring(0, 10);
              }
            }

            // Extract course, year, and semester information
            final course = session['course'] ?? 'Unknown Course';
            final year = session['year'] ?? '';
            final semester = session['semester'] ?? '';
            final department = session['department'] ?? 'Unknown Department';
            final weekInfo = session['weekInfo'] ?? '';
            final dayInfo = session['dayInfo'] ?? '';

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // University header with logo at top
                pw.Center(
                  child: logoImage != null 
                    ? pw.Container(
                        height: 100,
                        width: double.infinity,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      )
                    : pw.Container(
                        height: 70,
                        child: pw.Text('UNIVERSITY LOGO', 
                          style: pw.TextStyle(
                            fontSize: 24, 
                            fontWeight: pw.FontWeight.bold
                          )
                        ),
                      ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Attendance record header
                pw.Center(
                  child: pw.Text(
                    'ATTENDANCE RECORD',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                
                // Academic information section - displayed prominently
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  margin: pw.EdgeInsets.only(bottom: 16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.blue800, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (department.isNotEmpty)
                        pw.Text('Department: $department', 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      if (course.isNotEmpty)
                        pw.Text('Course: $course', 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('Year: ${year.isNotEmpty ? year : "3"}, Semester: ${semester.isNotEmpty ? semester : "2"}', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue800)),
                    ],
                  ),
                ),
                
                // Unit header information
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Unit Code: $unitCode', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Unit Title: $unitName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          // Remove duplicated department & course info
                          if (session.containsKey('weekInfo')) 
                            pw.Text(session['weekInfo'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          if (session.containsKey('dayInfo')) 
                            pw.Text(session['dayInfo'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Date: $dateStr', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          if (timeStr.isNotEmpty) pw.Text('Time: $timeStr'),
                          pw.Text('Total Students: $totalExpected'),
                          pw.Text('Present: $presentCount | Absent: $absentCount'),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                
                // Attendance table
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: pw.FlexColumnWidth(0.5),  // No.
                    1: pw.FlexColumnWidth(3),    // Name
                    2: pw.FlexColumnWidth(3),    // Email
                    3: pw.FlexColumnWidth(1.5),  // Time
                    4: pw.FlexColumnWidth(1),    // Status
                  },
                  children: [
                    // Table header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        _pdfTableCell('No.', isHeader: true),
                        _pdfTableCell('Student Name', isHeader: true),
                        _pdfTableCell('Email', isHeader: true),
                        _pdfTableCell('Time Marked', isHeader: true),
                        _pdfTableCell('Status', isHeader: true),
                      ],
                    ),
                    // Table data rows
                    ...List.generate(attendeeDetails.length, (index) {
                      final attendee = attendeeDetails[index];
                      final details = attendee['details'];
                      
                      // Extract email
                      final String email = attendee['email'] ?? '';
                      
                      // Extract student name with fallback to email username
                      String name;
                      if (details is Map) {
                        name = details['name'] ?? details['studentName'] ?? '';
                        
                        // Replace generic "Student" with better info
                        if (name == 'Student' || name.isEmpty || name == 'Unknown') {
                          // Use email username as fallback
                          name = email.contains('@') ? email.split('@').first : email;
                          
                          // Then try to look up real name from SharedPreferences
                          SharedPreferences.getInstance().then((prefs) {
                            final userData = prefs.getString(email);
                            if (userData != null) {
                              try {
                                final Map<String, dynamic> user = json.decode(userData);
                                if (user.containsKey('name') && user['name'] != null && 
                                    user['name'].toString().isNotEmpty && user['name'] != 'Student') {
                                  // This won't change current display but will update the data for next render
                                  details['name'] = user['name'];
                                  details['studentName'] = user['name'];
                                }
                              } catch (e) {
                                print('Error parsing user data for $email: $e');
                              }
                            }
                          });
                        }
                      } else {
                        name = email.contains('@') ? email.split('@').first : email;
                      }
                      
                      // Determine if student is absent
                      bool isAbsent = false;
                      if (details is Map) {
                        if (details.containsKey('status') && details['status'] == 'absent') {
                          isAbsent = true;
                        } else if (details.containsKey('timestamp') && details['timestamp'] == null) {
                          isAbsent = true;
                        }
                      }
                      
                      // Extract time
                      String timeMarked = '';
                      if (details is Map) {
                        if (isAbsent) {
                          timeMarked = 'null';
                        } else if (details.containsKey('timestamp')) {
                          try {
                            final timestamp = details['timestamp'];
                            DateTime dateTime;
                            if (timestamp is int) {
                              dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                            } else if (timestamp is String) {
                              dateTime = DateTime.parse(timestamp);
                            } else {
                              dateTime = DateTime.now();
                            }
                            timeMarked = '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                          } catch (e) {
                            timeMarked = 'Unknown';
                          }
                        }
                      }
                      
                      final isEvenRow = index % 2 == 0;
                      final rowColor = isAbsent 
                          ? PdfColors.red50
                          : (isEvenRow ? PdfColors.white : PdfColors.grey50);
                          
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: rowColor,
                        ),
                        children: [
                          _pdfTableCell('${index + 1}'),
                          _pdfTableCell(name, isAbsent: isAbsent),
                          _pdfTableCell(email, isAbsent: isAbsent),
                          _pdfTableCell(timeMarked, isAbsent: isAbsent),
                          _pdfTableCell(isAbsent ? 'Absent' : 'Present', 
                            isAbsent: isAbsent, 
                            textAlign: pw.TextAlign.center
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                
                pw.Spacer(), // Push the footer to the bottom of the page
                
                // Approval section at bottom
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Approved', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      qrImage != null
                        ? pw.Container(
                            width: 100,
                            height: 100,
                            child: pw.Image(qrImage),
                          )
                        : pw.Container(
                            width: 100,
                            height: 100,
                            child: pw.Center(
                              child: pw.Text('QR CODE'),
                            ),
                          ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                pw.Center(
                  child: pw.Text(
                    'TUN is ISO 9001:2015 Certified.',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      print('Error printing: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // New method to print multiple sessions at once
  Future<void> _printMultipleSessions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pdf = pw.Document();
      
      // Get all related sessions or just the current one if no related sessions
      List<Map<String, dynamic>> sessionsToPrint = widget.relatedSessions ?? [widget.sessionData];
      
      // Sort sessions chronologically (oldest to newest)
      sessionsToPrint.sort((a, b) {
        DateTime aDate = DateTime.now();
        DateTime bDate = DateTime.now();
        
        if (a.containsKey('date')) {
          try {
            aDate = DateTime.parse(a['date']);
          } catch (e) {}
        } else if (a.containsKey('timestamp')) {
          final timestamp = a['timestamp'];
          if (timestamp is int) {
            aDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String && int.tryParse(timestamp) != null) {
            aDate = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
          }
        }
        
        if (b.containsKey('date')) {
          try {
            bDate = DateTime.parse(b['date']);
          } catch (e) {}
        } else if (b.containsKey('timestamp')) {
          final timestamp = b['timestamp'];
          if (timestamp is int) {
            bDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String && int.tryParse(timestamp) != null) {
            bDate = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
          }
        }
        
        return aDate.compareTo(bDate);
      });

      // Get sample session for header info (unit code, name, etc.)
      final sampleSession = sessionsToPrint.first;
      final unitCode = sampleSession['unitCode'] ?? 'Unknown Unit Code';
      final unitName = sampleSession['unitName'] ?? 'Unknown Unit Name';
      final course = sampleSession['course'] ?? '';
      final year = sampleSession['year'] ?? '';
      final semester = sampleSession['semester'] ?? '';
      
      // Load logo image for PDF
      final ByteData? logoData = await rootBundle.load('assets/images/university_logo.png');
      final Uint8List? logoBytes = logoData?.buffer.asUint8List();
      final pw.MemoryImage? logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
      
      // Load QR code image for PDF
      final ByteData? qrData = await rootBundle.load('assets/images/icon.png');
      final Uint8List? qrBytes = qrData?.buffer.asUint8List();
      final pw.MemoryImage? qrImage = qrBytes != null ? pw.MemoryImage(qrBytes) : null;
      
      // Add pages to the PDF document
      for (int i = 0; i < sessionsToPrint.length; i++) {
        final isLastPage = i == sessionsToPrint.length - 1;
        final session = sessionsToPrint[i];
        
        // Calculate week and day information for the current session
        if (session.containsKey('date') && !session.containsKey('weekInfo')) {
          try {
            final date = DateTime.parse(session['date']);
            final weekOfMonth = _getWeekOfMonth(date);
            final monthName = DateFormat('MMMM').format(date);
            final dayOfWeek = DateFormat('EEEE').format(date);
            
            session['weekInfo'] = 'Week $weekOfMonth of $monthName';
            session['dayInfo'] = '$dayOfWeek, ${date.day}';
          } catch (e) {
            print('Error calculating week info: $e');
          }
        }
        
        // Format date from timestamp
        String dateStr = '';
        if (session.containsKey('date')) {
          dateStr = session['date'];
        } else if (session.containsKey('timestamp')) {
          try {
            final timestamp = session['timestamp'];
            DateTime date;
            if (timestamp is int) {
              date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            } else if (timestamp is String) {
              if (int.tryParse(timestamp) != null) {
                date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
              } else {
                date = DateTime.parse(timestamp);
              }
            } else {
              date = DateTime.now();
            }
            dateStr = DateFormat('yyyy-MM-dd').format(date);
          } catch (e) {
            dateStr = DateTime.now().toString().substring(0, 10);
          }
        } else {
          dateStr = DateTime.now().toString().substring(0, 10);
        }
        
        // Extract time information
        final timeStr = session.containsKey('startTime') && session.containsKey('endTime')
          ? '${session['startTime']} - ${session['endTime']}'
          : '';
          
        // Get attendee list and calculate present/absent counts
        final attendeeDetails = session['attendeeDetails'] as List<dynamic>? ?? [];
        
        // Calculate present and absent counts
        int presentCount = 0;
        int absentCount = 0;
        
        for (var attendee in attendeeDetails) {
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
        
        final totalExpected = presentCount + absentCount;
        
        // Create a page for the current session
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              // Get the date string for this session
              String dateStr;
              if (session.containsKey('date')) {
                dateStr = session['date'];
              } else if (session.containsKey('timestamp')) {
                try {
                  final timestamp = session['timestamp'];
                  DateTime date;
                  if (timestamp is int) {
                    date = DateTime.fromMillisecondsSinceEpoch(timestamp);
                  } else if (timestamp is String) {
                    if (int.tryParse(timestamp) != null) {
                      date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
                    } else {
                      date = DateTime.parse(timestamp);
                    }
                  } else {
                    final sessionId = session['sessionId']?.toString();
                    if (sessionId != null && int.tryParse(sessionId) != null) {
                      date = DateTime.fromMillisecondsSinceEpoch(int.parse(sessionId));
                    } else {
                      date = DateTime.now();
                    }
                  }
                  dateStr = DateFormat('yyyy-MM-dd').format(date);
                } catch (e) {
                  dateStr = DateTime.now().toString().substring(0, 10);
                }
              } else {
                final sessionId = session['sessionId']?.toString();
                if (sessionId != null && int.tryParse(sessionId) != null) {
                  final date = DateTime.fromMillisecondsSinceEpoch(int.parse(sessionId));
                  dateStr = DateFormat('yyyy-MM-dd').format(date);
                } else {
                  dateStr = DateTime.now().toString().substring(0, 10);
                }
              }

              // Extract course, year, and semester information
              String course = session['course'] ?? '';
              String year = session['year']?.toString() ?? '';
              String semester = session['semester']?.toString() ?? '';
              String department = session['department'] ?? '';
              
              // If department, course, year or semester is missing, try to get it from attendees
              if (department.isEmpty || course.isEmpty || year.isEmpty || semester.isEmpty) {
                if (session.containsKey('attendees') && session['attendees'] is List && session['attendees'].isNotEmpty) {
                  final attendees = session['attendees'];
                  for (var attendee in attendees) {
                    if (attendee is Map) {
                      if (department.isEmpty && attendee.containsKey('department')) {
                        department = attendee['department'] ?? '';
                      }
                      if (course.isEmpty && attendee.containsKey('course')) {
                        course = attendee['course'] ?? '';
                      }
                      if (year.isEmpty && attendee.containsKey('year')) {
                        year = attendee['year']?.toString() ?? '';
                      }
                      if (semester.isEmpty && attendee.containsKey('semester')) {
                        semester = attendee['semester']?.toString() ?? '';
                      }
                      
                      // Break if we've found all the information we need
                      if (department.isNotEmpty && course.isNotEmpty && 
                          year.isNotEmpty && semester.isNotEmpty) {
                        break;
                      }
                    }
                  }
                }
              }
              
              // Don't set defaults, leave as extracted
              final weekInfo = session['weekInfo'] ?? '';
              final dayInfo = session['dayInfo'] ?? '';
              
              // Print debug info
              print('Multiple Session Debug: department=$department, course=$course, year=$year, semester=$semester');

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // University header with logo - at the top of every page
                  pw.Center(
                    child: logoImage != null 
                      ? pw.Container(
                          height: 100,
                          width: double.infinity,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        )
                      : pw.Container(
                          height: 70,
                          child: pw.Text('UNIVERSITY LOGO', 
                            style: pw.TextStyle(
                              fontSize: 24, 
                              fontWeight: pw.FontWeight.bold
                            )
                          ),
                        ),
                  ),
                  
                  pw.SizedBox(height: 20),
                  
                  // Attendance record header
                  pw.Center(
                    child: pw.Text(
                      'ATTENDANCE RECORD',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  
                  // Academic information section - displayed prominently
                  pw.Container(
                    padding: pw.EdgeInsets.all(10),
                    margin: pw.EdgeInsets.only(bottom: 16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.blue800, width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (department.isNotEmpty)
                          pw.Text('Department: $department', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        if (course.isNotEmpty)
                          pw.Text('Course: $course', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Text('Year: ${year.isNotEmpty ? year : "3"}, Semester: ${semester.isNotEmpty ? semester : "2"}', 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue800)),
                      ],
                    ),
                  ),
                  
                  // Unit header information
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Unit Code: $unitCode', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text('Unit Title: $unitName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            // Remove duplicated department & course info
                            if (session.containsKey('weekInfo')) 
                              pw.Text(session['weekInfo'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            if (session.containsKey('dayInfo')) 
                              pw.Text(session['dayInfo'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Date: $dateStr', 
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            if (timeStr.isNotEmpty) pw.Text('Time: $timeStr'),
                            pw.Text('Total Students: $totalExpected'),
                            pw.Text('Present: $presentCount | Absent: $absentCount'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),
                  
                  // Attendance table
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: pw.FlexColumnWidth(0.5),  // No.
                      1: pw.FlexColumnWidth(3),    // Name
                      2: pw.FlexColumnWidth(3),    // Email
                      3: pw.FlexColumnWidth(1.5),  // Time
                      4: pw.FlexColumnWidth(1),    // Status
                    },
                    children: [
                      // Table header
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                        ),
                        children: [
                          _pdfTableCell('No.', isHeader: true),
                          _pdfTableCell('Student Name', isHeader: true),
                          _pdfTableCell('Email', isHeader: true),
                          _pdfTableCell('Time Marked', isHeader: true),
                          _pdfTableCell('Status', isHeader: true),
                        ],
                      ),
                      // Table data rows
                      ...List.generate(attendeeDetails.length, (index) {
                        final attendee = attendeeDetails[index];
                        final details = attendee['details'];
                        
                        // Extract email
                        final String email = attendee['email'] ?? '';
                        
                        // Extract student name with fallback to email username
                        String name;
                        if (details is Map) {
                          name = details['name'] ?? details['studentName'] ?? '';
                          
                          // Replace generic "Student" with better info
                          if (name == 'Student' || name.isEmpty || name == 'Unknown') {
                            // Use email username as fallback
                            name = email.contains('@') ? email.split('@').first : email;
                            
                            // Then try to look up real name from SharedPreferences
                            SharedPreferences.getInstance().then((prefs) {
                              final userData = prefs.getString(email);
                              if (userData != null) {
                                try {
                                  final Map<String, dynamic> user = json.decode(userData);
                                  if (user.containsKey('name') && user['name'] != null && 
                                      user['name'].toString().isNotEmpty && user['name'] != 'Student') {
                                    // This won't change current display but will update the data for next render
                                    details['name'] = user['name'];
                                    details['studentName'] = user['name'];
                                  }
                                } catch (e) {
                                  print('Error parsing user data for $email: $e');
                                }
                              }
                            });
                          }
                        } else {
                          name = email.contains('@') ? email.split('@').first : email;
                        }
                        
                        // Determine if student is absent
                        bool isAbsent = false;
                        if (details is Map) {
                          if (details.containsKey('status') && details['status'] == 'absent') {
                            isAbsent = true;
                          } else if (details.containsKey('timestamp') && details['timestamp'] == null) {
                            isAbsent = true;
                          }
                        }
                        
                        // Extract time
                        String timeMarked = '';
                        if (details is Map) {
                          if (isAbsent) {
                            timeMarked = 'null';
                          } else if (details.containsKey('timestamp')) {
                            try {
                              final timestamp = details['timestamp'];
                              DateTime dateTime;
                              if (timestamp is int) {
                                dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                              } else if (timestamp is String) {
                                dateTime = DateTime.parse(timestamp);
                              } else {
                                dateTime = DateTime.now();
                              }
                              timeMarked = '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                            } catch (e) {
                              timeMarked = 'Unknown';
                            }
                          }
                        }
                        
                        final isEvenRow = index % 2 == 0;
                        final rowColor = isAbsent 
                            ? PdfColors.red50
                            : (isEvenRow ? PdfColors.white : PdfColors.grey50);
                            
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: rowColor,
                          ),
                          children: [
                            _pdfTableCell('${index + 1}'),
                            _pdfTableCell(name, isAbsent: isAbsent),
                            _pdfTableCell(email, isAbsent: isAbsent),
                            _pdfTableCell(timeMarked, isAbsent: isAbsent),
                            _pdfTableCell(isAbsent ? 'Absent' : 'Present', 
                              isAbsent: isAbsent, 
                              textAlign: pw.TextAlign.center
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  
                  // Add spacer to push approval section to the bottom
                  pw.Spacer(),
                  
                  // Only show approval and certification on the last page
                  if (isLastPage) ...[
                    // Approval section with QR code
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text('Approved', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          qrImage != null
                            ? pw.Container(
                                width: 100,
                                height: 100,
                                child: pw.Image(qrImage),
                              )
                            : pw.Container(
                                width: 100,
                                height: 100,
                                child: pw.Center(
                                  child: pw.Text('QR CODE'),
                                ),
                              ),
                        ],
                      ),
                    ),
                    
                    pw.SizedBox(height: 20),
                    
                    // Certification note
                    pw.Center(
                      child: pw.Text(
                        'TUN is ISO 9001:2015 Certified.',
                        style: pw.TextStyle(
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      print('Error printing multiple sessions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to create PDF table cells
  pw.Widget _pdfTableCell(String text, {bool isHeader = false, bool isAbsent = false, pw.TextAlign textAlign = pw.TextAlign.left}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: isHeader ? pw.TextAlign.center : textAlign,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
          color: isAbsent ? PdfColors.red : null,
          fontStyle: isAbsent ? pw.FontStyle.italic : null,
        ),
      ),
    );
  }

  int _getWeekOfMonth(DateTime date) {
    // Clone the date to avoid modifying the original
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    
    // Calculate days from start of month, accounting for the day of week
    final int dayOffset = date.day + firstDayOfMonth.weekday - 1;
    
    // Integer division to get the week number (1-based)
    return ((dayOffset - 1) ~/ 7) + 1;
  }
}

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  DateTime? _selectedDate;
  bool _filterWeek = false;
  int _selectedWeek = 0; // 0=none, 1-4 = week of month
  int _selectedMonth = 0; // 0=current, -1/-2=previous, 1/2=next
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Set initial values
    _isLoading = true;
    _sessions = [];
    _selectedDate = null;
    _selectedWeek = 0;
    _selectedMonth = 0;
    
    // Load attendance history
    _loadAttendanceHistory();
    
    // Force refresh attendance data every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshAttendanceData();
      }
    });
  }

  // Method to refresh attendance data without showing loading indicator
  Future<void> _refreshAttendanceData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Directly scan SharedPreferences for session data
      Set<String> sessionKeys = {};
      
      for (String key in prefs.getKeys()) {
        if (key.startsWith('session_') && 
            !key.contains('_students') && 
            !key.contains('_data') && 
            !key.contains('_metadata')) {
          sessionKeys.add(key);
        }
      }
      
      if (sessionKeys.isEmpty) {
        print('No session data found in SharedPreferences');
        return;
      }
      
      // Create a map to track unique sessions and their attendee counts
      Map<String, Map<String, dynamic>> sessionMap = {};
      
      // Process all session records
      for (String sessionKey in sessionKeys) {
        final String? sessionDataStr = prefs.getString(sessionKey);
        
        if (sessionDataStr == null) {
          continue;
        }
        
        try {
          // Parse session data
          final Map<String, dynamic> sessionData = json.decode(sessionDataStr);
          final String sessionId = sessionData['sessionId']?.toString() ?? sessionKey.replaceAll('session_', '');
          
          // Skip sessions without required information
          if (!sessionData.containsKey('unitCode') || !sessionData.containsKey('unitName')) {
            continue;
          }
          
          // Get attendees list (students who actually scanned the QR code)
          final List<dynamic> attendees = sessionData['attendees'] ?? [];
          
          // Get the list of students who were sent the QR code (eligible students)
          List<String> eligibleStudents = prefs.getStringList('session_${sessionId}_students') ?? [];
          
          // Create or update session map entry
          if (!sessionMap.containsKey(sessionId)) {
            // Create new entry
            final entry = Map<String, dynamic>.from(sessionData);
            
            // Process attendees to make them available for display
            int presentCount = attendees.length;
            int absentCount = 0;
            
            // Transform attendees into a format the UI can use
            List<Map<String, dynamic>> processedAttendees = [];
            
            // Process present students (those who scanned the QR code)
            Set<String> presentStudentEmails = {};
          for (var attendee in attendees) {
              if (attendee is Map) {
                final studentEmail = attendee['studentEmail'] ?? '';
                presentStudentEmails.add(studentEmail);
                
                processedAttendees.add({
                  'email': studentEmail,
                  'details': {
                    'name': attendee['studentName'] ?? 'Student',
                    'studentName': attendee['studentName'] ?? 'Student',
                    'timestamp': attendee['timestamp'],
                    'status': 'present'
                  }
                });
              }
            }
            
            // Process absent students (those who received the QR but didn't scan)
            for (String studentEmail in eligibleStudents) {
              if (!presentStudentEmails.contains(studentEmail)) {
                // This student was sent the QR code but didn't scan it
                absentCount++;
                
                // Get student info if available
                String studentName = 'Student';
                try {
                  String? studentData = prefs.getString(studentEmail);
                  if (studentData != null) {
                    Map<String, dynamic> studentInfo = json.decode(studentData);
                    studentName = studentInfo['name'] ?? studentEmail.split('@')[0];
                  } else {
                    studentName = studentEmail.split('@')[0];
                  }
                  } catch (e) {
                  print('Error getting student info: $e');
                  studentName = studentEmail.split('@')[0];
                }
                
                processedAttendees.add({
                  'email': studentEmail,
                  'details': {
                    'name': studentName,
                    'studentName': studentName,
                    'timestamp': null,
                    'status': 'absent'
                  }
                });
              }
            }
            
            // Add processed attendees to entry
            entry['attendeeDetails'] = processedAttendees;
            
            // Add attendance counts to entry
            entry['presentCount'] = presentCount;
            entry['absentCount'] = absentCount;
            entry['attendeeCount'] = presentCount;
            entry['eligibleCount'] = eligibleStudents.length;
            
            // Add timestamp if missing
            if (!entry.containsKey('timestamp')) {
              // Try to parse timestamp from sessionId
              final int? timestamp = int.tryParse(sessionId);
              if (timestamp != null) {
                entry['timestamp'] = timestamp;
              } else {
                // Use current time as fallback
                entry['timestamp'] = DateTime.now().millisecondsSinceEpoch;
              }
            }
            
            // Format date for grouping
            if (!entry.containsKey('date') || entry['date'] == null) {
              final timestamp = entry['timestamp'];
              if (timestamp != null) {
                final dateTime = DateTime.fromMillisecondsSinceEpoch(
                  timestamp is int ? timestamp : int.tryParse(timestamp.toString()) ?? DateTime.now().millisecondsSinceEpoch
                );
                entry['date'] = dateTime.toString().substring(0, 10);
              } else {
                entry['date'] = DateTime.now().toString().substring(0, 10);
              }
            }
            
            sessionMap[sessionId] = entry;
                }
              } catch (e) {
          print('Error processing session data: $e');
        }
      }
      
      // Convert session map to list and sort by date (newest first)
      final List<Map<String, dynamic>> sessions = sessionMap.values.toList();
      sessions.sort((a, b) {
        final aTimestamp = a['timestamp'] is int ? a['timestamp'] : int.tryParse(a['timestamp'].toString()) ?? 0;
        final bTimestamp = b['timestamp'] is int ? b['timestamp'] : int.tryParse(b['timestamp'].toString()) ?? 0;
        return bTimestamp.compareTo(aTimestamp);
      });

      if (mounted) {
      setState(() {
        _sessions = sessions;
      });
      }
      
      print('Refreshed ${sessions.length} unique sessions with attendance records');
      
    } catch (e) {
      print('Error refreshing attendance data: $e');
    }
  }

  // Clear all attendance logs
  Future<void> _clearAttendanceLogs() async {
    try {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Clear Attendance Logs'),
            content: Text('Are you sure you want to clear all attendance logs? This cannot be undone.'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Clear', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.of(context).pop();
                  setState(() {
                    _sessions = [];
                    _isLoading = false;
                    _selectedDate = null;
                    _selectedWeek = 0;
                    _selectedMonth = 0;
                  });
                  
                  final prefs = await SharedPreferences.getInstance();
                  
                  // Get all keys in SharedPreferences
                  final keys = prefs.getKeys();
                  
                  // Remove all attendance-related records
                  for (String key in keys) {
                    if (key.startsWith('session_') || 
                        key.startsWith('lecture_history_') ||
                        key.startsWith('class_attendance_') ||
                        key == 'lecturer_attendance_history' ||
                        key == 'attendance_data_consolidated' ||
                        key == 'detailed_attendance_history') {
                      await prefs.remove(key);
                    }
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('All attendance logs cleared'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error clearing attendance logs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  // Get week of month (1-4)
  int _getWeekOfMonth(DateTime date) {
    // Clone the date to avoid modifying the original
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    
    // Calculate days from start of month, accounting for the day of week
    final int dayOffset = date.day + firstDayOfMonth.weekday - 1;
    
    // Integer division to get the week number (1-based)
    return ((dayOffset - 1) ~/ 7) + 1;
  }

  // Get start and end date for a specific week of a month
  DateTimeRange _getWeekDateRange() {
    // Base month: current, previous, or next
    DateTime now = DateTime.now();
    DateTime baseMonth;
    
    switch (_selectedMonth) {
      case -2: // 2 months ago
        baseMonth = DateTime(now.year, now.month - 2, 1);
        break;
      case -1: // Previous month
        baseMonth = DateTime(now.year, now.month - 1, 1);
        break;
      case 1: // Next month
        baseMonth = DateTime(now.year, now.month + 1, 1);
        break;
      case 2: // 2 months ahead
        baseMonth = DateTime(now.year, now.month + 2, 1);
        break;
      default: // Current month
        baseMonth = DateTime(now.year, now.month, 1);
    }
    
    // First day of the month
    final firstDay = DateTime(baseMonth.year, baseMonth.month, 1);
    
    // Day of week for the first day (0=Monday in our calculation)
    final firstDayWeekday = firstDay.weekday;
    
    // Calculate the first day of the selected week
    int daysToAdd = (_selectedWeek - 1) * 7;
    if (firstDayWeekday > 1) {
      // Adjust to start on the first full week
      daysToAdd += (8 - firstDayWeekday);
    }
    
    final startDate = DateTime(baseMonth.year, baseMonth.month, 1 + daysToAdd);
    final endDate = DateTime(baseMonth.year, baseMonth.month, 1 + daysToAdd + 6);
    
    return DateTimeRange(start: startDate, end: endDate);
  }

  // Helper to get month name
  String _getMonthName(int monthOffset) {
    final DateTime now = DateTime.now();
    final DateTime targetMonth = DateTime(now.year, now.month + monthOffset, 1);
    return DateFormat('MMMM').format(targetMonth);
  }

  // Filter sessions by selected date or week
  List<Map<String, dynamic>> _getFilteredSessions() {
    if (_selectedDate == null && _selectedWeek == 0) {
      return _groupAndSortSessions(_sessions);
    }
    
    final filtered = _sessions.where((session) {
      // Extract date from session
      DateTime? sessionDate;
      
      if (session.containsKey('date')) {
        try {
          sessionDate = DateTime.parse(session['date']);
        } catch (e) {
          // If parse fails, try to extract date parts
          final parts = session['date'].toString().split('-');
          if (parts.length == 3) {
            try {
              sessionDate = DateTime(
                int.parse(parts[0]), 
                int.parse(parts[1]), 
                int.parse(parts[2])
              );
            } catch (e) {
              print('Error parsing date parts: $e');
            }
          }
        }
      } else if (session.containsKey('timestamp')) {
        final timestamp = session['timestamp'];
        if (timestamp is int) {
          sessionDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp is String) {
          if (int.tryParse(timestamp) != null) {
            sessionDate = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
          } else {
            try {
              sessionDate = DateTime.parse(timestamp);
            } catch (e) {
              print('Error parsing timestamp: $e');
            }
          }
        }
      }

      if (sessionDate == null) {
        return false;
      }
      
      if (_selectedWeek > 0) {
        // Filter by selected week of month
        final DateTimeRange weekRange = _getWeekDateRange();
        
        // Check if session date is within the selected week
        return sessionDate.isAfter(weekRange.start.subtract(Duration(days: 1))) && 
               sessionDate.isBefore(weekRange.end.add(Duration(days: 1)));
      } else {
        // Check if session date matches selected date
        return sessionDate.year == _selectedDate!.year && 
               sessionDate.month == _selectedDate!.month && 
               sessionDate.day == _selectedDate!.day;
      }
    }).toList();
    
    return _groupAndSortSessions(filtered);
  }

  // Group sessions by date (day) and sort
  List<Map<String, dynamic>> _groupAndSortSessions(List<Map<String, dynamic>> sessions) {
    // Create a map to group sessions by date
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    
    // Track unique sessions to prevent repetition - using simpler key without sessionId
    Map<String, Map<String, dynamic>> uniqueSessionMap = {};
    
    for (var session in sessions) {
      // Get date from session
      String dateKey = "Unknown";
      
      if (session.containsKey('date')) {
        dateKey = session['date'].toString();
      } else if (session.containsKey('timestamp')) {
        try {
          final timestamp = session['timestamp'];
          DateTime date;
          if (timestamp is int) {
            date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String) {
            if (int.tryParse(timestamp) != null) {
              date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
            } else {
              date = DateTime.parse(timestamp);
            }
          } else {
            date = DateTime.now();
          }
          dateKey = DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          print('Error formatting date: $e');
          dateKey = "Unknown";
        }
      }
      
      // Add week and day information to each session
      if (session.containsKey('date')) {
        try {
          final date = DateTime.parse(session['date']);
          final weekOfMonth = _getWeekOfMonth(date);
          final monthName = DateFormat('MMMM').format(date);
          final dayOfWeek = DateFormat('EEEE').format(date);
          
          session['weekInfo'] = 'Week $weekOfMonth of $monthName';
          session['dayInfo'] = '$dayOfWeek, ${date.day}';
        } catch (e) {
          print('Error calculating week info: $e');
        }
      }
      
      // Create unique identifier that doesn't include sessionId
      String unitCode = session['unitCode'] ?? 'Unknown';
      String timeIdentifier = '';
      if (session.containsKey('startTime') && session.containsKey('endTime')) {
        timeIdentifier = '${session['startTime']}-${session['endTime']}';
      }
      
      // Create a unique key that combines date + unit + time (without sessionId)
      String uniqueSessionKey = '$dateKey::$unitCode::$timeIdentifier';
      
      // Check if we've seen this session before
      if (uniqueSessionMap.containsKey(uniqueSessionKey)) {
        // This is a duplicate session - merge attendee data if needed
        Map<String, dynamic> existingSession = uniqueSessionMap[uniqueSessionKey]!;
        
        // Merge attendee details if both sessions have them
        if (session.containsKey('attendeeDetails') && existingSession.containsKey('attendeeDetails')) {
          List<dynamic> newAttendeeDetails = session['attendeeDetails'];
          List<dynamic> existingAttendeeDetails = existingSession['attendeeDetails'];
          
          // Create a map of existing attendees by email to avoid duplicates
          Map<String, dynamic> attendeeByEmail = {};
          for (var attendee in existingAttendeeDetails) {
            final email = attendee['email'];
            if (email != null && email.isNotEmpty) {
              attendeeByEmail[email] = attendee;
            }
          }
          
          // Add any new attendees not already in the existing session
          for (var attendee in newAttendeeDetails) {
            final email = attendee['email'];
            if (email != null && email.isNotEmpty && !attendeeByEmail.containsKey(email)) {
              existingAttendeeDetails.add(attendee);
              attendeeByEmail[email] = attendee;
            }
          }
          
          // Update existing session with merged attendee details
          existingSession['attendeeDetails'] = existingAttendeeDetails;
        }
      } else {
        // This is a new unique session
        uniqueSessionMap[uniqueSessionKey] = session;
        
        // Add session to date group
        if (!groupedByDate.containsKey(dateKey)) {
          groupedByDate[dateKey] = [];
        }
        groupedByDate[dateKey]!.add(session);
      }
    }
    
    // Sort dates in reverse chronological order (newest first)
    List<String> sortedDates = groupedByDate.keys.toList();
    sortedDates.sort((a, b) {
      try {
        DateTime dateA = DateTime.parse(a);
        DateTime dateB = DateTime.parse(b);
        return dateB.compareTo(dateA); // Reverse order (newest first)
        } catch (e) {
        return a.compareTo(b); // Fallback to string comparison
      }
    });
    
    // Now update grouped dates based on our uniqueSessionMap
    for (var dateKey in groupedByDate.keys) {
      // Filter the sessions for this date to only include unique ones
      List<Map<String, dynamic>> uniqueSessions = [];
      for (var session in groupedByDate[dateKey]!) {
        String unitCode = session['unitCode'] ?? 'Unknown';
        String timeIdentifier = '';
        if (session.containsKey('startTime') && session.containsKey('endTime')) {
          timeIdentifier = '${session['startTime']}-${session['endTime']}';
        }
        String uniqueSessionKey = '$dateKey::$unitCode::$timeIdentifier';
        
        // Only add this session if it matches our unique map for this key
        if (uniqueSessionMap[uniqueSessionKey] == session) {
          uniqueSessions.add(session);
        }
      }
      
      // Sort by unit code within each date
      uniqueSessions.sort((a, b) {
        String unitCodeA = a['unitCode'] ?? 'Unknown';
        String unitCodeB = b['unitCode'] ?? 'Unknown';
        return unitCodeA.compareTo(unitCodeB);
      });
      
      // Replace the sessions for this date with the deduplicated set
      groupedByDate[dateKey] = uniqueSessions;
    }
    
    // Flatten the grouped list in date order
    List<Map<String, dynamic>> result = [];
    for (String dateKey in sortedDates) {
      result.addAll(groupedByDate[dateKey]!);
    }
    
    return result;
  }

  String _formatDateTime(dynamic timestamp) {
    DateTime date;
    
    if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      // Try to parse as int first
      int? epochTime = int.tryParse(timestamp);
      if (epochTime != null) {
        date = DateTime.fromMillisecondsSinceEpoch(epochTime);
      } else {
        // Try to parse as ISO date
        try {
          date = DateTime.parse(timestamp);
        } catch (e) {
          return timestamp; // Return as is if parsing fails
        }
      }
    } else {
      return 'Unknown date';
    }
    
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final filteredSessions = _isLoading ? [] : _getFilteredSessions();
    
    // Group sessions by date for display instead of by unit code
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    
    // Track unique sessions to prevent repetition
    Map<String, Map<String, dynamic>> uniqueSessionMap = {};
    
    for (var session in filteredSessions) {
      String unitCode = session['unitCode'] ?? 'Unknown';
      
      // Create a date key for sorting
      String dateKey = "Unknown";
      DateTime? sessionDate;
      
      if (session.containsKey('date')) {
        dateKey = session['date'].toString();
        try {
          sessionDate = DateTime.parse(session['date']);
          dateKey = DateFormat('yyyy-MM-dd').format(sessionDate);
        } catch (e) {
          print('Error parsing date: $e');
        }
      } else if (session.containsKey('timestamp')) {
        try {
          final timestamp = session['timestamp'];
          DateTime date;
          if (timestamp is int) {
            date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String) {
            if (int.tryParse(timestamp) != null) {
              date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
            } else {
              date = DateTime.parse(timestamp);
            }
          } else {
            date = DateTime.now();
          }
          sessionDate = date;
          dateKey = DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          print('Error formatting date: $e');
        }
      }
      
      // Create unique identifier that includes unit code and date
      String timeIdentifier = '';
      if (session.containsKey('startTime') && session.containsKey('endTime')) {
        timeIdentifier = '${session['startTime']}-${session['endTime']}';
      }
      
      // Create a unique key that combines unit + date + time
      String uniqueSessionKey = '$unitCode::$dateKey::$timeIdentifier';
      
      // Check if we've seen this session before
      if (uniqueSessionMap.containsKey(uniqueSessionKey)) {
        // This is a duplicate session - merge attendee data if needed
        Map<String, dynamic> existingSession = uniqueSessionMap[uniqueSessionKey]!;
        
        // Merge attendee details if both sessions have them
        if (session.containsKey('attendeeDetails') && existingSession.containsKey('attendeeDetails')) {
          List<dynamic> newAttendeeDetails = session['attendeeDetails'];
          List<dynamic> existingAttendeeDetails = existingSession['attendeeDetails'];
          
          // Create a map of existing attendees by email to avoid duplicates
          Map<String, dynamic> attendeeByEmail = {};
          for (var attendee in existingAttendeeDetails) {
            final email = attendee['email'];
            if (email != null && email.isNotEmpty) {
              attendeeByEmail[email] = attendee;
            }
          }
          
          // Add any new attendees not already in the existing session
          for (var attendee in newAttendeeDetails) {
            final email = attendee['email'];
            if (email != null && email.isNotEmpty && !attendeeByEmail.containsKey(email)) {
              existingAttendeeDetails.add(attendee);
              attendeeByEmail[email] = attendee;
            }
          }
          
          // Update existing session with merged attendee details
          existingSession['attendeeDetails'] = existingAttendeeDetails;
        }
      } else {
        // This is a new unique session
        uniqueSessionMap[uniqueSessionKey] = session;
        
        // Add session to date group
        if (!groupedByDate.containsKey(dateKey)) {
          groupedByDate[dateKey] = [];
        }
        groupedByDate[dateKey]!.add(session);
      }
    }
    
    // Sort dates in reverse chronological order (newest first)
    List<String> sortedDates = groupedByDate.keys.toList();
    sortedDates.sort((a, b) {
      try {
        DateTime dateA = DateTime.parse(a);
        DateTime dateB = DateTime.parse(b);
        return dateB.compareTo(dateA); // Reverse order (newest first)
      } catch (e) {
        return b.compareTo(a); // Fallback to string comparison (still newest first)
      }
    });
    
    // Sort sessions within each date by unit code
    for (String dateKey in groupedByDate.keys) {
      groupedByDate[dateKey]!.sort((a, b) {
        String unitCodeA = a['unitCode'] ?? 'Unknown';
        String unitCodeB = b['unitCode'] ?? 'Unknown';
        return unitCodeA.compareTo(unitCodeB);
      });
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance History'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Filter bar at the top
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  // Date selector
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null && picked != _selectedDate) {
                            setState(() {
                              _selectedDate = picked;
                              _selectedWeek = 0; // Clear week selection
                            });
                          }
                        },
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Icon(Icons.calendar_today, color: Colors.grey.shade700),
                            ),
                            Expanded(
                              child: Text(
                                _selectedDate != null 
                                    ? DateFormat('d MMM yyyy').format(_selectedDate!)
                                    : 'Select date',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                            if (_selectedDate != null)
                              IconButton(
                                icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade700),
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Week selection dropdown
                  PopupMenuButton<Map<String, int>>(
                    tooltip: 'Select week',
                    child: Container(
                      height: 44,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range, color: Colors.grey.shade700),
                          SizedBox(width: 4),
                          Text(
                            _selectedWeek > 0 
                                ? 'Week $_selectedWeek of ${_getMonthName(_selectedMonth)}' 
                                : 'Select week',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          if (_selectedWeek > 0)
                            IconButton(
                              icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade700),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _selectedWeek = 0;
                                  _selectedMonth = 0;
                                });
                              },
                          ),
                        ],
                      ),
                    ),
                    onSelected: (Map<String, int> value) {
                      setState(() {
                        _selectedWeek = value['week']!;
                        _selectedMonth = value['month']!;
                        _selectedDate = null; // Clear date selection
                      });
                    },
                    itemBuilder: (context) => _buildWeekSelectionItems(),
                  ),
                ],
              ),
            ),
          ),
          
          // Spinner or no data message
          if (_isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (filteredSessions.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No attendance records found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _selectedDate != null || _selectedWeek > 0
                          ? 'Try adjusting your date filter'
                          : 'Start taking attendance to see records here',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // List of sessions grouped by date
            Expanded(
              child: ListView.builder(
                itemCount: sortedDates.length,
                itemBuilder: (context, dateIndex) {
                  final dateKey = sortedDates[dateIndex];
                  final dateSessions = groupedByDate[dateKey]!;
                  
                  // Format the date for display
                  String displayDate = 'Unknown Date';
                  try {
                    final date = DateTime.parse(dateKey);
                    displayDate = DateFormat('EEEE, MMMM d, yyyy').format(date);
                  } catch (e) {
                    displayDate = dateKey;
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dateIndex > 0) Divider(thickness: 2),
                      // Date header
                      Container(
                        color: Colors.blue.shade100,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        width: double.infinity,
                        child: Text(
                          displayDate,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      // Sessions for this date
                      ...dateSessions.map((session) {
                        final unitCode = session['unitCode'] ?? 'Unknown';
                        final unitName = session['unitName'] ?? 'Unknown Unit';
                          
                        // Extract time if available
                        String timeStr = '';
                        if (session.containsKey('startTime') && session.containsKey('endTime')) {
                          timeStr = '${session['startTime']} - ${session['endTime']}';
                        }
                          
                        // Get pre-calculated counts or compute them from attendee details
                        int presentCount = session['presentCount'] ?? 0;
                        int absentCount = session['absentCount'] ?? 0;
                        
                        // If no pre-calculated counts but we have attendee details, calculate from them
                        if (presentCount == 0 && session.containsKey('attendeeDetails')) {
                          final attendeeDetails = session['attendeeDetails'] as List<dynamic>? ?? [];
                        
                        for (var attendee in attendeeDetails) {
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
                        
                        // If we have attendees but no calculated count, use attendee count
                        if (presentCount == 0 && session.containsKey('attendees') && session['attendees'] is List) {
                          presentCount = (session['attendees'] as List).length;
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Card(
                            elevation: 2,
                            child: ExpansionTile(
                              title: Text(
                                '$unitCode - $unitName',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (timeStr.isNotEmpty) 
                                    Text('Time: $timeStr'),
                                  // Display lecture number in subtitle if available
                                  if (session.containsKey('lectureNumber') && session['lectureNumber'] != null)
                                    Text(
                                      'Lecture #${session['lectureNumber']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Text(
                                        'Present: $presentCount',
                                        style: TextStyle(
                                          fontWeight: presentCount > 0 ? FontWeight.bold : FontWeight.normal,
                                          color: presentCount > 0 ? Colors.green.shade800 : null,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Text('|'),
                                      ),
                                      Text(
                                        'Absent: $absentCount',
                                        style: TextStyle(
                                          fontWeight: absentCount > 0 ? FontWeight.bold : FontWeight.normal,
                                          color: absentCount > 0 ? Colors.red.shade800 : null,
                                        ),
                                      ),
                                      if (presentCount > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: Icon(
                                            Icons.group,
                                            size: 16,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (session.containsKey('department'))
                                      Text(
                                        'Department: ${session['department']}',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                      ),
                                      if (session.containsKey('course'))
                                      Text(
                                        'Course: ${session['course']}',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                      ),
                                      // Always display year and semester
                                      Text(
                                        'Year: ${session['year'] ?? "3"}, Semester: ${session['semester'] ?? "2"}',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                      ),
                                      // Display lecture number if available
                                      if (session.containsKey('lectureNumber'))
                                      Text(
                                        'Lecture #: ${session['lectureNumber']}',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                      ),
                                      SizedBox(height: 16),
                                      
                                      // Show attendance statistics
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            Column(
                                              children: [
                                                Text(
                                                  'Present',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade800,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  '${presentCount}',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              width: 1,
                                              height: 40,
                                              color: Colors.grey.shade300,
                                            ),
                                            Column(
                                              children: [
                                                Text(
                                                  'Absent',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red.shade800,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  '${absentCount}',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              width: 1,
                                              height: 40,
                                              color: Colors.grey.shade300,
                                            ),
                                            Column(
                                              children: [
                                                Text(
                                                  'Total',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade800,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  '${session['eligibleCount'] ?? presentCount + absentCount}',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      
                                      // Display list of attendees if available
                                      if (session.containsKey('attendeeDetails')) ...[
                                        Text(
                                          'Attendance List:',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 8),
                                        
                                        // Attendance list with tabs for Present/Absent
                                        DefaultTabController(
                                          length: 2,
                                          child: Column(
                                            children: [
                                              TabBar(
                                                tabs: [
                                                  Tab(text: 'Present (${presentCount})'),
                                                  Tab(text: 'Absent (${absentCount})'),
                                                ],
                                                labelColor: Colors.blue.shade700,
                                                indicatorColor: Colors.blue,
                                              ),
                                              SizedBox(height: 8),
                                              SizedBox(
                                                height: 200, // Fixed height for the list
                                                child: TabBarView(
                                                  children: [
                                                    // Present students tab
                                                    SingleChildScrollView(
                                                      child: Column(
                                                        children: List.generate(
                                                          (session['attendeeDetails'] as List).length,
                                                          (index) {
                                                            final attendee = (session['attendeeDetails'] as List)[index];
                                                            final details = attendee['details'];
                                                            
                                                            // Skip absent students in this tab
                                                            if (details is Map && details['status'] == 'absent') {
                                                              return SizedBox.shrink();
                                                            }
                                                            
                                                            final email = attendee['email'] ?? '';
                                                            final name = details is Map ? (details['name'] ?? details['studentName'] ?? 'Student') : 'Student';
                                                            
                                                            return Padding(
                                                              padding: EdgeInsets.symmetric(vertical: 4),
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                                                  SizedBox(width: 8),
                                                                  Expanded(
                                                                    child: Text('$name ($email)'),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                        ).where((widget) => widget is! SizedBox).toList(),
                                                      ),
                                                    ),
                                                    
                                                    // Absent students tab
                                                    SingleChildScrollView(
                                                      child: Column(
                                                        children: List.generate(
                                                          (session['attendeeDetails'] as List).length,
                                                          (index) {
                                                            final attendee = (session['attendeeDetails'] as List)[index];
                                                            final details = attendee['details'];
                                                            
                                                            // Skip present students in this tab
                                                            if (details is Map && details['status'] != 'absent') {
                                                              return SizedBox.shrink();
                                                            }
                                                            
                                                            final email = attendee['email'] ?? '';
                                                            final name = details is Map ? (details['name'] ?? details['studentName'] ?? 'Student') : 'Student';
                                                            
                                                            return Padding(
                                                              padding: EdgeInsets.symmetric(vertical: 4),
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.cancel, color: Colors.red, size: 16),
                                                                  SizedBox(width: 8),
                                                                  Expanded(
                                                                    child: Text('$name ($email)'),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                        ).where((widget) => widget is! SizedBox).toList(),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ]
                                      else if (session.containsKey('attendees') && session['attendees'] is List) ...[
                                        Text(
                                          'Attendees:',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 8),
                                        ...List.generate((session['attendees'] as List).length, (index) {
                                          final attendee = (session['attendees'] as List)[index];
                                          final email = attendee is Map ? (attendee['studentEmail'] ?? '') : '';
                                          final name = attendee is Map ? (attendee['studentName'] ?? 'Student') : 'Student';
                                          
                                          return Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text('$name ($email)'),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ] else
                                        Text('No detailed attendance data available.'),
                                      
                                      SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: Icon(Icons.print),
                                            label: Text('Print Attendance'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () {
                                              // Get all sessions for this unit to provide context
                                              final relatedSessions = filteredSessions.where((s) => 
                                                s['unitCode'] == session['unitCode']).toList().cast<Map<String, dynamic>>();
                                              
                                              // Make sure we have course information in the session data
                                              if (!session.containsKey('department') || session['department'] == null || session['department'].isEmpty) {
                                                // Try to get department from the first attendee
                                                if (session.containsKey('attendees') && session['attendees'] is List && session['attendees'].isNotEmpty) {
                                                  final firstAttendee = session['attendees'].first;
                                                  if (firstAttendee is Map && firstAttendee.containsKey('department')) {
                                                    session['department'] = firstAttendee['department'];
                                                  }
                                                }
                                              }
                                              if (!session.containsKey('course') || session['course'] == null || session['course'].isEmpty) {
                                                // Try to get course from the first attendee
                                                if (session.containsKey('attendees') && session['attendees'] is List && session['attendees'].isNotEmpty) {
                                                  final firstAttendee = session['attendees'].first;
                                                  if (firstAttendee is Map && firstAttendee.containsKey('course')) {
                                                    session['course'] = firstAttendee['course'];
                                                  }
                                                }
                                              }
                                              
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => PrintAttendancePage(
                                                    sessionData: session,
                                                    relatedSessions: relatedSessions,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
  
  List<PopupMenuEntry<Map<String, int>>> _buildWeekSelectionItems() {
    List<PopupMenuEntry<Map<String, int>>> items = [];
    
    // Month sections
    for (int month = -2; month <= 2; month++) {
      String monthName = _getMonthName(month);
      String monthLabel;
      
      if (month == 0) {
        monthLabel = 'Current Month ($monthName)';
      } else if (month == -1) {
        monthLabel = 'Previous Month ($monthName)';
      } else if (month == -2) {
        monthLabel = '2 Months Ago ($monthName)';
      } else if (month == 1) {
        monthLabel = 'Next Month ($monthName)';
                                                      } else {
        monthLabel = '2 Months Ahead ($monthName)';
      }
      
      // Add month header
      items.add(
        PopupMenuItem<Map<String, int>>(
          enabled: false,
          child: Text(
            monthLabel,
                                                      style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      );
      
      // Add weeks for this month
      for (int week = 1; week <= 4; week++) {
        items.add(
          PopupMenuItem<Map<String, int>>(
            value: {'week': week, 'month': month},
            child: Text('Week $week'),
          ),
        );
      }
      
      // Add divider if not the last month
      if (month < 2) {
        items.add(PopupMenuDivider());
      }
    }
    
    return items;
  }

  Future<void> _saveAttendanceRecord(String sessionKey, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save the session data
      await prefs.setString(sessionKey, json.encode(data));
      
      // Add to lecturer history
      List<String> lecturerHistory = [];
      final dynamic existingHistory = prefs.get('lecturer_attendance_history');
      
      if (existingHistory is List<String>) {
        lecturerHistory = List<String>.from(existingHistory);
      } else if (existingHistory is String) {
        try {
          final List<dynamic> parsed = json.decode(existingHistory);
          lecturerHistory = parsed.map((item) => item.toString()).toList();
        } catch (e) {
          lecturerHistory = [existingHistory];
        }
      }
      
      if (!lecturerHistory.contains(sessionKey)) {
        lecturerHistory.add(sessionKey);
        await prefs.setStringList('lecturer_attendance_history', lecturerHistory);
      }
      
      // Reload data to reflect changes
      _loadAttendanceHistory();
    } catch (e) {
      print('Error saving attendance record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving attendance record: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Load attendance history
  Future<void> _loadAttendanceHistory() async {
    setState(() {
      _isLoading = true;
    });
    
    await _refreshAttendanceData();
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
} 
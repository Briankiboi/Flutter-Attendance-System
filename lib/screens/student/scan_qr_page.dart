import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({Key? key}) : super(key: key);

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  bool isScanning = false;
  bool isProcessing = false;
  bool isInCoolingState = false;  // New flag for cooling state
  late MobileScannerController controller;
  String? _email;
  String? _studentName;
  String? _department;
  String? _course;
  String? _year;
  String? _semester;
  Map<String, DateTime> _lastAttendanceTimes = {};
  Uint8List? _qrCodeData;
  Map<String, dynamic>? _currentQRMetadata;
  Set<String> _markedSessionIds = {};
  Set<String> _scannedQRCodes = {};

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    
    // Load user data and scanned QR codes from SharedPreferences on startup
    _loadUserData();
    _loadScannedQRCodes();
    
    // Setup periodic check for active sessions (every 30 seconds)
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkActiveSessionsInPrefs();
      } else {
        timer.cancel();
      }
    });

    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted && _lastAttendanceTimes.containsKey(_email ?? '')) {
        setState(() {});
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _email = args['email'];
        _studentName = args['name'];
        _department = args['department'];
        _course = args['course'];
        _year = args['year']; 
        _semester = args['semester'];
      });
      _saveCurrentUserData(args);
    }
    _checkQRCodeAvailability();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _email = prefs.getString('current_user_email');
        _studentName = prefs.getString('current_user_name');
        _department = prefs.getString('current_user_department');
        _course = prefs.getString('current_user_course');
        _year = prefs.getString('current_user_year');
        _semester = prefs.getString('current_user_semester');
      });
      
      // Load attendance history
      final lastAttendanceTimesStr = prefs.getString('last_attendance_times');
      if (lastAttendanceTimesStr != null) {
        final Map<String, dynamic> decoded = json.decode(lastAttendanceTimesStr);
        _lastAttendanceTimes = decoded.map((key, value) => 
          MapEntry(key, DateTime.parse(value)));
      }
      
      // Load marked session IDs
      final markedSessionIdsStr = prefs.getString('marked_session_ids');
      if (markedSessionIdsStr != null) {
        final List<dynamic> decoded = json.decode(markedSessionIdsStr);
        _markedSessionIds = decoded.map((e) => e.toString()).toSet();
      }

      // Check if user is in cooling state
      if (_email != null && _lastAttendanceTimes.containsKey(_email)) {
        final lastAttendanceTime = _lastAttendanceTimes[_email!]!;
        if (DateTime.now().difference(lastAttendanceTime).inMinutes < 60) {
          setState(() {
            isInCoolingState = true;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadScannedQRCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scannedCodesStr = prefs.getString('scanned_qr_codes_${_email}');
      if (scannedCodesStr != null) {
        final List<dynamic> decoded = json.decode(scannedCodesStr);
        _scannedQRCodes = decoded.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      print('Error loading scanned QR codes: $e');
    }
  }

  Future<void> _saveScannedQRCode(String sessionId) async {
    _scannedQRCodes.add(sessionId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('scanned_qr_codes_${_email}', json.encode(_scannedQRCodes.toList()));
    } catch (e) {
      print('Error saving scanned QR code: $e');
    }
  }

  Future<void> _checkQRCodeAvailability() async {
    if (_email == null) return;

    // If in cooling state, don't check for QR codes
    if (isInCoolingState) return;

    try {
      bool foundActiveSession = await _checkActiveSessionsInPrefs();
      if (foundActiveSession) {
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final studentQRDir = Directory('$path/student_qr_codes/$_email');
      
      if (await studentQRDir.exists()) {
        final files = await studentQRDir.list().toList();
        if (files.isNotEmpty) {
          final latestQR = files.whereType<File>().reduce((a, b) => 
            a.statSync().modified.isAfter(b.statSync().modified) ? a : b);
          
          final filename = latestQR.path.split('/').last;
          final timestamp = int.tryParse(filename.split('_').last.replaceAll('.png', ''));
          
          if (timestamp != null) {
            final prefs = await SharedPreferences.getInstance();
            final metadataString = prefs.getString('qr_metadata_$timestamp');
            
            if (metadataString != null) {
              final lastAttendanceTime = _lastAttendanceTimes[_email!];
              final metadata = json.decode(metadataString);
              final sessionId = metadata['timestamp']?.toString();
              
              // Check if this QR code has already been scanned
              if (sessionId != null && _scannedQRCodes.contains(sessionId)) {
                if (mounted) {
                  setState(() {
                    _qrCodeData = null;
                    _currentQRMetadata = null;
                  });
                }
                return;
              }
              
              if (sessionId != null) {
                final sessionKey = 'session_$sessionId';
                final sessionDataString = prefs.getString(sessionKey);
                
                if (sessionDataString != null) {
                  final sessionData = json.decode(sessionDataString);
                  final attendees = sessionData['attendees'] as List<dynamic>;
                  
                  bool alreadyMarked = false;
                  for (var attendee in attendees) {
                    if (attendee is Map && attendee['studentEmail'] == _email) {
                      alreadyMarked = true;
                      break;
                    }
                  }
                  
                  if (alreadyMarked) {
                    if (mounted) {
                      setState(() {
                        _qrCodeData = null;
                        _currentQRMetadata = null;
                      });
                    }
                    return;
                  }
                }
              }
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _qrCodeData = null;
              _currentQRMetadata = null;
            });
          }
        }
      }
    } catch (e) {
      print('Error checking QR code availability: $e');
    }
  }

  Future<bool> _checkActiveSessionsInPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_email == null) {
        return false;
      }
      
      // If in cooling state, don't check for active sessions
      if (isInCoolingState) {
        return true;
      }
      
      if (_lastAttendanceTimes.containsKey(_email) && 
          DateTime.now().difference(_lastAttendanceTimes[_email]!).inMinutes < 60) {
        setState(() {
          isInCoolingState = true;
        });
        return true;
      }
      
      List<String> activeSessions = prefs.getStringList('active_sessions') ?? [];
      
      if (activeSessions.isEmpty) {
        return false;
      }
      
      for (String sessionId in activeSessions.reversed) {
        // Skip if this QR code has already been scanned
        if (_scannedQRCodes.contains(sessionId)) {
          continue;
        }
        
        bool alreadyAttended = prefs.getBool('attended_session_${_email}_$sessionId') ?? false;
        if (alreadyAttended) {
          continue;
        }
        
        String studentSessionKey = 'student_${_email}_session_$sessionId';
        String? studentSessionData = prefs.getString(studentSessionKey);
        
        if (studentSessionData != null) {
          String? activeSessionData = prefs.getString('active_session_$sessionId');
          if (activeSessionData != null) {
            Map<String, dynamic> metadata = json.decode(activeSessionData);
            
            if (mounted) {
              setState(() {
                _qrCodeData = null;
                _currentQRMetadata = metadata;
              });
              return true;
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking active sessions: $e');
      return false;
    }
  }

  Future<bool> _markAttendanceForSession(String sessionId) async {
    try {
      // First check if this QR code has already been scanned
      if (_scannedQRCodes.contains(sessionId)) {
        return true; // Return true to avoid showing error message
      }
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      String? sessionDataStr = prefs.getString('active_session_$sessionId');
      if (sessionDataStr == null) return false;
      
      Map<String, dynamic> sessionData = json.decode(sessionDataStr);
      
      if (!(sessionData['isActive'] ?? false)) return false;
      
      final now = DateTime.now();
      final startTimeStr = sessionData['startTime'] as String?;
      final endTimeStr = sessionData['endTime'] as String?;
      
      if (startTimeStr != null && endTimeStr != null) {
        final startParts = startTimeStr.split(':');
        final endParts = endTimeStr.split(':');
        
        if (startParts.length == 2 && endParts.length == 2) {
          final startTime = DateTime(
            now.year, now.month, now.day,
            int.parse(startParts[0]), int.parse(startParts[1])
          );
          final endTime = DateTime(
            now.year, now.month, now.day,
            int.parse(endParts[0]), int.parse(endParts[1])
          ).add(Duration(minutes: 30));
          
          if (now.isBefore(startTime) || now.isAfter(endTime)) return false;
        }
      }
      
      final attendanceKey = 'session_$sessionId';
      String? existingAttendanceStr = prefs.getString(attendanceKey);
      Map<String, dynamic> attendanceRecord;
      
      if (existingAttendanceStr != null) {
        attendanceRecord = json.decode(existingAttendanceStr);
        List<dynamic> attendees = attendanceRecord['attendees'] ?? [];
        
        bool alreadyMarked = false;
        for (var attendee in attendees) {
          if (attendee is Map && attendee['studentEmail'] == _email) {
            alreadyMarked = true;
            break;
          }
        }
        
        if (!alreadyMarked) {
          attendees.add({
            'studentEmail': _email,
            'studentName': _studentName,
            'department': _department,
            'course': _course,
            'year': _year,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          attendanceRecord['attendees'] = attendees;
        } else {
          return true;
        }
      } else {
        attendanceRecord = {
          'sessionId': sessionId,
          'unitCode': sessionData['unitCode'],
          'unitName': sessionData['unitName'],
          'date': DateTime.now().toString().substring(0, 10),
          'startTime': startTimeStr,
          'endTime': endTimeStr,
          'lectureNumber': sessionData['lectureNumber'] ?? '1', // Include lecture number
          'department': sessionData['department'],
          'course': sessionData['course'],
          'year': sessionData['year'],
          'semester': sessionData['semester'],
          'attendees': [
            {
              'studentEmail': _email,
              'studentName': _studentName,
              'department': _department,
              'course': _course,
              'year': _year,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }
          ]
        };
      }
      
      // Save the updated attendance record
      await prefs.setString(attendanceKey, json.encode(attendanceRecord));
      
      // Make sure this session is in the lecturer's attendance history
      final lecturerHistoryKey = 'lecturer_attendance_history';
      List<String> lecturerHistory = [];
      final historyData = prefs.get(lecturerHistoryKey);
      
      if (historyData is List<String>) {
        lecturerHistory = List<String>.from(historyData);
      } else if (historyData is String) {
        try {
          final List<dynamic> parsed = json.decode(historyData);
          lecturerHistory = parsed.map((item) => item.toString()).toList();
        } catch (e) {
          if (historyData != null && historyData.isNotEmpty) {
            lecturerHistory = [historyData];
          }
        }
      }
      
      if (!lecturerHistory.contains(attendanceKey)) {
        lecturerHistory.add(attendanceKey);
        await prefs.setStringList(lecturerHistoryKey, lecturerHistory);
      }
      
      // Mark this student as having attended this session
      await prefs.setBool('attended_session_${_email}_$sessionId', true);
      
      // Save this QR code as scanned to prevent scanning again
      await _saveScannedQRCode(sessionId);
      
      if (mounted) {
        setState(() {
          _lastAttendanceTimes[_email!] = DateTime.now();
          _markedSessionIds.add(sessionId);
          isInCoolingState = true; // Enter cooling state
        });
      }
      
      return true;
    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }

  bool _isQRCodeValid() {
    if (_currentQRMetadata == null) return false;
    
    try {
      final now = DateTime.now();
      final startTimeStr = _currentQRMetadata!['startTime']?.toString();
      final endTimeStr = _currentQRMetadata!['endTime']?.toString();
      
      if (startTimeStr == null || endTimeStr == null) return false;
      
      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');
      
      if (startParts.length != 2 || endParts.length != 2) return false;
      
      final startTime = DateTime(
        now.year, now.month, now.day,
        int.parse(startParts[0]), int.parse(startParts[1])
      );
      final endTime = DateTime(
        now.year, now.month, now.day,
        int.parse(endParts[0]), int.parse(endParts[1])
      ).add(Duration(minutes: 30));
      
      return now.isAfter(startTime) && now.isBefore(endTime);
    } catch (e) {
      return false;
    }
  }

  String _getRemainingTime() {
    if (_currentQRMetadata == null) return '';
    
    try {
      final now = DateTime.now();
      final endTimeStr = _currentQRMetadata!['endTime'].toString();
      final endParts = endTimeStr.split(':');
      
      if (endParts.length != 2) return '';
      
      final endTime = DateTime(
        now.year, now.month, now.day,
        int.parse(endParts[0]), int.parse(endParts[1])
      ).add(Duration(minutes: 20));
      
      final difference = endTime.difference(now);
      
      if (difference.isNegative) return 'Expired';
      
      return '${difference.inHours.toString().padLeft(2, '0')}:${(difference.inMinutes % 60).toString().padLeft(2, '0')}:${(difference.inSeconds % 60).toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _getCoolingTimeRemaining() {
    if (_email == null || !_lastAttendanceTimes.containsKey(_email!)) {
      return '';
    }
    
    final lastAttendanceTime = _lastAttendanceTimes[_email!]!;
    final difference = Duration(minutes: 60) - DateTime.now().difference(lastAttendanceTime);
    
    if (difference.isNegative) {
      if (mounted) {
        setState(() {
          isInCoolingState = false;
        });
      }
      return '0';
    }
    
    return '${difference.inMinutes}:${(difference.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  bool _hasMarkedAttendanceForCurrentSession() {
    if (_currentQRMetadata == null || !_currentQRMetadata!.containsKey('sessionId') || _email == null) {
      return false;
    }
    
    String sessionId = _currentQRMetadata!['sessionId'].toString();
    return _markedSessionIds.contains(sessionId) || _scannedQRCodes.contains(sessionId);
  }

  @override
  void dispose() {
    controller.dispose();
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _buildQRCodeDisplay(),
    );
  }

  Widget _buildQRCodeDisplay() {
    // If in cooling state, show the cooling state UI
    if (isInCoolingState) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Attendance Marked Successfully',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your attendance has been recorded',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.green.shade700),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'You can mark attendance for another class after ${_getCoolingTimeRemaining()} minutes',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green.shade800, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_qrCodeData != null || _currentQRMetadata != null) {
      if (!_isQRCodeValid()) {
        return _buildDefaultDisplay('QR Code Not Available', 'Outside of valid time window');
      }

      return SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                        ),
                        child: _qrCodeData != null
                          ? Image.memory(
                                _qrCodeData!,
                                width: 250,
                                height: 250,
                                fit: BoxFit.contain,
                            )
                          : SizedBox(
                              width: 250,
                              height: 250,
                              child: QrImageView(
                                data: json.encode(_currentQRMetadata),
                                version: QrVersions.auto,
                                backgroundColor: Colors.white,
                              ),
                            ),
                      ),
                      if (isScanning)
                        Container(
                          width: 282,
                          height: 282,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Scanning...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: ElevatedButton.icon(
                      onPressed: _hasMarkedAttendanceForCurrentSession()
                        ? null
                        : () async {
                            if (_currentQRMetadata?.containsKey('sessionId') ?? false) {
                              setState(() => isScanning = true);
                              await Future.delayed(Duration(seconds: 1));
                              
                              final success = await _markAttendanceForSession(
                                _currentQRMetadata!['sessionId'].toString()
                              );
                              
                              setState(() => isScanning = false);
                              
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Attendance marked successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to mark attendance. Please try again.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                      icon: Icon(_hasMarkedAttendanceForCurrentSession()
                        ? Icons.check_circle
                        : Icons.check_circle_outline),
                      label: Text(
                        _hasMarkedAttendanceForCurrentSession()
                          ? 'Attendance Marked'
                          : 'Mark Attendance',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasMarkedAttendanceForCurrentSession()
                          ? Colors.grey.shade400
                          : Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (_currentQRMetadata != null) ...[
                    SizedBox(height: 16),
                    _buildDetailsSection(),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return _buildDefaultDisplay(
      'No QR Code Available',
      'Waiting for lecturer to send QR code...'
    );
  }

  Widget _buildDefaultDisplay(String title, String subtitle) {
    return Center(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Icon(
            Icons.qr_code_2_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Divider(),
                  _detailRow('Unit', _currentQRMetadata!['unitName']),
                  _detailRow('Unit Code', _currentQRMetadata!['unitCode']),
                  _detailRow('Lecture No', _currentQRMetadata!['lectureNumber']?.toString() ?? '1'),
                  _detailRow('Time', '${_currentQRMetadata!['startTime']} - ${_currentQRMetadata!['endTime']}'),
                  _detailRow('Remaining Time', _getRemainingTime()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
            ),
          ),
            Text(
            value,
              style: TextStyle(
              fontSize: 15,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
              ),
            ),
          ],
      ),
    );
  }

  Timer? _checkTimer;

  void _startPeriodicChecking() {
    // Cancel any existing timer
    _checkTimer?.cancel();
    
    // Check immediately
    _checkQRCodeAvailability();
    
    // Then check every 5 seconds
    _checkTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted) {
        _checkQRCodeAvailability();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _saveCurrentUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_email', userData['email']);
      await prefs.setString('current_user_name', userData['name']);
      await prefs.setString('current_user_department', userData['department']);
      await prefs.setString('current_user_course', userData['course']);
      await prefs.setString('current_user_year', userData['year'].toString());
      await prefs.setString('current_user_semester', userData['semester'].toString());
      
      // Save attendance times if they exist
      if (_lastAttendanceTimes.isNotEmpty) {
        final encoded = json.encode(
          _lastAttendanceTimes.map((key, value) => MapEntry(key, value.toIso8601String()))
        );
        await prefs.setString('last_attendance_times', encoded);
      }
      
      // Save marked session IDs
      if (_markedSessionIds.isNotEmpty) {
        await prefs.setString('marked_session_ids', json.encode(_markedSessionIds.toList()));
      }
    } catch (e) {
      print('Error saving user data: $e');
    }
  }
}

// Scanner effect for QR code processing
class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scanPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final finderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final double scanAreaSize = size.width * 0.9;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;

    // Main scan area
    final rect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);
    final RRect roundedRect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(10),
    );

    canvas.drawRRect(roundedRect, scanPaint);

    // Highlight the three finder patterns (corners of QR code)
    final double cornerSize = scanAreaSize * 0.22; // Size of QR finder pattern

    // Top-left finder pattern
    _drawFinderPattern(canvas, Offset(left, top), cornerSize, finderPaint);
    
    // Top-right finder pattern
    _drawFinderPattern(canvas, Offset(left + scanAreaSize - cornerSize, top), cornerSize, finderPaint);
    
    // Bottom-left finder pattern
    _drawFinderPattern(canvas, Offset(left, top + scanAreaSize - cornerSize), cornerSize, finderPaint);

    // Draw scan lines
    _drawScanLines(canvas, rect, scanPaint);
  }

  // Draw a QR finder pattern at the given position
  void _drawFinderPattern(Canvas canvas, Offset position, double size, Paint paint) {
    // Outer square
    final outerRect = Rect.fromLTWH(position.dx, position.dy, size, size);
    canvas.drawRect(outerRect, paint);
    
    // Middle square
    final middleSize = size * 0.7;
    final middleOffset = (size - middleSize) / 2;
    final middleRect = Rect.fromLTWH(
      position.dx + middleOffset,
      position.dy + middleOffset,
      middleSize,
      middleSize
    );
    canvas.drawRect(middleRect, paint);
    
    // Inner square
    final innerSize = size * 0.35;
    final innerOffset = (size - innerSize) / 2;
    final innerRect = Rect.fromLTWH(
      position.dx + innerOffset, 
      position.dy + innerOffset, 
      innerSize, 
      innerSize
    );
    canvas.drawRect(innerRect, paint..style = PaintingStyle.fill);
  }

  // Draw animated scan lines to show processing
  void _drawScanLines(Canvas canvas, Rect rect, Paint paint) {
    // Horizontal scan lines
    final scanLinePaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    final lineCount = 5;
    final lineSpacing = rect.height / (lineCount + 1);
    
    for (int i = 1; i <= lineCount; i++) {
      final y = rect.top + (lineSpacing * i);
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        scanLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 
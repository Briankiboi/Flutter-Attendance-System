import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:ntp/ntp.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_attendance/models/attendance_schema.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/device_security_service.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class AttendanceService {
  final SupabaseService _supabaseService = SupabaseService();
  final DeviceSecurityService _deviceSecurity = DeviceSecurityService();
  final _maxTimeOffset = const Duration(minutes: 2);
  final _maxDistanceMeters = 50.0;
  final _supabase = Supabase.instance.client;

  // Constants for attendance structure
  static const int hoursPerSession = 2; // Each session is 2 hours
  static const int sessionsPerWeek = 2; // Two sessions per week
  static const int hoursPerWeek = hoursPerSession * sessionsPerWeek; // 4 hours per week
  static const int weeksPerMonth = 4;
  static const int monthsPerSemester = 3;
  
  // Total hours calculation
  static const int hoursPerMonth = hoursPerWeek * weeksPerMonth; // 16 hours per month
  static const int totalSemesterHours = hoursPerMonth * monthsPerSemester; // 48 total hours
  static const double eligibilityThreshold = 0.7; // 70% requirement
  
  // Required hours for eligibility
  static final int requiredSemesterHours = (totalSemesterHours * eligibilityThreshold).round(); // 34 hours (70% of 48)

  // Verify time synchronization
  Future<TimeVerification> verifyTime() async {
    try {
      // Get NTP time from multiple servers for accuracy
      final serverTime = await NTP.now();
      final deviceTime = DateTime.now();
      
      // Get GPS time for additional verification
      final position = await Geolocator.getCurrentPosition();
      final gpsTime = DateTime.fromMillisecondsSinceEpoch(
        position.timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch
      );

      final timeDiff = serverTime.difference(deviceTime).inMinutes.abs();
      final isTimeValid = timeDiff <= _maxTimeOffset.inMinutes;

      String message = isTimeValid 
          ? 'Time verification successful'
          : 'Please sync your device time. Difference: $timeDiff minutes';

      return TimeVerification(
        serverTime: serverTime,
        deviceTime: deviceTime,
        gpsTime: gpsTime,
        isTimeValid: isTimeValid,
        timeDifferenceMinutes: timeDiff,
        validationMessage: message,
      );
    } catch (e) {
      print('Time verification error: $e');
      return TimeVerification(
        serverTime: DateTime.now().toUtc(),
        deviceTime: DateTime.now(),
        gpsTime: DateTime.now(),
        isTimeValid: false,
        timeDifferenceMinutes: -1,
        validationMessage: 'Failed to verify time: $e',
      );
    }
  }

  // Verify location
  Future<LocationVerification> verifyLocation(Map<String, double> classCoordinates) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        classCoordinates['latitude']!,
        classCoordinates['longitude']!
      );

      final isInRange = distance <= _maxDistanceMeters;

      // Get location name using reverse geocoding
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude
      );
      final placemark = placemarks.first;
      final locationName = '${placemark.name}, ${placemark.locality}';

      return LocationVerification(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        locationName: locationName,
        isInRange: isInRange,
        distanceFromClass: distance,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Location verification error: $e');
      throw Exception('Failed to verify location: $e');
    }
  }

  // Check for overlapping sessions
  Future<bool> hasOverlappingSessions(String studentId, String sessionId) async {
    try {
      final response = await _supabaseService.client
          .from('attendance')
          .select('*, attendance_sessions!inner(*)')
          .eq('student_id', studentId)
          .neq('session_id', sessionId)
          .eq('attendance_sessions.is_active', true);

      if (response.isEmpty) return false;

      final currentSession = await _supabaseService.client
          .from('attendance_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      final currentStart = DateTime.parse(currentSession['start_time']);
      final currentEnd = DateTime.parse(currentSession['end_time']);

      for (final record in response) {
        final session = record['attendance_sessions'];
        final sessionStart = DateTime.parse(session['start_time']);
        final sessionEnd = DateTime.parse(session['end_time']);

        if (!(currentEnd.isBefore(sessionStart) || currentStart.isAfter(sessionEnd))) {
          return true; // Overlap found
        }
      }

      return false;
    } catch (e) {
      print('Error checking overlapping sessions: $e');
      return false;
    }
  }

  // Mark attendance with all verifications
  Future<Map<String, dynamic>> markAttendance({
    required String sessionId,
    required String studentId,
    required double latitude,
    required double longitude,
    required String markMethod,
    required String markValue,
    required Map<String, dynamic> deviceInfo,
  }) async {
    try {
      print('DEBUG: Starting attendance marking');
      print('DEBUG: Session ID: $sessionId');
      print('DEBUG: Student ID: $studentId');
      print('DEBUG: Mark Method: $markMethod');
      print('DEBUG: Location: $latitude, $longitude');
      print('DEBUG: Device Info: $deviceInfo');

      // Get device time and server time for verification
      final deviceTime = DateTime.now().toUtc();
      final serverTime = await NTP.now();
      final timeDifference = serverTime.difference(deviceTime).abs();
      
      print('DEBUG: Device time: $deviceTime');
      print('DEBUG: Server time: $serverTime');
      print('DEBUG: Time difference: ${timeDifference.inSeconds} seconds');

      // Check if student has already marked attendance for this session
      final existingAttendance = await _supabase
          .from('attendance')
          .select()
          .eq('session_id', sessionId)
          .eq('student_id', studentId)
          .maybeSingle();

      if (existingAttendance != null) {
        print('DEBUG: Student already marked attendance');
        return {
          'success': false,
          'message': 'You have already marked attendance for this session'
        };
      }

      // Get session details
      print('DEBUG: Fetching session details');
      final session = await _supabase
          .from('attendance_sessions')
          .select()
          .eq('id', sessionId)
          .single();
      
      print('DEBUG: Session details: ${session.toString()}');

      // Calculate distance
      final distance = _calculateDistance(
        latitude,
        longitude,
        session['class_latitude'],
        session['class_longitude'],
      );
      
      print('DEBUG: Distance from class: $distance meters');

      // Verify QR code or backup key
      if (markMethod == 'QR_CODE' && markValue != session['qr_code']) {
        print('DEBUG: Invalid QR code');
        return {
          'success': false,
          'message': 'Invalid QR code'
        };
      } else if (markMethod == 'BACKUP_KEY' && markValue != session['backup_key']) {
        print('DEBUG: Invalid backup key');
        return {
          'success': false,
          'message': 'Invalid backup key'
        };
      }

      // Check if the time difference is too large (e.g., more than 2 minutes)
      final maxAllowedTimeDifference = Duration(minutes: 2);
      final hasTimeDiscrepancy = timeDifference > maxAllowedTimeDifference;

      print('DEBUG: Inserting attendance record');

      // Get location name using reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      final locationName = placemarks.isNotEmpty 
          ? '${placemarks.first.name}, ${placemarks.first.locality}'
          : 'Unknown Location';

      // Determine attendance status based on time and distance
      String status;
      final sessionEndTime = DateTime.parse(session['end_time']);
      final tenMinutesBeforeEnd = sessionEndTime.subtract(Duration(minutes: 10));
      
      if (distance > (session['radius_meters'] ?? 50.0)) {
        status = 'ABSENT';
      } else if (serverTime.isAfter(tenMinutesBeforeEnd)) {
        status = 'LATE';
      } else {
        status = 'PRESENT';
      }

      // Determine verification status
      String verificationStatus;
      if (deviceInfo['is_mock_location'] == true) {
        verificationStatus = 'MOCK_LOCATION_DETECTED';
      } else if (distance > (session['radius_meters'] ?? 50.0)) {
        verificationStatus = 'OUTSIDE_RADIUS';
      } else if (hasTimeDiscrepancy) {
        verificationStatus = 'TIME_MISMATCH';
      } else {
        verificationStatus = 'VERIFIED';
      }

      // Insert attendance record matching exact schema
      final attendanceData = {
        'session_id': sessionId,
        'student_id': studentId,
        'marked_at': serverTime.toIso8601String(),
        'mark_method': markMethod.toUpperCase(),
        'status': status,
        'location_name': locationName,
        'device_info': {
          'device_id': deviceInfo['device_id'],
          'device_model': deviceInfo['model'],
          'platform': deviceInfo['platform'],
          'os_version': deviceInfo['os_version'],
          'device_timestamp': deviceTime.toIso8601String(),  // Store device time in device_info JSONB
          'time_difference_seconds': timeDifference.inSeconds
        },
        'created_at': serverTime.toIso8601String(),
        'updated_at': serverTime.toIso8601String(),
        'student_latitude': latitude,
        'student_longitude': longitude,
        'distance_from_class': distance,
        'is_within_radius': distance <= (session['radius_meters'] ?? 50.0),
        'location_accuracy': deviceInfo['location_accuracy'],
        'device_id': deviceInfo['device_id'],
        'device_model': deviceInfo['model'],
        'platform': deviceInfo['platform'],
        'os_version': deviceInfo['os_version'],
        'is_mock_location': deviceInfo['is_mock_location'] ?? false,
        'network_info': deviceInfo['network_info'] ?? {},
        'app_version': deviceInfo['app_version'],
        'verification_status': verificationStatus,
        'verified_at': serverTime.toIso8601String()
      };
      
      print('DEBUG: Attendance data to insert: $attendanceData');
      
      await _supabase.from('attendance').insert(attendanceData);

      // Return appropriate message based on verification status
      String message = 'Attendance marked successfully';
      if (verificationStatus != 'VERIFIED') {
        message = switch (verificationStatus) {
          'TIME_MISMATCH' => 'Warning: Your device time appears to be incorrect',
          'OUTSIDE_RADIUS' => 'Warning: You are outside the class radius',
          'MOCK_LOCATION_DETECTED' => 'Warning: Mock location detected',
          _ => 'Attendance marked with verification issues'
        };
      }

      print('DEBUG: Attendance marked successfully');
      return {
        'success': true,
        'message': message,
        'verification_status': verificationStatus
      };
    } catch (e) {
      print('DEBUG: Error marking attendance: $e');
      return {
        'success': false,
        'message': e.toString()
      };
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Haversine formula implementation
    const R = 6371e3; // Earth's radius in meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // Distance in meters
  }

  // Verify QR code data with similar detailed validation
  Future<Map<String, dynamic>> verifyQRCode(String qrData, String studentId, {Map<String, dynamic>? location}) async {
    try {
      // Verify network connectivity
      final hasNetwork = await _deviceSecurity.checkNetworkConnectivity();
      if (!hasNetwork) {
        return {
          'success': false,
          'message': 'No network connection available. Please check your internet connection.',
          'status': 'NETWORK_ISSUE'
        };
      }

      print('DEBUG: Verifying QR code for student: $studentId'); // Debug log
      if (location != null) {
        print('DEBUG: Student location - ${location.toString()}');
      }

      // Get session data from QR code
      final sessionData = _decodeQRData(qrData);
      if (sessionData == null) {
        return {
          'success': false,
          'message': 'Invalid QR code format. This QR code is not valid for attendance.',
          'status': 'INVALID_FORMAT'
        };
      }

      print('DEBUG: Session data from QR: $sessionData'); // Debug log

      // Check if session exists and is active
      final sessionQuery = await _supabaseService.client
          .from('attendance_sessions')
          .select('*, units:unit_id(*)')
          .eq('id', sessionData['session_id'])
          .eq('is_active', true);

      print('DEBUG: Session query result: $sessionQuery'); // Debug log

      if (sessionQuery == null || sessionQuery.isEmpty) {
        return {
          'success': false,
          'message': 'This QR code is not valid. The session may have ended or been cancelled.',
          'status': 'INVALID_SESSION'
        };
      }

      final session = sessionQuery[0];

      // Check if location verification is required
      if (session['location_required'] == true && location != null) {
        // Verify student's location
        final double classLat = session['class_latitude'];
        final double classLong = session['class_longitude'];
        final int radiusMeters = session['radius_meters'] ?? 50;

        print('DEBUG: Class location - Lat: $classLat, Long: $classLong, Radius: $radiusMeters meters');
        print('DEBUG: Student location - Lat: ${location['latitude']}, Long: ${location['longitude']}');

        // Calculate distance between student and class location
        final double distance = Geolocator.distanceBetween(
          location['latitude'],
          location['longitude'],
          classLat,
          classLong
        );

        print('DEBUG: Distance from class: ${distance.toStringAsFixed(2)} meters');

        // Check for mock location
        if (location['isMocked'] == true) {
          return {
            'success': false,
            'message': 'Mock location detected. Please disable any location spoofing apps.',
            'status': 'MOCK_LOCATION_DETECTED',
            'sessionData': session
          };
        }

        // Check if student is within allowed radius
        if (distance > radiusMeters) {
          return {
            'success': false,
            'message': 'You are ${distance.toStringAsFixed(0)} meters away from class. Must be within $radiusMeters meters.',
            'status': 'OUTSIDE_RADIUS',
            'sessionData': session
          };
        }
      }

      // Check session timing using UTC
      final now = DateTime.now().toUtc();
      final startTime = DateTime.parse(session['start_time']);
      final endTime = DateTime.parse(session['end_time']);
      
      print('DEBUG: Time check - Now UTC: $now, Start: $startTime, End: $endTime'); // Debug log

      if (now.isBefore(startTime)) {
        return {
          'success': false,
          'message': 'Session has not started yet. Please wait until the scheduled time.',
          'status': 'TIME_MISMATCH',
          'sessionData': session
        };
      }

      if (now.isAfter(endTime)) {
        return {
          'success': false,
          'message': 'Session has ended. The attendance window is closed.',
          'status': 'TIME_MISMATCH',
          'sessionData': session
        };
      }

      // Check if student is enrolled in the unit
      final isEnrolled = await _checkStudentEnrollment(studentId, session['unit_id']);
      if (!isEnrolled) {
        return {
          'success': false,
          'message': 'You are not enrolled in this unit. Please contact your lecturer if this is incorrect.',
          'status': 'NOT_ENROLLED',
          'sessionData': session
        };
      }

      // Check if attendance already marked
      final existingAttendance = await _supabaseService.client
          .from('attendance_records')
          .select()
          .eq('session_id', session['id'])
          .eq('student_id', studentId)
          .limit(1)
          .single();

      if (existingAttendance != null) {
        return {
          'success': false,
          'message': 'Your attendance has already been marked for this session.',
          'status': 'ALREADY_MARKED',
          'sessionData': session
        };
      }

      return {
        'success': true,
        'sessionData': session,
        'status': 'PENDING_VERIFICATION'
      };
    } catch (e) {
      print('DEBUG: Error verifying QR code: $e'); // Debug log
      return {
        'success': false,
        'message': 'An error occurred while verifying the QR code. Please try again.',
        'status': 'ERROR'
      };
    }
  }

  // Verify backup key with similar detailed validation
  Future<Map<String, dynamic>> verifyBackupKey(String backupKey, String studentId, {Map<String, dynamic>? location}) async {
    try {
      // Verify network connectivity
      final hasNetwork = await _deviceSecurity.checkNetworkConnectivity();
      if (!hasNetwork) {
        return {
          'success': false,
          'message': 'No network connection available. Please check your internet connection.',
          'status': 'NETWORK_ISSUE'
        };
      }

      print('DEBUG: Verifying backup key: $backupKey for student: $studentId'); // Debug log
      if (location != null) {
        print('DEBUG: Student location - ${location.toString()}');
      }

      // Get session by backup key
      final sessionQuery = await _supabaseService.client
          .from('attendance_sessions')
          .select('*, units:unit_id(*)')
          .eq('backup_key', backupKey)
          .eq('is_active', true);

      print('DEBUG: Session query result: $sessionQuery'); // Debug log

      if (sessionQuery == null || sessionQuery.isEmpty) {
        return {
          'success': false,
          'message': 'This backup key is not valid. It may be incorrect or the session may have ended.',
          'status': 'INVALID_KEY'
        };
      }

      final session = sessionQuery[0];

      // Check if location verification is required
      if (session['location_required'] == true && location != null) {
        // Verify student's location
        final double classLat = session['class_latitude'];
        final double classLong = session['class_longitude'];
        final int radiusMeters = session['radius_meters'] ?? 50;

        print('DEBUG: Class location - Lat: $classLat, Long: $classLong, Radius: $radiusMeters meters');
        print('DEBUG: Student location - Lat: ${location['latitude']}, Long: ${location['longitude']}');

        // Calculate distance between student and class location
        final double distance = Geolocator.distanceBetween(
          location['latitude'],
          location['longitude'],
          classLat,
          classLong
        );

        print('DEBUG: Distance from class: ${distance.toStringAsFixed(2)} meters');

        // Check for mock location
        if (location['isMocked'] == true) {
          return {
            'success': false,
            'message': 'Mock location detected. Please disable any location spoofing apps.',
            'status': 'MOCK_LOCATION_DETECTED',
            'sessionData': session
          };
        }

        // Check if student is within allowed radius
        if (distance > radiusMeters) {
          return {
            'success': false,
            'message': 'You are ${distance.toStringAsFixed(0)} meters away from class. Must be within $radiusMeters meters.',
            'status': 'OUTSIDE_RADIUS',
            'sessionData': session
          };
        }
      }

      // Check session timing using UTC
      final now = DateTime.now().toUtc();
      final startTime = DateTime.parse(session['start_time']);
      final endTime = DateTime.parse(session['end_time']);

      print('DEBUG: Time check - Now UTC: $now, Start: $startTime, End: $endTime'); // Debug log
      
      if (now.isBefore(startTime)) {
        return {
          'success': false,
          'message': 'Session has not started yet. Please wait until the scheduled time.',
          'status': 'TIME_MISMATCH',
          'sessionData': session
        };
      }

      if (now.isAfter(endTime)) {
        return {
          'success': false,
          'message': 'Session has ended. The attendance window is closed.',
          'status': 'TIME_MISMATCH',
          'sessionData': session
        };
      }

      // Check if student is enrolled in the unit
      final isEnrolled = await _checkStudentEnrollment(studentId, session['unit_id']);
      if (!isEnrolled) {
        return {
          'success': false,
          'message': 'You are not enrolled in this unit. Please contact your lecturer if this is incorrect.',
          'status': 'NOT_ENROLLED',
          'sessionData': session
        };
      }

      // Check if attendance already marked
      final existingAttendance = await _supabaseService.client
          .from('attendance_records')
          .select()
          .eq('session_id', session['id'])
          .eq('student_id', studentId)
          .limit(1)
          .single();

      if (existingAttendance != null) {
        return {
          'success': false,
          'message': 'Your attendance has already been marked for this session.',
          'status': 'ALREADY_MARKED',
          'sessionData': session
        };
      }

      return {
        'success': true,
        'sessionData': session,
        'status': 'PENDING_VERIFICATION'
      };
    } catch (e) {
      print('DEBUG: Error verifying backup key: $e'); // Debug log
      return {
        'success': false,
        'message': 'An error occurred while verifying the backup key. Please try again.',
        'status': 'ERROR'
      };
    }
  }

  // Helper function to check student enrollment
  Future<bool> _checkStudentEnrollment(String studentId, String unitId) async {
    try {
      // Check in student_registered_units first
      final registeredUnitsQuery = await _supabaseService.client
          .from('student_registered_units')
          .select()
          .eq('student_id', studentId)
          .eq('unit_id', unitId)
          .limit(1);
      
      if (registeredUnitsQuery != null && registeredUnitsQuery.isNotEmpty) {
        return true;
      }

      // If not found, check in student_units
      final studentUnitsQuery = await _supabaseService.client
          .from('student_units')
          .select()
          .eq('student_id', studentId)
          .eq('unit_id', unitId)
          .limit(1);
      
      return studentUnitsQuery != null && studentUnitsQuery.isNotEmpty;
    } catch (e) {
      print('DEBUG: Error checking student enrollment: $e');
      return false;
    }
  }

  Map<String, dynamic>? _decodeQRData(String qrData) {
    try {
      // First try JSON format
      try {
        return json.decode(qrData) as Map<String, dynamic>;
      } catch (e) {
        // If JSON fails, try URL-encoded format
        return Map<String, dynamic>.from(
          Uri.decodeFull(qrData).split('&').fold({}, (map, item) {
            final parts = item.split('=');
            if (parts.length == 2) map[parts[0]] = parts[1];
            return map;
          })
        );
      }
    } catch (e) {
      print('Error decoding QR data: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSessionByKey(String sessionKey) async {
    try {
      final result = await _supabaseService.client
          .from('attendance_sessions')
          .select()
          .eq('session_key', sessionKey)
          .single();
      return result;
    } catch (e) {
      print('Error getting session by key: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSessionByBackupKey(String backupKey) async {
    try {
      final response = await _supabase
          .from('attendance_sessions')
          .select('''
            *,
            units:unit_id (
              id,
              code,
              name
            )
          ''')
          .eq('backup_key', backupKey)
          .single();

      return response;
    } catch (e) {
      print('Error getting session by backup key: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getActiveSession(String unitId) async {
    try {
      final response = await _supabase
          .from('attendance_sessions')
        .select('''
          *,
          units:unit_id (
            id,
            code,
            name
          )
        ''')
          .eq('unit_id', unitId)
        .eq('is_active', true)
          .single();
      
      return response;
    } catch (e) {
      print('Error getting active session: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> refreshSessionStatus(String sessionId) async {
    try {
      // Force update the session to recalculate its active status
      final response = await _supabaseService.client
          .rpc('update_session_status_manual', 
          params: {'session_id': sessionId});
      
      // Fetch the updated session
      final sessionResponse = await _supabaseService.client
          .from('attendance_sessions')
          .select()
          .eq('id', sessionId)
          .single();
          
      return {
        'success': true,
        'session': sessionResponse,
        'is_active': sessionResponse['is_active']
      };
    } catch (e) {
      print('Error refreshing session status: $e');
      return {
        'success': false,
        'message': 'Failed to refresh session status'
      };
    }
  }

  Future<List<Map<String, dynamic>>> getUnitAttendance(String unitId) async {
    try {
      final response = await _supabase
          .from('attendance')
          .select('''
            *,
            students (
              id,
              users (
                name,
                email
              )
            ),
            units (
              code,
              name,
              department,
              course,
              year,
              semester
            )
          ''')
          .eq('unit_id', unitId as Object);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching attendance: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> calculateAttendanceStats(String unitId) async {
    try {
      // First get all enrolled students for this unit
      final enrolledStudentsResponse = await _supabase
          .from('student_units')
          .select('''
            student_id,
            students!inner (
              id,
              users!inner (
                id,
                name,
                email,
                reg_number
              )
            )
          ''')
          .eq('unit_id', unitId);

      if (enrolledStudentsResponse == null) {
        return _getEmptyStatsResponse();
      }

      // Get all sessions for this unit
      final sessionsResponse = await _supabase
          .from('attendance_sessions')
          .select('id, start_time, end_time, duration_hours')
          .eq('unit_id', unitId);
      
      List<Map<String, dynamic>> studentDetails = [];
      int totalStudents = enrolledStudentsResponse.length;
      int eligibleCount = 0;
      int atRiskCount = 0;

      // If there are no sessions yet, just return enrolled students with 0 attendance
      if (sessionsResponse == null || sessionsResponse.isEmpty) {
        for (var enrollment in enrolledStudentsResponse) {
          final student = enrollment['students']['users'];
          studentDetails.add({
            'name': student['name'] ?? 'Unknown',
            'email': student['email'] ?? '',
            'reg_number': student['reg_number'] ?? '',
            'total_hours_attended': 0.0,
            'completion_rate': 0.0,
            'hours_needed_for_eligibility': requiredSemesterHours,
            'is_eligible': false,
            'weekly_breakdown': {},
            'monthly_breakdown': {},
            'expected_hours': {
              'per_session': hoursPerSession,
              'per_week': hoursPerWeek,
              'per_month': hoursPerMonth,
              'total_semester': totalSemesterHours,
              'required_for_eligibility': requiredSemesterHours
            }
          });
        }

        return {
          'total_students': totalStudents,
          'eligible_count': 0,
          'at_risk_count': totalStudents,
          'student_details': studentDetails,
          'attendance_structure': {
            'hours_per_session': hoursPerSession,
            'sessions_per_week': sessionsPerWeek,
            'hours_per_week': hoursPerWeek,
            'weeks_per_month': weeksPerMonth,
            'months_per_semester': monthsPerSemester,
            'total_semester_hours': totalSemesterHours,
            'required_semester_hours': requiredSemesterHours,
            'eligibility_threshold': '${(eligibilityThreshold * 100).round()}%'
          }
        };
      }

      // Get all attendance records for these sessions with proper joins
      final response = await _supabase
          .from('attendance')
          .select('''
            id,
            status,
            marked_at,
            verification_status,
            student_id,
            session_id,
            students!inner (
              id,
              users!inner (
                id,
                name,
                email,
                reg_number
              )
            ),
            attendance_sessions!inner (
              id,
              start_time,
              end_time,
              duration_hours
            )
          ''')
          .filter('session_id', 'in', sessionsResponse.map((s) => s['id']).toList())
          .order('marked_at', ascending: true);

      // Create a map of student IDs to their attendance records
      Map<String, List<Map<String, dynamic>>> studentAttendance = {};
      
      // Initialize with all enrolled students
      for (var enrollment in enrolledStudentsResponse) {
        final studentId = enrollment['student_id'] as String;
        studentAttendance[studentId] = [];
      }

      // Add attendance records if they exist
      if (response != null) {
        for (var record in response) {
          final studentId = record['student_id'] as String? ?? '';
          if (studentId.isEmpty) continue;
          
          if (!studentAttendance.containsKey(studentId)) {
            studentAttendance[studentId] = [];
          }
          studentAttendance[studentId]!.add(record);
        }
      }

      // Process each student's attendance
      studentAttendance.forEach((studentId, records) {
        double totalHours = 0.0;
        Map<String, double> weeklyHours = {};
        Map<String, double> monthlyHours = {};
        
        // Only count verified present attendance
        for (var record in records.where((r) => 
          (r['status'] as String?)?.toUpperCase() == 'PRESENT' &&
          (r['verification_status'] as String?)?.toUpperCase() == 'VERIFIED'
        )) {
          try {
            final DateTime markedAt = DateTime.parse(record['marked_at'] as String? ?? DateTime.now().toIso8601String());
            final double sessionHours = (record['attendance_sessions']?['duration_hours'] as num?)?.toDouble() ?? 2.0;
            
            // Weekly tracking
            final String weekKey = '${markedAt.year}-${_getWeekNumber(markedAt)}';
            weeklyHours[weekKey] = (weeklyHours[weekKey] ?? 0) + sessionHours;
            
            // Monthly tracking
            final String monthKey = '${markedAt.year}-${markedAt.month}';
            monthlyHours[monthKey] = (monthlyHours[monthKey] ?? 0) + sessionHours;
            
            totalHours += sessionHours;
          } catch (e) {
            print('Error processing attendance record: $e');
            continue;
          }
        }

        // Get student info from enrolled students data
        final enrollment = enrolledStudentsResponse.firstWhere(
          (e) => e['student_id'] == studentId,
          orElse: () => {'students': {'users': {}}}
        );
        final userInfo = enrollment['students']['users'];

        // Calculate completion percentage with null safety
        double completionRate = 0.0;
        if (totalSemesterHours > 0) {
          completionRate = (totalHours / totalSemesterHours) * 100;
          completionRate = completionRate.isNaN ? 0.0 : completionRate.clamp(0.0, 100.0);
        }
        
        // Determine eligibility based on achieving 70% of total semester hours
        bool isEligible = totalHours >= requiredSemesterHours;

        // Update counters
        if (isEligible) eligibleCount++;
        else atRiskCount++;
        
        // Calculate hours needed for eligibility
        double hoursNeededForEligibility = isEligible ? 0 : (requiredSemesterHours - totalHours).clamp(0.0, double.infinity);
        
        studentDetails.add({
          'name': userInfo['name'] ?? 'Unknown',
          'email': userInfo['email'] ?? '',
          'reg_number': userInfo['reg_number'] ?? '',
          'total_hours_attended': totalHours,
          'completion_rate': completionRate,
          'hours_needed_for_eligibility': hoursNeededForEligibility,
          'is_eligible': isEligible,
          'weekly_breakdown': weeklyHours,
          'monthly_breakdown': monthlyHours,
          'expected_hours': {
            'per_session': hoursPerSession,
            'per_week': hoursPerWeek,
            'per_month': hoursPerMonth,
            'total_semester': totalSemesterHours,
            'required_for_eligibility': requiredSemesterHours
          }
        });
      });

      // Sort by completion rate descending
      studentDetails.sort((a, b) => (b['completion_rate'] as double).compareTo(a['completion_rate'] as double));

      return {
        'total_students': totalStudents,
        'eligible_count': eligibleCount,
        'at_risk_count': atRiskCount,
        'student_details': studentDetails,
        'attendance_structure': {
          'hours_per_session': hoursPerSession,
          'sessions_per_week': sessionsPerWeek,
          'hours_per_week': hoursPerWeek,
          'weeks_per_month': weeksPerMonth,
          'months_per_semester': monthsPerSemester,
          'total_semester_hours': totalSemesterHours,
          'required_semester_hours': requiredSemesterHours,
          'eligibility_threshold': '${(eligibilityThreshold * 100).round()}%'
        }
      };
    } catch (e) {
      print('Error calculating attendance stats: $e');
      return _getEmptyStatsResponse();
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays;
    return ((dayOfYear + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  Map<String, dynamic> _getEmptyStatsResponse() {
    return {
      'total_students': 0,
      'eligible_count': 0,
      'at_risk_count': 0,
      'student_details': [],
      'attendance_structure': {
        'hours_per_session': hoursPerSession,
        'sessions_per_week': sessionsPerWeek,
        'hours_per_week': hoursPerWeek,
        'weeks_per_month': weeksPerMonth,
        'months_per_semester': monthsPerSemester,
        'total_semester_hours': totalSemesterHours,
        'required_semester_hours': requiredSemesterHours,
        'eligibility_threshold': '${(eligibilityThreshold * 100).round()}%'
      }
    };
  }
} 
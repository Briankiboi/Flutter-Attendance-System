import 'package:supabase_flutter/supabase_flutter.dart';

// Attendance Session Schema
class AttendanceSession {
  final String id;
  final String unitCode;
  final String unitName;
  final String department;
  final String year;
  final String semester;
  final String startTime;
  final String endTime;
  final Duration duration;
  final bool isActive;
  final String qrCodeData;
  final String backupKey;
  final Map<String, dynamic> timeStatus;
  final String lecturerId;
  final DateTime createdAt;
  final Map<String, dynamic> sessionData;
  final String location;
  final Map<String, double> coordinates;

  AttendanceSession({
    required this.id,
    required this.unitCode,
    required this.unitName,
    required this.department,
    required this.year,
    required this.semester,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.isActive,
    required this.qrCodeData,
    required this.backupKey,
    required this.timeStatus,
    required this.lecturerId,
    required this.createdAt,
    required this.sessionData,
    required this.location,
    required this.coordinates,
  });
}

// Attendance Record Schema
class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final String studentName;
  final String department;
  final String course;
  final String year;
  final String semester;
  final DateTime serverTimestamp;
  final DateTime deviceTimestamp;
  final String markMethod; // 'QR_CODE' or 'BACKUP_KEY'
  final String status; // 'PRESENT', 'LATE', 'ABSENT'
  final Map<String, dynamic> location;
  final bool isTimeSynced;
  final Map<String, dynamic> verificationData;
  final DateTime createdAt;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.department,
    required this.course,
    required this.year,
    required this.semester,
    required this.serverTimestamp,
    required this.deviceTimestamp,
    required this.markMethod,
    required this.status,
    required this.location,
    required this.isTimeSynced,
    required this.verificationData,
    required this.createdAt,
  });

  // Convert to JSON for database storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'student_id': studentId,
    'student_name': studentName,
    'department': department,
    'course': course,
    'year': year,
    'semester': semester,
    'server_timestamp': serverTimestamp.toIso8601String(),
    'device_timestamp': deviceTimestamp.toIso8601String(),
    'mark_method': markMethod,
    'status': status,
    'location': location,
    'is_time_synced': isTimeSynced,
    'verification_data': verificationData,
    'created_at': createdAt.toIso8601String(),
  };

  // Create from JSON from database
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
    id: json['id'],
    sessionId: json['session_id'],
    studentId: json['student_id'],
    studentName: json['student_name'],
    department: json['department'],
    course: json['course'],
    year: json['year'],
    semester: json['semester'],
    serverTimestamp: DateTime.parse(json['server_timestamp']),
    deviceTimestamp: DateTime.parse(json['device_timestamp']),
    markMethod: json['mark_method'],
    status: json['status'],
    location: json['location'],
    isTimeSynced: json['is_time_synced'],
    verificationData: json['verification_data'],
    createdAt: DateTime.parse(json['created_at']),
  );
}

// Time Verification Data
class TimeVerification {
  final DateTime serverTime;
  final DateTime deviceTime;
  final DateTime gpsTime;
  final bool isTimeValid;
  final int timeDifferenceMinutes;
  final String validationMessage;

  TimeVerification({
    required this.serverTime,
    required this.deviceTime,
    required this.gpsTime,
    required this.isTimeValid,
    required this.timeDifferenceMinutes,
    required this.validationMessage,
  });

  Map<String, dynamic> toJson() => {
    'server_time': serverTime.toIso8601String(),
    'device_time': deviceTime.toIso8601String(),
    'gps_time': gpsTime.toIso8601String(),
    'is_time_valid': isTimeValid,
    'time_difference_minutes': timeDifferenceMinutes,
    'validation_message': validationMessage,
  };
}

// Location Verification Data
class LocationVerification {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String locationName;
  final bool isInRange;
  final double distanceFromClass;
  final DateTime timestamp;

  LocationVerification({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.locationName,
    required this.isInRange,
    required this.distanceFromClass,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'location_name': locationName,
    'is_in_range': isInRange,
    'distance_from_class': distanceFromClass,
    'timestamp': timestamp.toIso8601String(),
  };
} 
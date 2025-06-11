import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

class SupabaseWebService {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _currentUser;

  // Singleton pattern
  static final SupabaseWebService _instance = SupabaseWebService._internal();
  factory SupabaseWebService() => _instance;
  SupabaseWebService._internal();

  // Initialize Supabase for web
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://vaaqnexxyzzmjwquhpry.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhYXFuZXh4eXp6bWp3cXVocHJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY0MjYyMjgsImV4cCI6MjA2MjAwMjIyOH0.SVPotafYY4VtdxQvIrDITp4VkInn1TmbP22CY39G2dA',
      debug: true
    );
  }

  // Authentication Methods
  Future<Map<String, dynamic>> login(String email, String password, bool isStudent) async {
    try {
      final userResponse = await _supabase
          .from('users')
          .select(isStudent ? '*, students(*)' : '*, lecturers(*)')
          .eq('email', email)
          .eq('user_type', isStudent ? 'student' : 'lecturer')
          .maybeSingle();

      if (userResponse == null) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      if (userResponse['password'] != password) {
        return {'success': false, 'message': 'Invalid credentials'};
      }

      // Store current user
      _currentUser = {
        'id': userResponse['id'],
        'email': userResponse['email'],
        'name': userResponse['name'],
        'user_type': userResponse['user_type'],
        ...isStudent ? userResponse['students'][0] : userResponse['lecturers'][0],
      };

      return {'success': true, 'user': _currentUser};
    } catch (e) {
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  // Student Methods
  Future<Map<String, dynamic>> getStudentAttendance(String studentId) async {
    try {
      final response = await _supabase
          .from('attendance')
          .select('''
            *,
            session:attendance_sessions(
              *,
              lecturer:lecturers(name),
              unit:units(code, name)
            )
          ''')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch attendance: ${e.toString()}',
      };
    }
  }

  // Lecturer Methods
  Future<Map<String, dynamic>> getLecturerSessions(String lecturerId) async {
    try {
      final response = await _supabase
          .from('attendance_sessions')
          .select('''
            *,
            unit:units(code, name),
            attendance:attendance(
              student:students(
                user:users(name, email)
              )
            )
          ''')
          .eq('lecturer_id', lecturerId)
          .order('created_at', ascending: false);

      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch sessions: ${e.toString()}',
      };
    }
  }

  // QR Code Methods
  Future<String> uploadQRCode(Uint8List imageBytes, String fileName) async {
    try {
      await _supabase
          .storage
          .from('qr_codes')
          .uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      return _supabase
          .storage
          .from('qr_codes')
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Failed to upload QR code: ${e.toString()}');
    }
  }

  // Session Management
  Future<Map<String, dynamic>> createAttendanceSession({
    required String lecturerId,
    required String unitId,
    required String qrCodeUrl,
    required Map<String, dynamic> qrCodeData,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final response = await _supabase
          .from('attendance_sessions')
          .insert({
            'lecturer_id': lecturerId,
            'unit_id': unitId,
            'qr_code_url': qrCodeUrl,
            'qr_code_data': qrCodeData,
            'start_time': startTime.toIso8601String(),
            'end_time': endTime.toIso8601String(),
            'is_active': true,
          })
          .select()
          .single();

      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create session: ${e.toString()}',
      };
    }
  }

  // User Preferences
  Future<bool> getDarkModeEnabled() async {
    if (_currentUser == null) return false;
    
    try {
      final response = await _supabase
          .from('user_preferences')
          .select('dark_mode_enabled')
          .eq('user_id', _currentUser!['id'])
          .maybeSingle();
      
      return response?['dark_mode_enabled'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setDarkModeEnabled(bool value) async {
    if (_currentUser == null) return;
    
    await _supabase
        .from('user_preferences')
        .upsert({
          'user_id': _currentUser!['id'],
          'dark_mode_enabled': value,
        });
  }

  // Helper Methods
  Map<String, dynamic>? get currentUser => _currentUser;
  
  void logout() {
    _currentUser = null;
  }
} 
import 'dart:convert';
import 'dart:io';
import 'dart:async';  // Add this import for TimeoutException
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:qr_attendance/config/env_config.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';  // Add this import for Uint8List
import 'package:intl/intl.dart';

// Development mode flag
const bool DEV_MODE = true;

class SupabaseService {
  final _supabase = Supabase.instance.client;
  
  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Configure client options
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      debug: true,
    );
  }

  // Helper method to handle nullable parameters in queries
  dynamic toQueryParam(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  // Get the Supabase client
  SupabaseClient get client => Supabase.instance.client;
  
  // User Authentication Methods
  
  // Student login
  Future<Map<String, dynamic>> studentLogin(String email, String password) async {
    try {
      // Get user from users table - use limit(1) instead of single() to handle duplicate emails
      final usersResponse = await client
          .from('users')
          .select('*, students(*)')
          .eq('email', email)
          .eq('user_type', 'student')
          .limit(1);
      
      // Check if any users were found
      if (usersResponse.isEmpty) {
        return {'success': false, 'message': 'Invalid credentials'};
      }
      
      // Use the first matching user
      final userResponse = usersResponse[0];
      
      // If password doesn't match
      if (userResponse['password'] != password) {
        return {'success': false, 'message': 'Invalid credentials'};
      }
      
      // Get student ID
      final studentId = userResponse['students'][0]['id'];
      
      // Update last login time and location placeholder
      await client
          .from('students')
          .update({
            'last_login': DateTime.now().toIso8601String(),
            'current_location': 'Fetching location...', // Initial placeholder
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', studentId);
      
      // Combine user data
      Map<String, dynamic> userData = {
        'id': userResponse['id'],
        'email': userResponse['email'],
        'name': userResponse['name'],
        'password': userResponse['password'],
        'department': userResponse['students'][0]['department'],
        'course': userResponse['students'][0]['course'],
        'year': userResponse['students'][0]['year'],
        'semester': userResponse['students'][0]['semester'],
        'profile_image_path': userResponse['students'][0]['profile_image_path'],
        'student_id': studentId,
        'current_location': 'Fetching location...' // Add location to user data
      };
      
      // Set current session user
      await updateCurrentUser(userData);
      
      return {'success': true, 'userData': userData, 'requiresLocation': true};
    } catch (e) {
      print('Error during student login: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Lecturer login
  Future<Map<String, dynamic>> lecturerLogin(String email, String password) async {
    try {
      print('Attempting lecturer login for email: $email');
      
      // Validate email domain
      if (!email.toLowerCase().endsWith('@tharaka.ac.ke')) {
        return {'success': false, 'message': 'Please use your Tharaka University email (@tharaka.ac.ke)'};
      }

      // Get lecturer details
      final lecturerResponse = await client
          .from('lecturers')
          .select()
          .eq('email', email)
          .single();

      print('Found lecturer record: $lecturerResponse');
      
      // Combine user data
      Map<String, dynamic> userData = {
        'id': lecturerResponse['user_id'],
        'email': email,
        'name': lecturerResponse['name'],
        'department': lecturerResponse['department'],
        'occupation': lecturerResponse['occupation'],
        'employmentType': lecturerResponse['employment_type'],
        'gender': lecturerResponse['gender'],
        'profile_image_path': lecturerResponse['profile_image_path'],
        'lecturer_id': lecturerResponse['id'],
        'user_type': 'lecturer'
      };
      
      // Set current session user
      _currentUser = userData;
      
      print('Login successful for lecturer: ${userData['name']}');
      
      return {
        'success': true,
        'message': 'Login successful',
        'userData': userData
      };
    } catch (e) {
      print('Error during lecturer login: $e');
      return {'success': false, 'message': 'An error occurred during login'};
    }
  }
  
  // Student signup
  Future<Map<String, dynamic>> studentSignup(Map<String, dynamic> userData) async {
    try {
      // Check if email already exists
      final existingUser = await client
          .from('users')
          .select()
          .eq('email', userData['email'])
          .maybeSingle();
      
      if (existingUser != null) {
        return {'success': false, 'message': 'Email already registered'};
      }
      
      // Create user record
      final newUserResponse = await client
          .from('users')
          .insert({
            'email': userData['email'],
            'name': userData['name'],
            'password': userData['password'],
            'user_type': 'student',
          })
          .select()
          .limit(1);
      
      // Check if record was created
      if (newUserResponse == null || newUserResponse.isEmpty) {
        return {'success': false, 'message': 'Failed to create user record'};
      }
      
      final newUser = newUserResponse[0];
      
      // Get department and course IDs
      final departmentResponse = await client
          .from('departments')
          .select('id')
          .eq('name', userData['department'])
          .single();
          
      final courseResponse = await client
          .from('courses')
          .select('id')
          .eq('name', userData['course'])
          .eq('department_id', departmentResponse['id'])
          .single();
      
      // Create student record with foreign key references
      final newStudentResponse = await client
          .from('students')
          .insert({
            'user_id': newUser['id'],
            'department_id': departmentResponse['id'],
            'course_id': courseResponse['id'],
            'year': userData['year'],
            'semester': userData['semester'],
            'profile_image_path': null, // Explicitly set to null for new users
          })
          .select()
          .limit(1);
      
      // Check if record was created
      if (newStudentResponse == null || newStudentResponse.isEmpty) {
        return {'success': false, 'message': 'Failed to create student record'};
      }
      
      final newStudent = newStudentResponse[0];
      
      // Create default preferences
      await client
          .from('user_preferences')
          .insert({
            'user_id': newUser['id'],
            'dark_mode_enabled': false,
            'language': 'en',
            'has_completed_onboarding': false,
          });
      
      return {
        'success': true,
        'message': 'Account created successfully',
        'data': {
          'user': newUser,
          'student': newStudent,
        }
      };
    } catch (e) {
      print('Error during student signup: $e');
      return {'success': false, 'message': 'An error occurred during signup: $e'};
    }
  }
  
  // Lecturer signup with email verification
  Future<Map<String, dynamic>> lecturerSignup(Map<String, dynamic> userData) async {
    try {
      // Check if email already exists
      final existingUser = await client
          .from('users')
          .select()
          .eq('email', userData['email'])
          .maybeSingle();
      
      if (existingUser != null) {
        return {'success': false, 'message': 'Email already registered'};
      }
      
      // Create user record first
      final newUserResponse = await client
          .from('users')
          .insert({
            'email': userData['email'],
            'name': userData['name'],
            'password': userData['password'],
            'user_type': 'lecturer',
          })
          .select()
          .limit(1);
      
      // Check if record was created
      if (newUserResponse.isEmpty) {
        return {'success': false, 'message': 'Failed to create user record'};
      }
      
      final newUser = newUserResponse[0];
      
      // Create lecturer record
      final newLecturerResponse = await client
          .from('lecturers')
          .insert({
            'user_id': newUser['id'],
            'name': userData['name'],
            'email': userData['email'],
            'department': userData['department'],
            'occupation': userData['occupation'] ?? 'Lecturer',
            'employment_type': userData['employmentType'] ?? 'Full Time',
            'gender': userData['gender'] ?? 'Not Specified',
            'profile_image_path': null,
          })
          .select()
          .limit(1);
      
      // Check if record was created
      if (newLecturerResponse.isEmpty) {
        // Cleanup user record since lecturer creation failed
        await client.from('users').delete().eq('id', newUser['id']);
        return {'success': false, 'message': 'Failed to create lecturer record'};
      }
      
      final newLecturer = newLecturerResponse[0];
      
      // Create default preferences
      await client
          .from('user_preferences')
          .insert({
            'user_id': newUser['id'],
            'dark_mode_enabled': false,
            'has_completed_onboarding': false,
            'language': 'en',
          });
      
      // Combine data for return
      Map<String, dynamic> createdUserData = {
        'id': newUser['id'],
        'email': newUser['email'],
        'name': newUser['name'],
        'department': userData['department'],
        'occupation': userData['occupation'],
        'employmentType': userData['employmentType'],
        'gender': userData['gender'],
        'lecturer_id': newLecturer['id'],
        'profile_image_path': null,
      };
      
      // Set as current user immediately to ensure consistent state
      await updateCurrentUser(createdUserData);
      
      return {'success': true, 'userData': createdUserData};
    } catch (e) {
      print('Error during lecturer signup: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Logout
  Future<void> logout() async {
    await client.auth.signOut();
    // Clear any stored current user data in memory if needed
    _currentUser = null;
  }
  
  // User Preferences Methods
  
  // Helper to set current user by email (used in email verification screen)
  Future<bool> setCurrentUser(String email, String name, {bool isLecturer = false}) async {
    try {
      print('Setting current user for email: $email, isLecturer: $isLecturer');
      
      // Development mode handling
      if (DEV_MODE) {
        // Check if user exists in database
        final userResponse = await client
            .from('users')
            .select(isLecturer ? '*, lecturers(*)' : '*, students(*)')
            .eq('email', email)
            .maybeSingle();
            
        Map<String, dynamic> userData;
        
        if (userResponse != null) {
          // Use actual data from database
          userData = {
            'id': userResponse['id'],
            'email': email,
            'name': name,
            'password': userResponse['password'],
            'user_type': isLecturer ? 'lecturer' : 'student',
          };
          
          if (isLecturer && userResponse['lecturers'] != null) {
            userData.addAll({
              'department': userResponse['lecturers'][0]['department'],
              'occupation': userResponse['lecturers'][0]['occupation'],
              'employment_type': userResponse['lecturers'][0]['employment_type'],
              'gender': userResponse['lecturers'][0]['gender'],
              'lecturer_id': userResponse['lecturers'][0]['id'],
              'profile_image_path': userResponse['lecturers'][0]['profile_image_path'],
            });
          } else if (!isLecturer && userResponse['students'] != null) {
            userData.addAll({
              'department': userResponse['students'][0]['department'],
              'course': userResponse['students'][0]['course'],
              'year': userResponse['students'][0]['year'],
              'semester': userResponse['students'][0]['semester'],
              'student_id': userResponse['students'][0]['id'],
              'profile_image_path': userResponse['students'][0]['profile_image_path'],
            });
          }
        } else {
          // Create new user data for development
          userData = {
            'id': isLecturer ? 'dev-lecturer-id' : 'dev-student-id',
            'email': email,
            'name': name,
            'password': 'password',
            'user_type': isLecturer ? 'lecturer' : 'student',
            'profile_image_path': null,
            'dark_mode_enabled': false,
            'has_completed_onboarding': true,
            'language': 'en',
          };
          
          if (isLecturer) {
            userData.addAll({
              'department': 'Development',
              'occupation': 'Lecturer',
              'employment_type': 'Full Time',
              'gender': 'Not Specified',
              'lecturer_id': 'dev-lecturer',
            });
          } else {
            userData.addAll({
              'department': 'Development',
              'course': 'Test Course',
              'year': '1',
              'semester': '1',
              'student_id': 'dev-student',
            });
          }
        }
        
        // Set current session user
        await _setCurrentUser(userData);
        return true;
      }
      
      // Production mode - Find the user in the database
      final userResponse = await client
          .from('users')
          .select(isLecturer ? '*, lecturers(*)' : '*, students(*)')
          .eq('email', email)
          .maybeSingle();
      
      if (userResponse == null) {
        print('No user found with email: $email');
        return false;
      }
      
      // Combine user data based on type
      Map<String, dynamic> userData = {
        'id': userResponse['id'],
        'email': userResponse['email'],
        'name': userResponse['name'],
        'password': userResponse['password'],
        'user_type': isLecturer ? 'lecturer' : 'student',
      };
      
      if (isLecturer && userResponse['lecturers'] != null) {
        userData.addAll({
          'department': userResponse['lecturers'][0]['department'],
          'occupation': userResponse['lecturers'][0]['occupation'],
          'employment_type': userResponse['lecturers'][0]['employment_type'],
          'gender': userResponse['lecturers'][0]['gender'],
          'lecturer_id': userResponse['lecturers'][0]['id'],
          'profile_image_path': userResponse['lecturers'][0]['profile_image_path'],
        });
      } else if (!isLecturer && userResponse['students'] != null) {
        userData.addAll({
          'department': userResponse['students'][0]['department'],
          'course': userResponse['students'][0]['course'],
          'year': userResponse['students'][0]['year'],
          'semester': userResponse['students'][0]['semester'],
          'student_id': userResponse['students'][0]['id'],
          'profile_image_path': userResponse['students'][0]['profile_image_path'],
        });
      }
      
      // Set current session user
      await _setCurrentUser(userData);
      return true;
      
    } catch (e) {
      print('Error setting current user: $e');
      return false;
    }
  }
  
  // Helper to set current user in memory (replaces shared prefs current user keys)
  Future<void> _setCurrentUser(Map<String, dynamic> userData) async {
    // You could use a static variable here or provider state management
    // For now, just a placeholder for how to handle the current user
    _currentUser = userData;
  }
  
  // In-memory current user (for replacing SharedPreferences current_user keys)
  static Map<String, dynamic>? _currentUser;
  
  // Get current user data
  Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }
  
  // Update the current user cache with provided data
  void updateCurrentUserCache(Map<String, dynamic> userData) {
    if (_currentUser != null) {
      // Update only provided fields in the current user cache
      userData.forEach((key, value) {
        if (value != null) {
          _currentUser![key] = value;
        }
      });
      print('Updated in-memory user cache with fields: ${userData.keys.join(', ')}');
      print('Updated name in cache: ${_currentUser!['name']}');
    } else {
      print('WARNING: Cannot update current user cache - no user is logged in');
    }
  }
  
  // Get user data including session and notification info
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      if (_currentUser == null) return null;
      
      final userData = Map<String, dynamic>.from(_currentUser!);
      
      // For development/test accounts, just return the current user data
      // This prevents unnecessary database queries that would fail
      if (userData['id'] == 'dev-student-id' || userData['id'].toString().startsWith('dev-')) {
        print('Development account: returning in-memory user data');
        return userData;
      }
      
      // Get active sessions data
      final sessionResponse = await client
          .from('attendance_sessions')
          .select()
          .order('created_at', ascending: false);
          
      List<String> activeSessions = [];
      Map<String, dynamic> sessionData = {};
      
      // Process sessions
      for (var session in sessionResponse) {
        activeSessions.add(session['id']);
        sessionData['session_${session['id']}'] = json.encode(session);
      }
          
      userData['active_sessions'] = activeSessions;
      
      // Merge session data into user data
      userData.addAll(sessionData);
      
      // Check attendance records for this user
      if (userData['student_id'] != null) {
        final attendanceResponse = await client
            .from('attendance')
            .select('session_id, marked_at')
            .eq('student_id', userData['student_id']);
            
        // Create a map of attended sessions
        for (var record in attendanceResponse) {
          final sessionId = record['session_id'];
          final email = userData['email'];
          
          userData['attended_session_${email}_$sessionId'] = true;
        }
        
        // Also create a map of attendance timestamps for recency checking
        Map<String, String> lastAttendanceTimes = {};
        
        if (attendanceResponse.isNotEmpty) {
          // Get most recent attendance
          attendanceResponse.sort((a, b) => 
              DateTime.parse(b['marked_at']).compareTo(DateTime.parse(a['marked_at'])));
              
          lastAttendanceTimes[userData['email']] = attendanceResponse.first['marked_at'];
        }
        
        if (lastAttendanceTimes.isNotEmpty) {
          userData['last_attendance_times'] = json.encode(lastAttendanceTimes);
        }
      }
      
      return userData;
    } catch (e) {
      print('Error getting user data: $e');
      return _currentUser;
    }
  }
  
  // Get dark mode preference
  Future<bool> getDarkModeEnabled() async {
    if (_currentUser != null && _currentUser!.containsKey('dark_mode_enabled')) {
      return _currentUser!['dark_mode_enabled'] ?? false;
    }
    
    try {
      final userId = _currentUser?['id'];
      if (userId == null) return false;
      
      final response = await client
          .from('user_preferences')
          .select('dark_mode_enabled')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null) {
        // Update current user cache
        if (_currentUser != null) {
          _currentUser!['dark_mode_enabled'] = response['dark_mode_enabled'];
        }
        return response['dark_mode_enabled'] ?? false;
      }
      
      return false;
    } catch (e) {
      print('Error getting dark mode preference: $e');
      return false;
    }
  }
  
  // Set dark mode preference
  Future<void> setDarkModeEnabled(bool value) async {
    try {
      final userId = _currentUser?['id'];
      if (userId == null) return;
      
      await client
          .from('user_preferences')
          .upsert({
            'user_id': userId,
            'dark_mode_enabled': value,
          });
      
      // Update current user cache
      if (_currentUser != null) {
        _currentUser!['dark_mode_enabled'] = value;
      }
    } catch (e) {
      print('Error setting dark mode preference: $e');
    }
  }
  
  // Get has completed onboarding
  Future<bool> getHasCompletedOnboarding() async {
    if (_currentUser != null && _currentUser!.containsKey('has_completed_onboarding')) {
      return _currentUser!['has_completed_onboarding'] ?? false;
    }
    
    try {
      final userId = _currentUser?['id'];
      if (userId == null) return false;
      
      final response = await client
          .from('user_preferences')
          .select('has_completed_onboarding')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null) {
        // Update current user cache
        if (_currentUser != null) {
          _currentUser!['has_completed_onboarding'] = response['has_completed_onboarding'];
        }
        return response['has_completed_onboarding'] ?? false;
      }
      
      return false;
    } catch (e) {
      print('Error getting onboarding status: $e');
      return false;
    }
  }
  
  // Set has completed onboarding
  Future<void> setHasCompletedOnboarding(bool value) async {
    try {
      final userId = _currentUser?['id'];
      if (userId == null) return;
      
      await client
          .from('user_preferences')
          .upsert({
            'user_id': userId,
            'has_completed_onboarding': value,
          });
      
      // Update current user cache
      if (_currentUser != null) {
        _currentUser!['has_completed_onboarding'] = value;
      }
    } catch (e) {
      print('Error setting onboarding status: $e');
    }
  }
  
  // Profile Methods
  
  // Update student details
  Future<Map<String, dynamic>> updateStudentDetails(Map<String, dynamic> userData) async {
    try {
      final userId = _currentUser?['id'];
      final studentId = _currentUser?['student_id'];
      
      // Handle edge cases for ID values
      if (userId == null) {
        return {'success': false, 'message': 'No active user session'};
      }
      
      // Skip database operations for development/test accounts but still update memory
      if (userId.toString().startsWith('dev-') || 
          (studentId != null && studentId.toString().startsWith('dev-'))) {
        
        print('Development account detected - updating in-memory data only');
        
        // Just update in-memory data for development accounts
        if (_currentUser != null) {
          _currentUser!['name'] = userData['name'];
          _currentUser!['department'] = userData['department'];
          _currentUser!['course'] = userData['course'];
          _currentUser!['year'] = userData['year'];
          _currentUser!['semester'] = userData['semester'];
          
          if (userData.containsKey('password') && userData['password'] != null) {
            _currentUser!['password'] = userData['password'];
          }
        }
        
        return {'success': true, 'userData': _currentUser};
      }
      
      if (studentId == null) {
        return {'success': false, 'message': 'Student ID not found'};
      }
      
      // Update user name and password if provided
      Map<String, dynamic> userUpdate = {'name': userData['name']};
      if (userData.containsKey('password') && userData['password'] != null) {
        userUpdate['password'] = userData['password'];
      }
      
      try {
        await client
            .from('users')
            .update(userUpdate)
            .eq('id', userId);
      } catch (e) {
        print('Error updating user data: $e');
        return {'success': false, 'message': 'Failed to update user data: $e'};
      }
      
      // Update student details
      try {
        await client
            .from('students')
            .update({
              'department': userData['department'],
              'course': userData['course'],
              'year': userData['year'],
              'semester': userData['semester'],
            })
            .eq('id', studentId);
      } catch (e) {
        print('Error updating student data: $e');
        return {'success': false, 'message': 'Failed to update student data: $e'};
      }
      
      // Update in-memory current user
      if (_currentUser != null) {
        _currentUser!['name'] = userData['name'];
        _currentUser!['department'] = userData['department'];
        _currentUser!['course'] = userData['course'];
        _currentUser!['year'] = userData['year'];
        _currentUser!['semester'] = userData['semester'];
        
        if (userData.containsKey('password') && userData['password'] != null) {
          _currentUser!['password'] = userData['password'];
        }
      }
      
      print('Successfully updated student details in database and memory');
      
      // Fetch the latest data after update to ensure consistency
      Map<String, dynamic>? updatedData = await refreshUserData();
      
      return {
        'success': true, 
        'userData': updatedData ?? _currentUser
      };
    } catch (e) {
      print('Error updating student details: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Update lecturer details
  Future<Map<String, dynamic>> updateLecturerDetails(Map<String, dynamic> userData) async {
    try {
      final userId = _currentUser?['id'];
      final lecturerId = _currentUser?['lecturer_id'];
      if (userId == null || lecturerId == null) {
        return {'success': false, 'message': 'No active user session'};
      }
      
      // Split name into first and last name
      final nameParts = userData['name'].split(' ');
      final firstName = nameParts[0];
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      // Update user name
      await client
          .from('users')
          .update({
            'name': userData['name'],
            'email': userData['email'], // Email is non-editable but included for completeness
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', userId);
      
      // Update lecturer details
      await client
          .from('lecturers')
          .update({
            'department': userData['department'],
            'occupation': userData['occupation'],
            'employment_type': userData['employmentType'],
            'gender': userData['gender'],
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', lecturerId);
      
      // Update in-memory current user
      if (_currentUser != null) {
        _currentUser!.addAll({
          'name': userData['name'],
          'department': userData['department'],
          'occupation': userData['occupation'],
          'employmentType': userData['employmentType'],
          'gender': userData['gender'],
        });
      }
      
      return {'success': true, 'userData': _currentUser};
    } catch (e) {
      print('Error updating lecturer details: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Upload and save profile image
  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    try {
      final userId = _currentUser?['id'];
      final studentId = _currentUser?['student_id'];
      final email = _currentUser?['email'];
      
      if (userId == null || email == null) {
        return {'success': false, 'message': 'No active user session'};
      }

      print('Starting profile image upload for user: $email (ID: $userId)');
      
      // Create a unique filename with user ID to ensure proper organization
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path);
      final fileName = 'profile_${userId}_$timestamp$fileExtension';
      final storagePath = 'profile_images/$fileName';
      
      print('Uploading to storage path: $storagePath');

      // Upload to Supabase Storage
      await client.storage
          .from('user_uploads')
          .upload(storagePath, imageFile, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true
          ));
      
      // Get the public URL
      final imageUrl = client.storage
          .from('user_uploads')
          .getPublicUrl(storagePath);
      
      print('File uploaded successfully. URL: $imageUrl');

      // Update the database record
      bool updated = false;
      
      if (studentId != null) {
        try {
          print('Updating student record with ID: $studentId');
          await client
              .from('students')
              .update({
                'profile_image_path': imageUrl,
                'updated_at': DateTime.now().toIso8601String()
              })
              .eq('id', studentId);
          updated = true;
          print('Successfully updated student record');
        } catch (e) {
          print('Error updating student record by ID: $e');
        }
      }

      // If the first update attempt failed, try by user ID
      if (!updated) {
        try {
          print('Attempting to update by user ID: $userId');
          final studentRecord = await client
              .from('students')
              .select('id')
              .eq('user_id', userId)
              .single();
          
          await client
              .from('students')
              .update({
                'profile_image_path': imageUrl,
                'updated_at': DateTime.now().toIso8601String()
              })
              .eq('id', studentRecord['id']);
          updated = true;
          print('Successfully updated student record by user ID');
                } catch (e) {
          print('Error updating by user ID: $e');
        }
      }

      // If still not updated, try to find by email
      if (!updated) {
        try {
          print('Attempting to update by email: $email');
          final userRecord = await client
              .from('users')
              .select('id')
              .eq('email', email)
              .single();
          
          final studentRecord = await client
              .from('students')
              .select('id')
              .eq('user_id', userRecord['id'])
              .single();
          
          if (studentRecord != null) {
            await client
                .from('students')
                .update({
                  'profile_image_path': imageUrl,
                  'updated_at': DateTime.now().toIso8601String()
                })
                .eq('id', studentRecord['id']);
            updated = true;
            print('Successfully updated student record by email lookup');
          }
                } catch (e) {
          print('Error updating by email lookup: $e');
        }
      }

      if (!updated) {
        print('WARNING: Failed to update database record after multiple attempts');
        return {'success': false, 'message': 'Failed to update profile in database'};
      }

      // Update in-memory cache
      if (_currentUser != null) {
        _currentUser!['profile_image_path'] = imageUrl;
        print('Updated in-memory cache with new profile image URL');
      }

      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      print('Profile image update completed successfully');
      return {'success': true, 'imagePath': imageUrl};
    } catch (e) {
      print('Error in uploadProfileImage: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Get profile image with secure URL
  Future<String?> getProfileImagePath() async {
    try {
      if (_currentUser == null) return null;
      
      final imagePath = _currentUser!['profile_image_path'];
      if (imagePath == null || imagePath.isEmpty) return null;
      
      // Get a fresh signed URL for the image
      final signedUrl = await client.storage
          .from('user_uploads')
          .createSignedUrl(imagePath, 3600); // 1 hour expiry
          
      return signedUrl;
    } catch (e) {
      print('Error getting profile image path: $e');
      return null;
    }
  }
  
  // Attendance Methods
  
  // Create or update a session
  Future<Map<String, dynamic>> createOrUpdateSession(Map<String, dynamic> sessionData) async {
    try {
      final lecturerId = _currentUser?['lecturer_id'];
      if (lecturerId == null) {
        return {'success': false, 'message': 'No active lecturer session'};
      }
      
      // Check if the session already exists
      final existingSession = await client
          .from('attendance_sessions')
          .select()
          .eq('id', sessionData['id'])
          .single();
      
      Map<String, dynamic> session;
      
      if (existingSession != null) {
        // Update existing session
        await client
            .from('attendance_sessions')
            .update(sessionData)
            .eq('id', sessionData['id']);
        
        // Get the updated session
        session = await client
            .from('attendance_sessions')
            .select()
            .eq('id', sessionData['id'])
            .single();
      } else {
        // Create new session
        session = await client
            .from('attendance_sessions')
            .insert(sessionData)
            .select()
            .single();
      }
      
      return {'success': true, 'session': session};
    } catch (e) {
      print('Error creating/updating session: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Mark student attendance
  Future<Map<String, dynamic>> markAttendance(String sessionId, String studentEmail) async {
    try {
      // First get the student ID from the email
      final studentResponse = await client
          .from('users')
          .select('*, students(*)')
          .eq('email', studentEmail)
          .eq('user_type', 'student')
          .maybeSingle();
      
      if (studentResponse == null || studentResponse['students'] == null || studentResponse['students'].isEmpty) {
        return {'success': false, 'message': 'Student not found'};
      }
      
      final studentId = studentResponse['students'][0]['id'];
      
      // Check if attendance already exists
      final existingAttendance = await client
          .from('attendance')
          .select()
          .eq('session_id', sessionId)
          .eq('student_id', studentId)
          .maybeSingle();
      
      if (existingAttendance != null) {
        return {'success': true, 'message': 'Attendance already marked'};
      }
      
      // Create attendance record with UTC time
      final now = DateTime.now().toUtc();
      await client
          .from('attendance')
          .insert({
            'session_id': sessionId,
            'student_id': studentId,
            'marked_at': now.toIso8601String(),
            'status': 'PRESENT', // Default status
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String()
          });
      
      return {'success': true, 'message': 'Attendance marked successfully'};
    } catch (e) {
      print('Error marking attendance: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Get attendance for a specific session
  Future<Map<String, dynamic>> getSessionAttendance(String sessionId) async {
    try {
      // Get the session data
      final sessionsResponse = await client
          .from('attendance_sessions')
          .select()
          .eq('id', sessionId)
          .limit(1);
      
      if (sessionsResponse.isEmpty) {
        return {'success': false, 'message': 'Session not found'};
      }
      
      final sessionResponse = sessionsResponse[0];
      
      // Get all attendance records for this session
      final attendanceResponse = await client
          .from('attendance')
          .select('*, students(*, users(*))')
          .eq('session_id', sessionId);
      
      // Format the attendance data
      List<Map<String, dynamic>> attendeeDetails = [];
      for (var record in attendanceResponse) {
        attendeeDetails.add({
          'studentEmail': record['students']['users']['email'],
          'name': record['students']['users']['name'],
          'department': record['students']['department'],
          'course': record['students']['course'],
          'year': record['students']['year'],
          'semester': record['students']['semester'],
          'timeScanned': record['time_scanned'],
        });
      }
      
      return {
        'success': true,
        'session': sessionResponse,
        'attendeeDetails': attendeeDetails,
      };
    } catch (e) {
      print('Error getting session attendance: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // QR Code Methods
  
  // Save QR code data
  Future<Map<String, dynamic>> saveQRCode(Map<String, dynamic> qrData, File? qrImageFile) async {
    try {
      final lecturerId = await getCurrentLecturerId();
      if (lecturerId == null) {
        return {'success': false, 'message': 'No active lecturer session'};
      }
      
      // Get unit ID from units table
      final unitResponse = await client
          .from('units')
          .select('id')
          .eq('code', qrData['unit_code'])
          .single();

      final unitId = unitResponse['id'];

      // Format the session data to match the example
      final formattedSessionData = {
        'year': '1',
        'course': null,
        'duration': {
          'hours': int.parse(qrData['duration']['hours'].toString()),
          'minutes': int.parse(qrData['duration']['minutes'].toString())
        },
        'end_time': qrData['end_time'],
        'semester': '1',
        'is_active': true,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'unit_code': qrData['unit_code'],
        'unit_name': qrData['unit_name'],
        'department': null,
        'session_id': qrData['session_id'],
        'start_time': qrData['start_time'],
        'lecturer_name': null,
        'lecturer_email': null
      };

      // Create attendance session record
      final sessionResponse = await client
          .from('attendance_sessions')
          .insert({
            'lecturer_id': lecturerId,
            'unit_id': unitId,
            'qr_code_data': qrData['session_id'],
            'backup_key': qrData['backup_key'],
            'start_time': qrData['start_time'],
            'end_time': qrData['end_time'],
            'is_active': true,
            'session_data': formattedSessionData,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      return {'success': true, 'session': sessionResponse};
    } catch (e) {
      print('Error saving QR code: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Get QR code by ID
  Future<Map<String, dynamic>> getQRCode(String qrId) async {
    try {
      final qrRecords = await client
          .from('qr_codes')
          .select()
          .eq('id', qrId)
          .limit(1);
          
      if (qrRecords.isEmpty) {
        return {'success': false, 'message': 'QR code not found'};
      }
      
      final qrRecord = qrRecords[0];
      
      return {'success': true, 'qrRecord': qrRecord};
    } catch (e) {
      print('Error getting QR code: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Get all active QR codes for a unit
  Future<Map<String, dynamic>> getActiveQRCodesForUnit(String unitCode) async {
    try {
      final qrRecords = await client
          .from('qr_codes')
          .select()
          .eq('unit_code', unitCode);
      
      return {'success': true, 'qrRecords': qrRecords};
    } catch (e) {
      print('Error getting QR codes for unit: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Password Reset Methods
  
  // Reset student password
  Future<Map<String, dynamic>> resetStudentPassword(String email, String newPassword) async {
    try {
      // Check if user exists
      final userResponse = await client
          .from('users')
          .select()
          .eq('email', email)
          .eq('user_type', 'student')
          .maybeSingle();
      
      if (userResponse == null) {
        return {'success': false, 'message': 'No account found with this email'};
      }
      
      // Update password
      await client
          .from('users')
          .update({'password': newPassword})
          .eq('id', userResponse['id']);
      
      return {'success': true, 'message': 'Password reset successfully'};
    } catch (e) {
      print('Error resetting student password: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
  
  // Reset lecturer password
  Future<Map<String, dynamic>> resetLecturerPassword(String email, String newPassword) async {
    try {
      // Find the user
      final userResponse = await client
          .from('users')
          .select()
          .eq('email', email)
          .eq('user_type', 'lecturer')
          .maybeSingle();
      
      if (userResponse == null) {
        return {'success': false, 'message': 'No account found with this email'};
      }
      
      // Update password
      await client
          .from('users')
          .update({'password': newPassword})
          .eq('id', userResponse['id']);
      
      return {'success': true, 'message': 'Password reset successful'};
    } catch (e) {
      print('Error during lecturer password reset: $e');
      return {'success': false, 'message': 'An error occurred during password reset'};
    }
  }

  // Method to update current user data
  Future<void> updateCurrentUser(Map<String, dynamic> userData) async {
    await _setCurrentUser(userData);
  }
  
  // Method to refresh user data from database
  Future<Map<String, dynamic>?> refreshUserData() async {
    try {
      if (_currentUser == null) {
        return null;
      }
      
      final userId = _currentUser!['id'];
      final email = _currentUser!['email'];
      
      print('Refreshing user data for: $email (ID: $userId)');
      
      // For development accounts, try to get actual data from database
      if (userId.toString().startsWith('dev-') || email.contains('@student.thara')) {
        try {
          final userResponse = await client
              .from('users')
              .select('*, students(*)')
              .eq('email', email)
              .maybeSingle();
              
          if (userResponse != null && userResponse['students'] != null && userResponse['students'].isNotEmpty) {
            // Format year and semester consistently
            String year = userResponse['students'][0]['year']?.toString() ?? '';
            String semester = userResponse['students'][0]['semester']?.toString() ?? '';
            
            // Remove any existing "Year" or "Semester" prefix
            year = year.replaceAll(RegExp(r'^Year\s*'), '');
            semester = semester.replaceAll(RegExp(r'^Semester\s*'), '');
            
            // Build refreshed data with latest values and consistent formatting
            final refreshedData = {
              'id': userResponse['id'],
              'email': userResponse['email'],
              'name': userResponse['name'],
              'password': userResponse['password'],
              'department': userResponse['students'][0]['department'],
              'course': userResponse['students'][0]['course'],
              'year': year,
              'semester': semester,
              'profile_image_path': userResponse['students'][0]['profile_image_path'],
              'student_id': userResponse['students'][0]['id'],
              'user_type': 'student',
            };
            
            // Update cache with actual data
            _currentUser = refreshedData;
            print('Updated user data refreshed from database: ${refreshedData['name']}');
            return _currentUser;
          }
        } catch (e) {
          print('Error getting development user data from database: $e');
        }
        
        // If no data found in database, return current cached data
        print('Development account: returning cached user data');
        return _currentUser;
      }
      
      // For students
      if (_currentUser!.containsKey('student_id')) {
        final studentId = _currentUser!['student_id'];
        if (studentId == null) return _currentUser;
        
        print('Fetching latest user data from Supabase for student ID: $studentId');
        
        // IMPORTANT: Use a direct query to get the MOST UP TO DATE user data
        // This bypasses any client-side caching that might be happening
        final refreshedUserResponse = await client
            .from('users')
            .select('*, students!inner(*)')
            .eq('id', userId)
            .limit(1)
            .single();
        
        final studentData = refreshedUserResponse['students'][0];
        
        print('Got fresh data from database: Name=${refreshedUserResponse['name']}');
        
        // Only update if we have valid data
        if (studentData['department'] == null || 
            studentData['course'] == null || 
            studentData['year'] == null || 
            studentData['semester'] == null) {
          print('Invalid student data received, keeping current data');
          return _currentUser;
        }
        
        // Format year and semester consistently
        String year = studentData['year'].toString();
        String semester = studentData['semester'].toString();
        
        // Remove any existing "Year" or "Semester" prefix
        year = year.replaceAll(RegExp(r'^Year\s*'), '');
        semester = semester.replaceAll(RegExp(r'^Semester\s*'), '');
        
        // Build refreshed data with latest values and consistent formatting
        final refreshedData = {
          'id': refreshedUserResponse['id'],
          'email': refreshedUserResponse['email'],
          'name': refreshedUserResponse['name'],
          'password': refreshedUserResponse['password'],
          'department': studentData['department'],
          'course': studentData['course'],
          'year': year,
          'semester': semester,
          'profile_image_path': studentData['profile_image_path'],
          'student_id': studentData['id'],
          'user_type': 'student',
        };
        
        // Always update the in-memory cache with the latest database values
        _currentUser = refreshedData;
        
        print('User data refreshed from database and cache updated: Name=${refreshedData['name']}');
        return refreshedData;
      }
      
      return _currentUser;
    } catch (e) {
      print('Error refreshing user data: $e');
      return _currentUser;
    }
  }
  
  // Direct login method using raw SQL to avoid duplicate email issues
  Future<Map<String, dynamic>> directLogin(String email, String password) async {
    try {
      // Validate input first
      if (email.isEmpty) {
        return {'success': false, 'message': 'Email cannot be empty'};
      }
      
      if (password.isEmpty) {
        return {'success': false, 'message': 'Password cannot be empty'};
      }

      // Trim email to remove any accidental whitespace
      email = email.trim().toLowerCase();

      // Get user from users table - use limit(1) instead of single() to handle duplicate emails
      final usersResponse = await client
          .from('users')
          .select('*, students(*)')
          .eq('email', email)
          .eq('user_type', 'student')
          .limit(1);
      
      // Check if any users were found
      if (usersResponse.isEmpty) {
        return {'success': false, 'message': 'No account found with this email'};
      }
      
      // Use the first matching user
      final userResponse = usersResponse[0];
      
      // If password doesn't match
      if (userResponse['password'] != password) {
        return {'success': false, 'message': 'Incorrect password'};
      }
      
      // Ensure student record exists
      if (userResponse['students'] == null || userResponse['students'].isEmpty) {
        return {'success': false, 'message': 'Incomplete student profile'};
      }
      
      // Login successful - get preferences
      final preferencesResponse = await client
          .from('user_preferences')
          .select()
          .eq('user_id', userResponse['id'])
          .maybeSingle();
      
      // Check for profile image in the students table
      String? profileImagePath = userResponse['students'][0]['profile_image_path'];
      final studentId = userResponse['students'][0]['id'];
      
      // Always refresh profile image path to ensure it's up-to-date
      await refreshProfileImagePath(studentId, userResponse['id'], email);
      
      // Get the latest profile image path after refresh attempt
      final updatedStudentResponse = await client
          .from('students')
          .select('profile_image_path')
          .eq('id', studentId)
          .maybeSingle();
          
      if (updatedStudentResponse != null && 
          updatedStudentResponse['profile_image_path'] != null && 
          updatedStudentResponse['profile_image_path'].toString().isNotEmpty) {
        profileImagePath = updatedStudentResponse['profile_image_path'];
        print('Using refreshed profile image path: $profileImagePath');
      }
      
      // Combine user data
      Map<String, dynamic> userData = {
        'id': userResponse['id'],
        'email': userResponse['email'],
        'name': userResponse['name'],
        'password': userResponse['password'],
        'department': userResponse['students'][0]['department'] ?? '',
        'course': userResponse['students'][0]['course'] ?? '',
        'year': userResponse['students'][0]['year'] ?? '',
        'semester': userResponse['students'][0]['semester'] ?? '',
        'profile_image_path': profileImagePath,
        'student_id': userResponse['students'][0]['id'],
      };
      
      // Add preferences if they exist
      if (preferencesResponse != null) {
        userData['dark_mode_enabled'] = preferencesResponse['dark_mode_enabled'];
        userData['has_completed_onboarding'] = preferencesResponse['has_completed_onboarding'];
        userData['language'] = preferencesResponse['language'];
      }
      
      // Update last login time
      await client
          .from('users')
          .update({'last_login': DateTime.now().toIso8601String()})
          .eq('id', userResponse['id']);
      
      // Set current session user
      await updateCurrentUser(userData);
      
      return {'success': true, 'userData': userData};
    } catch (e) {
      print('Error during direct login: $e');
      return {'success': false, 'message': 'An unexpected error occurred. Please try again.'};
    }
  }

  // Alias method for backward compatibility
  Future<Map<String, dynamic>> studentDirectLogin(String email, String password) async {
    return directLogin(email, password);
  }

  // Helper to persist student profile image URL properly
  Future<bool> refreshProfileImagePath(String studentId, String userId, String email) async {
    try {
      // First check for direct images in storage that match this user's email
      final storageResponse = await client.storage
          .from('user_uploads')
          .list();
      
      if (storageResponse.isNotEmpty) {
        // Filter for this user's profile images
        final userImages = storageResponse.where((file) => 
            file.name.startsWith('profile_images/') && 
            (file.name.contains(email.replaceAll('@', '_')) || 
             file.name.toLowerCase().contains(email.toLowerCase()))).toList();
        
        if (userImages.isNotEmpty) {
          // Sort by name in descending order to get the most recent
          userImages.sort((a, b) => b.name.compareTo(a.name));
          
          // Get the public URL with cache busting
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final imageUrl = '${client.storage
              .from('user_uploads')
              .getPublicUrl(userImages.first.name)}?t=$timestamp';
          
          print('Found the most recent profile image in storage: $imageUrl');
          
          // Update the student record with this URL
          try {
            await client
                .from('students')
                .update({
                  'profile_image_path': imageUrl,
                  'updated_at': DateTime.now().toIso8601String()
                })
                .eq('id', studentId);
                
            print('Updated student profile with image URL in database (REFRESH)');
            
            // Also update in-memory current user
            if (_currentUser != null) {
              _currentUser!['profile_image_path'] = imageUrl;
              print('Updated in-memory profile image path during refresh');
            }
            
            return true;
          } catch (e) {
            print('Error updating profile image in database during refresh: $e');
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error refreshing profile image: $e');
      return false;
    }
  }

  // Helper function to ensure a student record exists for a user
  Future<String?> ensureStudentRecordExists(String userId, String email) async {
    try {
      print('Checking for existing student record for user $userId ($email)');
      
      // Check if student record exists
      final studentResponse = await client
          .from('students')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (studentResponse != null) {
        print('Found existing student record with ID: ${studentResponse['id']}');
        return studentResponse['id'];
      }
      
      // Get current user data to use for creating student record
      final userData = _currentUser;
      if (userData == null) {
        print('No current user data available to create student record');
        return null;
      }
      
      // Create student record if it doesn't exist using current user's data
      print('No student record found, creating one with current user data...');
      try {
        final newStudent = await client
            .from('students')
            .insert({
              'user_id': userId,
              'department': userData['department'] ?? '',
              'course': userData['course'] ?? '',
              'year': userData['year'] ?? '',
              'semester': userData['semester'] ?? '',
              'profile_image_path': userData['profile_image_path']
            })
            .select()
            .single();
        
        final studentId = newStudent['id'];
        print('Created new student record with ID: $studentId');
        return studentId;
      } catch (e) {
        print('Error creating student record: $e');
        return null;
      }
    } catch (e) {
      print('Error in ensureStudentRecordExists: $e');
      return null;
    }
  }
  
  // Helper to ensure profile image is properly stored
  Future<bool> ensureProfileImageStored(String email, String imageUrl) async {
    try {
      // First find the user by email
      final userResponse = await client
          .from('users')
          .select('id, email')
          .eq('email', email)
          .maybeSingle();
      
      if (userResponse == null) {
        print('Could not find user with email: $email');
        return false;
      }
      
      // Now find the student record for this user
      final studentResponse = await client
          .from('students')
          .select('id, profile_image_path')
          .eq('user_id', userResponse['id'])
          .maybeSingle();
      
      if (studentResponse != null) {
        // Update the student record with the image URL
        await client
            .from('students')
            .update({'profile_image_path': imageUrl})
            .eq('id', studentResponse['id']);
        
        print('Updated student profile image (ID: ${studentResponse['id']}) for user ${userResponse['email']}');
        
        // Double-check that the update worked by fetching the record again
        final verifyResponse = await client
            .from('students')
            .select('profile_image_path')
            .eq('id', studentResponse['id'])
            .maybeSingle();
            
        if (verifyResponse != null && verifyResponse['profile_image_path'] == imageUrl) {
          print('Verified profile image was correctly stored');
          return true;
        } else {
          print('Warning: Profile image verification failed, trying direct update');
          
          // Try one more direct update
          try {
            // Try a direct SQL update as a last resort
            await client
                .from('students')
                .update({
                  'profile_image_path': imageUrl,
                  'updated_at': DateTime.now().toIso8601String()
                })
                .eq('id', studentResponse['id']);
            
            print('Made a final attempt to update profile image for student ID: ${studentResponse['id']}');
            return true;
          } catch (updateError) {
            print('Final update attempt also failed: $updateError');
            return false;
          }
        }
      } else {
        print('No student record found for user ID: ${userResponse['id']}');
        return false;
      }
    } catch (e) {
      print('Error ensuring profile image is stored: $e');
      return false;
    }
  }
  
  // Helper to directly update student profile image
  Future<bool> updateStudentProfileImageDirect(String userId, String imageUrl) async {
    try {
      // First try standard update by user_id
      await client
          .from('students')
          .update({
            'profile_image_path': imageUrl,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('user_id', userId);
          
      print('Attempted direct update by user_id: $userId with URL: $imageUrl');
      
      // Query to check if update was successful
      final checkResult = await client
          .from('students')
          .select('id, profile_image_path')
          .eq('user_id', userId)
          .maybeSingle();
          
      if (checkResult != null && checkResult['profile_image_path'] == imageUrl) {
        print('Profile image URL updated successfully for student ID: ${checkResult['id']}');
        return true;
      }
      
      // If update failed, try a direct SQL query as a last resort
      // This approach bypasses any API limitations
      print('Direct update failed or could not be verified');
      return false;
    } catch (e) {
      print('Error in updateStudentProfileImageDirect: $e');
      return false;
    }
  }

  // Update student location - simplified to match existing schema
  Future<bool> updateStudentLocation(String studentId, String location, double? latitude, double? longitude) async {
    try {
      if (studentId.isEmpty) {
        print('Cannot update location: student ID is empty');
        return false;
      }
      
      // For development/test accounts, create a real record to demonstrate the capability
      if (studentId.startsWith('dev-')) {
        print('Development account detected - creating a real location record for testing');
        
        try {
          // Find a test student record
          final studentRecord = await client
              .from('students')
              .select('id')
              .limit(1)
              .maybeSingle();
          
          if (studentRecord != null) {
            String realStudentId = studentRecord['id'];
            print('Found existing student record with ID: $realStudentId to use for demo');
            
            // Update the location for this real student
            await client
                .from('students')
                .update({
                  'current_location': location
                })
                .eq('id', realStudentId);
            
            print('Updated location for test student ID: $realStudentId');
            return true;
          } else {
            print('No student records found to use for testing');
            return false;
          }
        } catch (e) {
          print('Error updating test student location: $e');
          return false;
        }
      }
      
      // PRODUCTION USER FLOW - This is for real users
      print('Attempting to update location for production student ID: $studentId');
      print('Location data: $location');
      
      // First check if the student record exists
      final studentExists = await client
          .from('students')
          .select('id, user_id')
          .eq('id', studentId)
          .maybeSingle();
          
      if (studentExists == null) {
        print('ERROR: Student record with ID $studentId not found in database');
        return false;
      }
      
      // If student exists, update the location
      try {
        // Simple update with only current_location field
        await client
            .from('students')
            .update({
              'current_location': location
            })
            .eq('id', studentId);
        
        print('✓ Updated current_location to: $location');
        return true;
      } catch (e) {
        print('Error updating student location: $e');
        return false;
      }
    } catch (e) {
      print('Error in updateStudentLocation method: $e');
      return false;
    }
  }
  
  // Direct location update - simplified to match schema
  Future<bool> updateLocationDirect(String studentId, String location, double? latitude, double? longitude) async {
    try {
      if (studentId.isEmpty) {
        print('Cannot update location directly: student ID is empty');
        return false;
      }
      
      // Skip dev accounts
      if (studentId.startsWith('dev-')) {
        print('Development account detected - finding real student to update');
        
        try {
          // Find a real student to update
          final studentRecord = await client
              .from('students')
              .select('id')
              .limit(1)
              .maybeSingle();
              
          if (studentRecord != null) {
            studentId = studentRecord['id'];
            print('Using real student ID for demo: $studentId');
          } else {
            return false;
          }
        } catch (e) {
          print('Could not find real student for dev update: $e');
          return false;
        }
      }
      
      print('DIRECT UPDATE: Attempting to update location for student $studentId');
      
      // Simple direct update with only current_location
      await client
          .from('students')
          .update({
            'current_location': location
          })
          .eq('id', studentId);
      
      print('DIRECT UPDATE: Completed for student $studentId');
      return true;
    } catch (e) {
      print('DIRECT UPDATE: Error in direct location update: $e');
      return false;
    }
  }

  // Get current user location
  Future<Map<String, dynamic>?> getStudentLocation(String studentId) async {
    try {
      if (studentId.isEmpty) {
        print('Cannot get location: student ID is empty');
        return null;
      }
      
      // For development accounts, use a real student ID
      if (studentId.startsWith('dev-')) {
        try {
          // Find a real student to check
          final studentRecord = await client
              .from('students')
              .select('id')
              .limit(1)
              .maybeSingle();
              
          if (studentRecord != null) {
            studentId = studentRecord['id'];
            print('Using real student ID for location check: $studentId');
          } else {
            return null;
          }
        } catch (e) {
          print('Could not find real student for location check: $e');
          return null;
        }
      }
      
      final response = await client
          .from('students')
          .select('current_location')
          .eq('id', studentId)
          .maybeSingle();
          
      return response;
    } catch (e) {
      print('Error getting student location: $e');
      return null;
    }
  }

  // Check storage for profile images and update database
  Future<String?> syncProfileImageWithDatabase(String email, String? studentId) async {
    try {
      print('Syncing profile image for email: $email, studentId: $studentId');
      
      // Skip if no email or student ID
      if (email.isEmpty) {
        return null;
      }
      
      String? imageUrl;
      
      // First check if user already has a profile image in the database
      if (studentId != null && studentId.isNotEmpty && !studentId.startsWith('dev-')) {
        final studentRecord = await client
            .from('students')
            .select('profile_image_path')
            .eq('id', studentId)
            .maybeSingle();
            
        if (studentRecord != null && 
            studentRecord['profile_image_path'] != null && 
            studentRecord['profile_image_path'].toString().isNotEmpty) {
          imageUrl = studentRecord['profile_image_path'];
          print('Found existing profile image in database: $imageUrl');
          return imageUrl;
        }
      }
      
      // If no image found in database, check storage for any images matching this email
      try {
        print('Checking storage for profile images matching email: $email');
        
        final storageResponse = await client.storage
            .from('user_uploads')
            .list(path: 'profile_images');
        
        if (storageResponse.isNotEmpty) {
          // Find all images matching this email
          final matchingFiles = storageResponse.where((file) => 
              file.name.toLowerCase().contains(email.replaceAll('@', '_').toLowerCase()) || 
              file.name.toLowerCase().contains(email.toLowerCase())).toList();
          
          if (matchingFiles.isNotEmpty) {
            // Sort by name in descending order to get the most recent image
            matchingFiles.sort((a, b) => b.name.compareTo(a.name));
            
            // Get the public URL of the most recent image
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            imageUrl = '${client.storage
                .from('user_uploads')
                .getPublicUrl('profile_images/${matchingFiles.first.name}')}?t=$timestamp';
                
            print('Found matching profile image in storage: $imageUrl');
            
            // Now update the database with this URL if we have a valid student ID
            if (studentId != null && studentId.isNotEmpty && !studentId.startsWith('dev-')) {
              try {
                await client
                    .from('students')
                    .update({'profile_image_path': imageUrl})
                    .eq('id', studentId);
                    
                print('Updated database with profile image URL: $imageUrl');
              } catch (e) {
                print('Error updating database with profile image URL: $e');
              }
            } else {
              // Try to find the student ID by email if not provided
              print('Trying to find student ID by email to update profile image');
              
              try {
                final userRecord = await client
                    .from('users')
                    .select('id')
                    .eq('email', email)
                    .maybeSingle();
                    
                if (userRecord != null) {
                  final studentRecord = await client
                      .from('students')
                      .select('id')
                      .eq('user_id', userRecord['id'])
                      .maybeSingle();
                      
                  if (studentRecord != null) {
                    await client
                        .from('students')
                        .update({'profile_image_path': imageUrl})
                        .eq('id', studentRecord['id']);
                        
                    print('Updated database with profile image URL for student ID: ${studentRecord['id']}');
                  }
                }
              } catch (e) {
                print('Error finding student ID by email: $e');
              }
            }
          }
        }
      } catch (e) {
        print('Error checking storage for profile images: $e');
      }
      
      return imageUrl;
    } catch (e) {
      print('Error in syncProfileImageWithDatabase: $e');
      return null;
    }
  }

  // Dropdown Data Methods
  
  // Fetch all student signup dropdown data at once (departments, years, semesters)
  Future<Map<String, dynamic>> getStudentSignupData() async {
    try {
      print('Fetching student signup data from Supabase');
      
      // Check if we can reach Supabase with retries
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(seconds: 2);
      
      while (retryCount < maxRetries) {
        try {
          // Use departments table instead of health_check
          await client.from('departments').select().limit(1).timeout(
            Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Connection to Supabase timed out');
            },
          );
          break; // If successful, break the retry loop
        } catch (e) {
          retryCount++;
          print('Connection attempt $retryCount failed: $e');
          if (retryCount == maxRetries) {
            return {
              'success': false,
              'message': 'Unable to connect to server. Please check your internet connection.',
            };
          }
          await Future.delayed(retryDelay);
        }
      }

      // Fetch all data in parallel for better performance
      final futures = await Future.wait([
        client.from('departments').select('id, name').order('name'),
        client.from('academic_years').select('id, year').order('year'),
        client.from('semesters').select('id, name').order('name'),
      ]);
      
      final departmentsResponse = futures[0];
      final yearsResponse = futures[1];
      final semestersResponse = futures[2];
      
      if (yearsResponse == null) {
        return {
          'success': false,
          'message': 'Failed to load signup data. Please try again.',
        };
      }
      
      return {
        'success': true,
        'data': {
          'departments': departmentsResponse,
          'academic_years': yearsResponse,
          'semesters': semestersResponse,
        },
      };
    } catch (e) {
      print('Error fetching student signup data: $e');
      return {
        'success': false,
        'message': 'Failed to load signup data. Please check your connection.',
      };
    }
  }
  
  // Get courses for a specific department
  Future<Map<String, dynamic>> getCoursesByDepartment(String departmentId) async {
    try {
      print('Fetching courses for department ID: $departmentId');
      
      // Check if we can reach Supabase with retries
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(seconds: 2);
      
      while (retryCount < maxRetries) {
        try {
          // Use departments table instead of health_check
          await client.from('departments').select().limit(1).timeout(
            Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Connection to Supabase timed out');
            },
          );
          break; // If successful, break the retry loop
        } catch (e) {
          retryCount++;
          print('Connection attempt $retryCount failed: $e');
          if (retryCount == maxRetries) {
            return {
              'success': false,
              'message': 'Unable to connect to server. Please check your internet connection.',
            };
          }
          await Future.delayed(retryDelay);
        }
      }

      if (departmentId.isEmpty) {
        return {
          'success': false,
          'message': 'Please select a department first',
        };
      }
      
      final response = await client
          .from('courses')
          .select('id, name')
          .eq('department_id', departmentId)
          .order('name');
      
      if (response.isEmpty) {
        return {
          'success': false,
          'message': 'No courses found for this department.',
        };
      }
      
      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      print('Error fetching courses by department: $e');
      return {
        'success': false,
        'message': 'Failed to load courses. Please check your connection.',
      };
    }
  }
  
  // Get units for a specific course
  Future<Map<String, dynamic>> getUnitsByCourse(String courseId) async {
    try {
      final response = await client
          .rpc('get_course_units', params: {'p_course_id': courseId})
          .single();
      
      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      print('Error fetching units by course: $e');
      return {
        'success': false,
        'message': 'Failed to load units',
      };
    }
  }

  // Comprehensive student profile update method using server-side function
  Future<Map<String, dynamic>> updateStudentProfile({
    required String studentId, 
    required Map<String, dynamic> updateData,
  }) async {
    try {
      // Get department and course IDs if they are being updated
      Map<String, dynamic> studentUpdateData = {};
      
      if (updateData.containsKey('department')) {
        final departmentResponse = await client
            .from('departments')
            .select('id')
            .eq('name', updateData['department'])
            .single();
        studentUpdateData['department_id'] = departmentResponse['id'];
      }
      
      if (updateData.containsKey('course')) {
        final courseResponse = await client
            .from('courses')
            .select('id')
            .eq('name', updateData['course'])
            .eq('department_id', studentUpdateData['department_id'])
            .single();
        studentUpdateData['course_id'] = courseResponse['id'];
      }
      
      // Add other fields to update
      if (updateData.containsKey('year')) {
        studentUpdateData['year'] = updateData['year'];
      }
      if (updateData.containsKey('semester')) {
        studentUpdateData['semester'] = updateData['semester'];
      }
      
      // Update student record
      final updatedStudent = await client
          .from('students')
          .update(studentUpdateData)
          .eq('id', studentId)
          .select('''
            *,
            courses:course_id(*),
            departments:department_id(*)
          ''')
          .single();

      // Update user record if name is being updated
      if (updateData.containsKey('name')) {
        await client
            .from('users')
            .update({'name': updateData['name']})
            .eq('id', updatedStudent['user_id']);
      }
    
      return {
        'success': true, 
        'message': 'Profile updated successfully',
        'data': updatedStudent
      };
    } catch (e) {
      print('Error updating student profile: $e');
      return {
        'success': false, 
        'message': 'Failed to update profile: $e'
      };
    }
  }

  // Verify current password before update
  Future<bool> verifyPassword({
    required String email, 
    required String password
  }) async {
    try {
      final userResponse = await client
        .from('users')
        .select()
        .eq('email', email)
        .eq('password', password)
        .single();
      
      return userResponse != null;
    } catch (e) {
      print('Password verification error: $e');
      return false;
    }
  }

  // Update password method
  Future<Map<String, dynamic>> updatePassword({
    required String email, 
    required String newPassword
  }) async {
    try {
      await client
        .from('users')
        .update({'password': newPassword})
        .eq('email', email);
      
      return {
        'success': true, 
        'message': 'Password updated successfully'
      };
    } catch (e) {
      print('Password update error: $e');
      return {
        'success': false, 
        'message': 'Failed to update password: ${e.toString()}'
      };
    }
  }

  // Get lecturer departments with retry logic
  Future<Map<String, dynamic>> getLecturerDepartments() async {
    try {
      print('Fetching lecturer departments from Supabase');
      
      // Check if we can reach Supabase with retries
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(seconds: 2);
      
      while (retryCount < maxRetries) {
        try {
          // Use departments table instead of health_check
          await client.from('departments').select().limit(1).timeout(
            Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Connection to Supabase timed out');
            },
          );
          break; // If successful, break the retry loop
        } catch (e) {
          retryCount++;
          print('Connection attempt $retryCount failed: $e');
          if (retryCount == maxRetries) {
            return {
              'success': false,
              'message': 'Unable to connect to server. Please check your internet connection.',
            };
          }
          await Future.delayed(retryDelay);
        }
      }
      
      final response = await client
          .from('departments')
          .select('id, name')
          .order('name');
      
      print('Response from departments: $response');
      
      if (response.isEmpty) {
        return {
          'success': false,
          'message': 'No departments found. Please try again later.',
        };
      }
      
      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      print('Error fetching lecturer departments: $e');
      return {
        'success': false,
        'message': 'Failed to load departments. Please check your connection.',
      };
    }
  }

  // Upload and update lecturer profile image
  Future<Map<String, dynamic>> uploadLecturerProfileImage(File imageFile) async {
    try {
      final userId = _currentUser?['id'];
      final lecturerId = _currentUser?['lecturer_id'];
      final email = _currentUser?['email'];
      
      if (userId == null || lecturerId == null || email == null) {
        return {'success': false, 'message': 'No active user session'};
      }

      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = path.extension(imageFile.path);
      final fileName = 'lecturer_profile_${email.replaceAll('@', '_')}_$timestamp$fileExtension';
      final storagePath = 'profile_images/$fileName';
      
      // Upload to Supabase Storage
        await client.storage
            .from('user_uploads')
          .upload(storagePath, imageFile, fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true
          ));
        
        // Get the public URL
        final imageUrl = client.storage
            .from('user_uploads')
            .getPublicUrl(storagePath);
        
      // Update the lecturer record
        await client
            .from('lecturers')
            .update({
              'profile_image_path': imageUrl,
              'updated_at': DateTime.now().toIso8601String()
            })
            .eq('id', lecturerId);
        
      // Update in-memory cache
        if (_currentUser != null) {
          _currentUser!['profile_image_path'] = imageUrl;
        }

      return {'success': true, 'imagePath': imageUrl};
    } catch (e) {
      print('Error uploading lecturer profile image: $e');
      return {'success': false, 'message': 'Failed to upload image'};
    }
  }

  Future<String?> syncLecturerProfileImage(String email, String? lecturerId) async {
    try {
      print('Syncing lecturer profile image for email: $email, lecturerId: $lecturerId');
      
      // Skip if no email
      if (email.isEmpty) {
        return null;
      }
      
      String? imageUrl;
      
      // First check if lecturer already has a profile image in the database
      if (lecturerId != null && lecturerId.isNotEmpty) {
        final lecturerRecord = await client
            .from('lecturers')
            .select('profile_image_path')
            .eq('id', lecturerId)
            .maybeSingle();
            
        if (lecturerRecord != null && 
            lecturerRecord['profile_image_path'] != null && 
            lecturerRecord['profile_image_path'].toString().isNotEmpty) {
          imageUrl = lecturerRecord['profile_image_path'];
          print('Found existing lecturer profile image in database: $imageUrl');
          return imageUrl;
        }
      }
      
      // If no image found in database, check storage for any images matching this email
      try {
        print('Checking storage for lecturer profile images matching email: $email');
        
        final storageResponse = await client.storage
            .from('user_uploads')
            .list(path: 'profile_images');
        
        if (storageResponse.isNotEmpty) {
          // Find all images matching this lecturer's email
          final matchingFiles = storageResponse.where((file) => 
              file.name.toLowerCase().contains('lecturer_profile_${email.replaceAll('@', '_').toLowerCase()}') || 
              file.name.toLowerCase().contains(email.toLowerCase())).toList();
          
          if (matchingFiles.isNotEmpty) {
            // Sort by name in descending order to get the most recent image
            matchingFiles.sort((a, b) => b.name.compareTo(a.name));
            
            // Get the public URL of the most recent image
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            imageUrl = '${client.storage
                .from('user_uploads')
                .getPublicUrl('profile_images/${matchingFiles.first.name}')}?t=$timestamp';
                
            print('Found matching lecturer profile image in storage: $imageUrl');
            
            // Update the database with this URL if we have a valid lecturer ID
            if (lecturerId != null && lecturerId.isNotEmpty) {
              try {
                await client
                    .from('lecturers')
                    .update({'profile_image_path': imageUrl})
                    .eq('id', lecturerId);
                    
                print('Updated database with lecturer profile image URL: $imageUrl');
              } catch (e) {
                print('Error updating lecturer profile image URL in database: $e');
              }
            } else {
              // Try to find the lecturer ID by email
              try {
                final userRecord = await client
                    .from('users')
                    .select('id')
                    .eq('email', email)
                    .maybeSingle();
                    
                if (userRecord != null) {
                  final lecturerRecord = await client
                      .from('lecturers')
                      .select('id')
                      .eq('user_id', userRecord['id'])
                      .maybeSingle();
                      
                  if (lecturerRecord != null) {
                    await client
                        .from('lecturers')
                        .update({'profile_image_path': imageUrl})
                        .eq('id', lecturerRecord['id']);
                        
                    print('Updated database with profile image URL for lecturer ID: ${lecturerRecord['id']}');
                  }
                }
              } catch (e) {
                print('Error finding lecturer ID by email: $e');
              }
            }
          }
        }
      } catch (e) {
        print('Error checking storage for lecturer profile images: $e');
      }
      
      return imageUrl;
    } catch (e) {
      print('Error in syncLecturerProfileImage: $e');
      return null;
    }
  }

  Future<bool> refreshLecturerProfileImage(String lecturerId, String userId, String email) async {
    try {
      // First check for direct images in storage that match this lecturer's email
      final storageResponse = await client.storage
          .from('user_uploads')
          .list(path: 'profile_images');
      
      if (storageResponse.isNotEmpty) {
        // Filter for this lecturer's profile images
        final userImages = storageResponse.where((file) => 
            file.name.startsWith('profile_images/') && 
            (file.name.contains('lecturer_profile_${email.replaceAll('@', '_')}') || 
             file.name.toLowerCase().contains(email.toLowerCase()))).toList();
        
        if (userImages.isNotEmpty) {
          // Sort by name in descending order to get the most recent
          userImages.sort((a, b) => b.name.compareTo(a.name));
          
          // Get the public URL with cache busting
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final imageUrl = '${client.storage
              .from('user_uploads')
              .getPublicUrl('profile_images/${userImages.first.name}')}?t=$timestamp';
          
          print('Found the most recent lecturer profile image in storage: $imageUrl');
          
          // Update the lecturer record with this URL
          try {
            await client
                .from('lecturers')
                .update({
                  'profile_image_path': imageUrl,
                  'updated_at': DateTime.now().toIso8601String()
                })
                .eq('id', lecturerId);
                
            print('Updated lecturer profile with image URL in database (REFRESH)');
            
            // Also update in-memory current user
            if (_currentUser != null) {
              _currentUser!['profile_image_path'] = imageUrl;
              print('Updated in-memory profile image path during refresh');
            }
            
            return true;
          } catch (e) {
            print('Error updating lecturer profile image in database during refresh: $e');
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error refreshing lecturer profile image: $e');
      return false;
    }
  }

  // Get current lecturer ID
  Future<String?> getCurrentLecturerId() async {
    try {
      final currentUser = getCurrentUser();
      if (currentUser == null) {
        throw Exception('No user logged in');
      }
      return currentUser['lecturer_id'];
    } catch (e) {
      print('Error getting current lecturer ID: $e');
      return null;
    }
  }

  // Get assigned units for a lecturer
  Future<List<Map<String, dynamic>>> getAssignedUnits(String lecturerId) async {
    try {
      // First get lecturer details
      final lecturerDetails = await client
          .from('lecturers')
          .select('name, email, department')
          .eq('id', lecturerId)
          .single();

      // Then get assigned units with course details
      final response = await client
          .from('lecturer_assigned_units')
          .select('*, units!lecturer_assigned_units_unit_code_fkey(*)')
          .eq('lecturer_id', lecturerId)
          .order('created_at');

      // Transform the response to include all required details
      return List<Map<String, dynamic>>.from(response).map((record) {
        final unit = record['units'];
        return {
          'id': record['id'],
          'unit_code': unit['code'],
          'unit_name': unit['name'],
          'department': record['department'],
          'course': record['course_name'],
          'year': record['year'],
          'semester': record['semester'],
          'created_at': record['created_at'],
          'lecturer_name': lecturerDetails['name'],
          'lecturer_email': lecturerDetails['email'],
        };
      }).toList();
    } catch (e) {
      print('Error getting assigned units: $e');
      return [];
    }
  }

  // Upload QR code image to Supabase storage
  Future<String> uploadQRCode(Uint8List imageBytes, String fileName) async {
    try {
      print('Starting QR code upload...'); // Debug print
      
      // Upload to qr_codes bucket
      await client
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

      // Get public URL
      final String publicUrl = client
          .storage
          .from('qr_codes')
          .getPublicUrl(fileName);

      print('Generated public URL: $publicUrl'); // Debug print
      return publicUrl;
    } catch (e) {
      print('Error in uploadQRCode: $e'); // Debug print
      throw Exception('Failed to upload QR code: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> getActiveSessionForUnit(String unitCode) async {
    try {
      // Get unit ID from units table
      final unitResponse = await client
          .from('units')
          .select('id')
          .eq('code', unitCode)
          .single();

      final unitId = unitResponse['id'];
      final now = DateTime.now().toUtc();

      // Check for any active sessions that haven't ended yet
      final response = await client
          .from('attendance_sessions')
          .select()
          .eq('unit_id', unitId)
          .eq('is_active', true)
          .gte('end_time', now.toIso8601String())
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        print('Found active session for unit $unitCode ending at ${response['end_time']}');
      }
      
      return response;
    } catch (e) {
      print('Error checking active sessions: $e');
      return null;
    }
  }

  // Check for overlapping sessions
  Future<Map<String, dynamic>?> checkOverlappingSessions(String unitCode, DateTime startTime, DateTime endTime) async {
    try {
      // Get all active sessions that overlap with the proposed time slot
      final response = await client
          .from('attendance_sessions')
          .select('*, units!inner(*)')
          .neq('units.code', unitCode) // Exclude current unit
          .eq('is_active', true)
          .lte('start_time', endTime.toUtc().toIso8601String()) // Session starts before our end
          .gte('end_time', startTime.toUtc().toIso8601String()) // Session ends after our start
          .order('start_time')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        // Format the conflicting session details
        final conflictingUnit = response['units'];
        final conflictStartTime = DateTime.parse(response['start_time']).toLocal();
        final conflictEndTime = DateTime.parse(response['end_time']).toLocal();
        
        return {
          'hasConflict': true,
          'conflictingUnit': '${conflictingUnit['code']} - ${conflictingUnit['name']}',
          'startTime': DateFormat('HH:mm').format(conflictStartTime),
          'endTime': DateFormat('HH:mm').format(conflictEndTime),
          'date': DateFormat('dd/MM/yyyy').format(conflictStartTime),
        };
      }

      return null;
    } catch (e) {
      print('Error checking overlapping sessions: $e');
      return null;
    }
  }

  Future<void> createAttendanceSession({
    required String lecturerId,
    required String unitCode,
    required String qrCodeUrl,
    required String qrCodeData,
    required String backupKey,
    required DateTime startTime,
    required DateTime endTime,
    required Map<String, dynamic> sessionData,
  }) async {
    try {
      // Get unit ID from units table
      final unitResponse = await client
          .from('units')
          .select('id')
          .eq('code', unitCode)
          .single();
      
      final unitId = unitResponse['id'];

      // Format display times in 24-hour format
      final displayStartTime = DateFormat('HH:mm').format(startTime.toLocal());
      final displayEndTime = DateFormat('HH:mm').format(endTime.toLocal());
      final displayDate = DateFormat('dd/MM/yyyy').format(startTime.toLocal());

      // Create session data with time status
      final updatedSessionData = Map<String, dynamic>.from(sessionData);
      updatedSessionData.addAll({
        'display_time': '$displayStartTime - $displayEndTime',
        'display_date': displayDate,
        'start_time': displayStartTime,
        'end_time': displayEndTime,
        'time_status': {
          'start_time': displayStartTime,
          'end_time': displayEndTime,
          'date': displayDate,
          'duration': sessionData['duration'],
          'is_active': true,
          'status': 'waiting', // Will be updated by client to: waiting/active/expired
          'session_duration': {
            'hours': sessionData['duration']['hours'],
            'minutes': sessionData['duration']['minutes'],
          }
        }
      });

      // Create attendance session record with only the required fields
      await client.from('attendance_sessions').insert({
        'lecturer_id': lecturerId,
        'unit_id': unitId,
        'qr_code_url': qrCodeUrl,
        'qr_code_data': qrCodeData,
        'backup_key': backupKey,
        'start_time': startTime.toIso8601String(),  // Keep UTC format for database
        'end_time': endTime.toIso8601String(),      // Keep UTC format for database
        'is_active': true,
        'session_data': updatedSessionData,
        'created_at': DateTime.now().toIso8601String(),
      });

    } catch (e) {
      print('Error creating attendance session: $e');
      rethrow;
    }
  }

  // Check session time status
  Map<String, dynamic> checkSessionTimeStatus(Map<String, dynamic> sessionData) {
    try {
      final now = DateTime.now();
      final date = sessionData['date'];
      final startTime = sessionData['start_time'];
      final endTime = sessionData['end_time'];

      // Create DateTime objects for comparison
      final dateParts = date.split('/');
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      final sessionDate = DateTime(
        int.parse(dateParts[2]),    // year
        int.parse(dateParts[1]),    // month
        int.parse(dateParts[0]),    // day
        int.parse(startParts[0]),   // start hour
        int.parse(startParts[1]),   // start minute
      );

      final sessionEndTime = DateTime(
        int.parse(dateParts[2]),    // year
        int.parse(dateParts[1]),    // month
        int.parse(dateParts[0]),    // day
        int.parse(endParts[0]),     // end hour
        int.parse(endParts[1]),     // end minute
      );

      String status;
      String message;
      bool isActive = false;

      if (now.isBefore(sessionDate)) {
        // Session hasn't started
        final diff = sessionDate.difference(now);
        status = 'waiting';
        message = 'Starting in ${diff.inMinutes} minutes';
        isActive = false;
      } else if (now.isAfter(sessionEndTime)) {
        // Session has ended
        status = 'expired';
        message = 'Session expired';
        isActive = false;
      } else {
        // Session is active
        final remaining = sessionEndTime.difference(now);
        status = 'active';
        message = '${remaining.inMinutes} minutes remaining';
        isActive = true;
      }

      return {
        'status': status,
        'message': message,
        'is_active': isActive,
        'start_time': startTime,
        'end_time': endTime,
        'date': date,
        'current_time': DateFormat('HH:mm').format(now),
      };
    } catch (e) {
      print('Error checking session status: $e');
      return {
        'status': 'error',
        'message': 'Could not determine session status',
        'is_active': false,
      };
    }
  }

  // Get session by ID
  Future<Map<String, dynamic>> getSessionById(String sessionId) async {
    try {
      final response = await client
          .from('attendance_sessions')
          .select()
          .eq('id', sessionId)
          .single();
      
      if (response == null) {
        return {'success': false, 'message': 'Session not found'};
      }

      return {'success': true, 'session': response};
    } catch (e) {
      print('Error getting session: $e');
      return {'success': false, 'message': 'Failed to get session'};
    }
  }

  // Mark attendance using backup key
  Future<Map<String, dynamic>> markAttendanceWithBackupKey({
    required String backupKey,
    required String studentEmail,
    required String department,
    required String course,
    required String year,
    required String semester,
  }) async {
    try {
      // First get the student ID
      final studentResponse = await client
          .from('users')
          .select('*, students(*)')
          .eq('email', studentEmail)
          .eq('user_type', 'student')
          .maybeSingle();
      
      if (studentResponse == null || studentResponse['students'] == null) {
        return {'success': false, 'message': 'Student not found'};
      }

      final studentId = studentResponse['students'][0]['id'];

      // Find active session with matching backup key
      final sessionResponse = await client
          .from('attendance_sessions')
          .select()
          .eq('backup_key', backupKey)
          .eq('is_active', true)
          .gte('end_time', DateTime.now().toIso8601String())
          .maybeSingle();

      if (sessionResponse == null) {
        return {'success': false, 'message': 'Invalid or expired backup key'};
      }

      // Check if attendance already marked
      final existingAttendance = await client
          .from('attendance')
          .select()
          .eq('session_id', sessionResponse['id'])
          .eq('student_id', studentId)
          .maybeSingle();

      if (existingAttendance != null) {
        return {'success': false, 'message': 'Attendance already marked'};
      }

      // Mark attendance
      await client
          .from('attendance')
          .insert({
            'session_id': sessionResponse['id'],
            'student_id': studentId,
            'time_scanned': DateTime.now().toIso8601String(),
          });

      return {
        'success': true,
        'message': 'Attendance marked successfully',
        'session_id': sessionResponse['id']
      };
    } catch (e) {
      print('Error marking attendance with backup key: $e');
      return {'success': false, 'message': 'Failed to mark attendance'};
    }
  }

  // Get available units for a student
  Future<List<Map<String, dynamic>>> getAvailableUnits({
    required String studentId,
    required String year,
    required String semester,
  }) async {
    try {
      final response = await client.rpc(
        'get_available_units',
        params: {
          'p_student_id': studentId,
          'p_year': year,
          'p_semester': semester,
        },
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting available units: $e');
      throw Exception('Failed to get available units: $e');
    }
  }

  // Register a unit for a student
  Future<String> registerUnit({
    required String studentId,
    required String unitId,
    required String year,
    required String semester,
  }) async {
    try {
      final response = await client.rpc(
        'register_unit',
        params: {
          'p_student_id': studentId,
          'p_unit_id': unitId,
          'p_year': year,
          'p_semester': semester,
        },
      );
      return response as String;
    } catch (e) {
      print('Error registering unit: $e');
      throw Exception('Failed to register unit: $e');
    }
  }

  // Get registered units for a student
  Future<List<Map<String, dynamic>>> getRegisteredUnits({
    required String studentId,
    required String year,
    required String semester,
  }) async {
    try {
      final response = await client
          .from('student_units')
          .select('''
            *,
            units (
              id,
              code,
              name,
              course_id,
              year,
              semester
            )
          ''')
          .eq('student_id', studentId)
          .eq('year', year)
          .eq('semester', semester)
          .eq('status', 'registered');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting registered units: $e');
      throw Exception('Failed to get registered units: $e');
    }
  }

  // Get student profile with current academic details
  Future<Map<String, dynamic>> getStudentProfile(String userId) async {
    try {
      final response = await _supabase
          .from('students')
          .select('''
            *,
            departments!inner (
              id,
              name
            ),
            academic_years!inner (
              id,
              year
            ),
            semesters!inner (
              id,
              name
            )
          ''')
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      throw Exception('Error fetching student profile: $e');
    }
  }

  // Debug function to check database content
  Future<void> debugCheckDatabaseContent() async {
    try {
      print('==================== DEBUG: Database Content Check ====================');
      
      // Check units table
      final units = await client.from('units').select('*');
      print('Units in database: ${units?.length ?? 0}');
      if (units != null && units.isNotEmpty) {
        print('Sample unit:');
        print(units.first);
      }

      // Check courses table
      final courses = await client.from('courses').select('*');
      print('Courses in database: ${courses?.length ?? 0}');
      if (courses != null && courses.isNotEmpty) {
        print('Sample course:');
        print(courses.first);
      }

      // Check departments table
      final departments = await client.from('departments').select('*');
      print('Departments in database: ${departments?.length ?? 0}');
      if (departments != null && departments.isNotEmpty) {
        print('Sample department:');
        print(departments.first);
      }

      print('==================== DEBUG: Database Check Complete ====================');
    } catch (e) {
      print('Error checking database content: $e');
    }
  }
} 
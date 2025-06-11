import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_schedule_service.dart';

class ScheduleService {
  final SupabaseScheduleService _supabaseService = SupabaseScheduleService();
  
  // Add getter for supabaseService
  SupabaseScheduleService get supabaseService => _supabaseService;

  // Get messages for a unit
  Future<List<Map<String, dynamic>>> getUnitMessages(String unitId) async {
    try {
      return await _supabaseService.getUnitMessages(unitId);
    } catch (e) {
      throw 'Failed to get unit messages: $e';
    }
  }

  // Send a new message
  Future<Map<String, dynamic>> sendMessage({
    required String unitId,
    required String message,
    required String lecturerId,
  }) async {
    try {
      return await _supabaseService.sendMessage(
        unitId: unitId,
        message: message,
        lecturerId: lecturerId,
      );
    } catch (e) {
      throw 'Failed to send message: $e';
    }
  }

  // Update an existing message
  Future<void> updateMessage({
    required String messageId,
    required String message,
  }) async {
    try {
      await _supabaseService.updateMessage(
        messageId: messageId,
        message: message,
      );
    } catch (e) {
      throw 'Failed to update message: $e';
    }
  }

  // Delete a message
  Future<void> deleteMessage({
    required String messageId,
  }) async {
    try {
      await _supabaseService.deleteMessage(
        messageId: messageId,
      );
    } catch (e) {
      throw 'Failed to delete message: $e';
    }
  }

  // Get read receipts for a message
  Future<Map<String, dynamic>> getMessageReadReceipts(String messageId) async {
    try {
      return await _supabaseService.getMessageReadReceipts(messageId);
    } catch (e) {
      throw 'Failed to get read receipts: $e';
    }
  }

  // Get lecturer's assigned units
  Future<List<Map<String, dynamic>>> getLecturerUnits(String lecturerId) async {
    try {
      return await _supabaseService.getLecturerUnits(lecturerId);
    } catch (e) {
      throw 'Failed to get lecturer units: $e';
    }
  }

  // Assign test units to lecturer
  Future<void> assignTestUnits(String lecturerId) async {
    try {
      await _supabaseService.assignTestUnits(lecturerId);
    } catch (e) {
      throw 'Failed to assign test units: $e';
    }
  }

  // Get student's registered units from student_registered_units table
  Future<List<Map<String, dynamic>>> getStudentUnits(String studentId) async {
    try {
      print('Getting units for student: $studentId');
      final response = await _supabaseService.client
          .from('student_registered_units')
          .select('''
            *,
            unit_id,
            unit_code,
            unit_name,
            department,
            course_name,
            year,
            semester
          ''')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      
      print('Response from student_registered_units: $response');
      
      if (response == null || response.isEmpty) {
        print('No units found in student_registered_units, trying student_units');
        // Try student_units table as fallback
        final fallbackResponse = await _supabaseService.client
            .from('student_units')
            .select('''
              *,
              unit_id,
              unit_code,
              unit_name,
              department,
              course_name,
              year,
              semester
            ''')
            .eq('student_id', studentId)
            .order('created_at', ascending: false);
            
        print('Response from student_units: $fallbackResponse');
        
        if (fallbackResponse == null || fallbackResponse.isEmpty) {
          print('No units found in either table for student: $studentId');
          return [];
        }
        
        return List<Map<String, dynamic>>.from(fallbackResponse);
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting student units: $e');
      return [];
    }
  }
} 
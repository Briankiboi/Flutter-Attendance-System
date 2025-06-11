import 'package:supabase_flutter/supabase_flutter.dart';
import 'schedule_service.dart';

class SupabaseScheduleService {
  final SupabaseClient client = Supabase.instance.client;

  // Get messages for a unit
  Future<List<Map<String, dynamic>>> getUnitMessages(String unitId) async {
    try {
      print('Getting messages for unit: $unitId');
      
      final response = await client
          .from('schedule_messages')
          .select('''
            id,
            content,
            created_at,
            schedule_date,
            unit:unit_id (
              id,
              code,
              name
            ),
            message_read_status (
              id,
              read_at,
              student:student_id (
                id,
                user:user_id (
                  name
                )
              )
            )
          ''')
          .eq('unit_id', unitId)
          .order('created_at', ascending: false);
      
      print('Messages response: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting unit messages: $e');
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
      print('Sending message for unit: $unitId');
      
      final response = await client
          .from('schedule_messages')
          .insert({
            'unit_id': unitId,
            'content': message,
            'lecturer_id': lecturerId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'schedule_date': DateTime.now().toIso8601String().split('T')[0],
          })
          .select()
          .single();
      
      print('Message sent: $response');
      return response;
    } catch (e) {
      print('Error sending message: $e');
      throw 'Failed to send message: $e';
    }
  }

  // Update an existing message
  Future<void> updateMessage({
    required String messageId,
    required String message,
  }) async {
    try {
      print('Updating message: $messageId');
      
      await client
          .from('schedule_messages')
          .update({'content': message})
          .eq('id', messageId);
      
      print('Message updated successfully');
    } catch (e) {
      print('Error updating message: $e');
      throw 'Failed to update message: $e';
    }
  }

  // Delete a message
  Future<void> deleteMessage({
    required String messageId,
  }) async {
    try {
      print('Deleting message: $messageId');
      
      await client
          .from('schedule_messages')
          .delete()
          .eq('id', messageId);
      
      print('Message deleted successfully');
    } catch (e) {
      print('Error deleting message: $e');
      throw 'Failed to delete message: $e';
    }
  }

  // Get read receipts for a message
  Future<Map<String, dynamic>> getMessageReadReceipts(String messageId) async {
    try {
      print('Getting read receipts for message: $messageId');
      
      final message = await client
          .from('schedule_messages')
          .select('''
            id,
            content,
            created_at,
            message_type,
            is_important,
            media_url,
            schedule_date,
            unit:unit_id (
              id,
              code,
              name,
              year,
              semester
            ),
            message_read_status (
              id,
              read_at,
              device_info,
              student:student_id (
                id,
                user:user_id (
                  id,
                  email,
                  name
                ),
                department,
                course,
                year,
                semester
              )
            )
          ''')
          .eq('id', messageId)
          .single();
      
      // Get total students for this unit
      final totalStudentsResponse = await client
          .rpc('get_unit_student_count', params: {
            'p_unit_id': message['unit_id']
          });

      print('Read receipts fetched successfully');
      return {
        'message': message,
        'total_students': totalStudentsResponse[0]['count'],
        'receipts': message['message_read_status'] ?? [],
      };
    } catch (e) {
      print('Error getting read receipts: $e');
      throw 'Failed to get read receipts: $e';
    }
  }

  // Get lecturer's assigned units
  Future<List<Map<String, dynamic>>> getLecturerUnits(String lecturerId) async {
    try {
      print('Getting units for lecturer: $lecturerId');
      
      final response = await client
          .from('lecturer_assigned_units')
          .select('''
            unit_id,
            unit_code,
            unit_name,
            department,
            course_name,
            year,
            semester
          ''')
          .eq('lecturer_id', lecturerId)
          .order('unit_code');
      
      print('Found units: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting lecturer units: $e');
      throw 'Failed to get lecturer units: $e';
    }
  }

  // Assign test units to lecturer
  Future<void> assignTestUnits(String lecturerId) async {
    try {
      print('Assigning test units to lecturer: $lecturerId');
      
      // First get lecturer details
      final lecturer = await client
          .from('lecturers')
          .select('id, name, email, department')
          .eq('id', lecturerId)
          .single();
      print('Found lecturer: $lecturer');

      // Get some units from the units table
      final units = await client
          .from('units')
          .select('id, code, name')
          .limit(3);
      print('Found units to assign: $units');

      if (units == null || (units as List).isEmpty) {
        print('No units found to assign');
        return;
      }

      // Assign each unit to the lecturer
      for (final unit in units) {
        try {
          await client
              .from('lecturer_assigned_units')
              .insert({
                'lecturer_id': lecturerId,
                'unit_code': unit['code'],
                'unit_name': unit['name'],
                'department': lecturer['department'],
                'course_name': 'Test Course',
                'year': '2024',
                'semester': '1',
              })
              .select();
          print('Assigned unit ${unit['code']} to lecturer');
        } catch (e) {
          print('Error assigning unit ${unit['code']}: $e');
          // Continue with next unit
        }
      }
    } catch (e) {
      print('Error assigning test units: $e');
      throw 'Failed to assign test units: $e';
    }
  }
} 
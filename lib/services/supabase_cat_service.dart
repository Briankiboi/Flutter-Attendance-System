import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cat_result.dart';
import '../models/excel_import.dart';

class SupabaseCatService {
  final SupabaseClient client = Supabase.instance.client;

  // Student Operations
  Future<List<CatResult>> getStudentCatResults(String studentId) async {
    try {
      final response = await client
          .from('cat_results')
          .select()
          .eq('student_id', studentId);
      
      return (response as List).map((json) => CatResult.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to get student CAT results: $e';
    }
  }

  Future<Map<String, dynamic>> getStudentPerformanceStats(String studentId) async {
    try {
      final response = await client.rpc(
        'get_student_cat_stats',
        params: {'p_student_id': studentId}
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      throw 'Failed to get student performance stats: $e';
    }
  }

  // Lecturer Operations
  Future<List<Map<String, dynamic>>> getLecturerUnits(String lecturerId) async {
    try {
      final response = await client
          .from('lecturer_units')
          .select('unit_id, units(id, name)')
          .eq('lecturer_id', lecturerId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to get lecturer units: $e';
    }
  }

  Future<List<Map<String, dynamic>>> searchUnitStudents(
    String unitId,
    String searchTerm,
  ) async {
    try {
      final response = await client.rpc(
        'search_unit_students',
        params: {
          'p_unit_id': unitId,
          'p_search_term': searchTerm,
        }
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to search unit students: $e';
    }
  }

  // CAT Results Operations
  Future<CatResult> saveCatResult(CatResult result) async {
    try {
      final response = await client
          .from('cat_results')
          .upsert(result.toJson())
          .select()
          .single();
      
      return CatResult.fromJson(response);
    } catch (e) {
      throw 'Failed to save CAT result: $e';
    }
  }

  Future<void> bulkSaveCatResults(List<CatResult> results) async {
    try {
      final data = results.map((r) => r.toJson()).toList();
      await client.from('cat_results').upsert(data);
    } catch (e) {
      throw 'Failed to bulk save CAT results: $e';
    }
  }

  Future<void> finalizeCatResults(
    String unitId,
    String lecturerId,
    CatType catType,
  ) async {
    try {
      // Update all draft marks to final status for the given unit and lecturer
      await client
          .from('cat_results')
          .update({
            'status': 'final',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('unit_id', unitId)
          .eq('lecturer_id', lecturerId)
          .eq('cat_number', catType.toString().split('.').last)
          .eq('status', 'draft');
    } catch (e) {
      throw 'Failed to finalize CAT results: $e';
    }
  }

  // Added missing methods
  Future<CatResult?> getCatResult(String id) async {
    try {
      final response = await client
          .from('cat_results')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      return response == null ? null : CatResult.fromJson(response);
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST116') {
        return null; // Record not found
      }
      throw 'Failed to get CAT result: $e';
    }
  }

  Future<List<CatResult>> getUnitResults(String unitId) async {
    try {
      final response = await client
          .from('cat_results')
          .select()
          .eq('unit_id', unitId)
          .order('created_at');
      
      return (response as List).map((json) => CatResult.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to get unit results: $e';
    }
  }

  Future<List<CatResult>> getLecturerResults(String lecturerId) async {
    try {
      final response = await client
          .from('cat_results')
          .select()
          .eq('lecturer_id', lecturerId)
          .order('created_at');
      
      return (response as List).map((json) => CatResult.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to get lecturer results: $e';
    }
  }

  // Excel Import Operations
  Future<ExcelImport> createExcelImport(ExcelImport import) async {
    try {
      final response = await client
          .from('cat_excel_imports')
          .insert(import.toJson())
          .select()
          .single();
      
      return ExcelImport.fromJson(response);
    } catch (e) {
      throw 'Failed to create Excel import: $e';
    }
  }

  Future<void> updateExcelImportStatus(
    String importId,
    String status,
    int processedCount,
    int totalCount, [
    Map<String, dynamic>? errorLog,
  ]) async {
    try {
      await client.from('cat_excel_imports').update({
        'status': status,
        'processed_count': processedCount,
        'total_count': totalCount,
        if (errorLog != null) 'error_log': errorLog,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', importId);
    } catch (e) {
      throw 'Failed to update Excel import status: $e';
    }
  }

  Future<ExcelImport?> getExcelImportStatus(String importId) async {
    try {
      final response = await client
          .from('cat_excel_imports')
          .select()
          .eq('id', importId)
          .single();
      
      return ExcelImport.fromJson(response);
    } catch (e) {
      throw 'Failed to get Excel import status: $e';
    }
  }

  // Storage Operations
  Future<String> uploadExcelFile(String filePath, Uint8List bytes) async {
    try {
      await client
          .storage
          .from('cat_imports')
          .uploadBinary(filePath, bytes);
      
      return client
          .storage
          .from('cat_imports')
          .getPublicUrl(filePath);
    } catch (e) {
      throw 'Failed to upload Excel file: $e';
    }
  }

  Future<Uint8List> downloadExcelFile(String filePath) async {
    try {
      return await client
          .storage
          .from('cat_imports')
          .download(filePath);
    } catch (e) {
      throw 'Failed to download Excel file: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getUnitStudents(String unitId) async {
    try {
      print('Attempting to fetch students with unit_id: $unitId');
      
      // First attempt: Try student_registered_units with unit_id
      var response = await client
          .from('student_registered_units')
          .select('''
            *,
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
            ),
            unit:unit_id (
              id,
              code,
              name
            )
          ''')
          .eq('unit_id', unitId);
      
      var students = List<Map<String, dynamic>>.from(response);
      print('Found ${students.length} students using unit_id');
      
      if (students.isEmpty) {
        // Second attempt: Get unit details first
        final unitDetails = await client
            .from('units')
            .select('id, code, name')
            .eq('id', unitId)
            .single();
            
        print('Found unit details: $unitDetails');
        
        // Try using unit_code
        response = await client
            .from('student_registered_units')
            .select('''
              *,
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
              ),
              unit:unit_id (
                id,
                code,
                name
              )
            ''')
            .eq('unit_code', unitDetails['code']);
            
        students = List<Map<String, dynamic>>.from(response);
        print('Found ${students.length} students using unit_code');
        
        if (students.isEmpty) {
          // Third attempt: Try using a more flexible year/semester format
          final yearSemester = unitDetails['code'].substring(2); // e.g., "422" from "CE422"
          final year = yearSemester[0];
          final semester = yearSemester[2];
          
          response = await client
              .from('student_registered_units')
              .select('''
                *,
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
                ),
                unit:unit_id (
                  id,
                  code,
                  name
                )
              ''')
              .eq('year', 'Year $year')
              .eq('semester', 'Semester $semester');
              
          students = List<Map<String, dynamic>>.from(response);
          print('Found ${students.length} students using year/semester');
        }
      }
      
      return students;
    } catch (e) {
      print('Error fetching students: $e');
      throw 'Failed to get unit students: $e';
    }
  }

  // Verify student registrations
  Future<void> verifyStudentRegistrations(String unitId) async {
    try {
      print('Verifying student registrations for unit: $unitId');
      
      // Get unit details with department info
      final unitDetails = await client
          .from('units')
          .select('''
            *,
            department:department_id (
              id,
              name
            )
          ''')
          .eq('id', unitId)
          .single();
      
      print('Unit details: $unitDetails');
      
      // Get all students in the same department and year
      final unitCode = unitDetails['code'] as String;
      final year = 'Year ${unitCode[2]}';  // e.g., "4" from "CE422"
      final semester = 'Semester ${unitCode[4]}';  // e.g., "2" from "CE422"
      final departmentId = unitDetails['department_id'];
      
      print('Checking for students in $year, $semester, department_id: $departmentId');
      
      final students = await client
          .from('students')
          .select('''
            id,
            user_id,
            user:user_id (
              id,
              email,
              name
            )
          ''')
          .eq('department_id', departmentId)
          .eq('year', year)
          .eq('semester', semester);
          
      print('Found ${students.length} potential students');
      
      // Check and register each student
      for (var student in students) {
        try {
          final existing = await client
              .from('student_registered_units')
              .select()
              .eq('student_id', student['id'])
              .eq('unit_id', unitId)
              .maybeSingle();
              
          if (existing == null) {
            print('Registering student ${student['id']} for unit $unitId');
            
            await client
                .from('student_registered_units')
                .upsert({
                  'student_id': student['id'],
                  'unit_id': unitId,
                  'unit_code': unitCode,
                  'unit_name': unitDetails['name'],
                  'year': year,
                  'semester': semester,
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                });
                
            print('Successfully registered student ${student['id']}');
          } else {
            print('Student ${student['id']} already registered for unit $unitId');
          }
        } catch (studentError) {
          print('Error registering individual student ${student['id']}: $studentError');
          // Continue with next student instead of failing completely
          continue;
        }
      }
      
      print('Student registration verification complete');
    } catch (e) {
      print('Error verifying student registrations: $e');
      throw 'Failed to verify student registrations: $e';
    }
  }
} 
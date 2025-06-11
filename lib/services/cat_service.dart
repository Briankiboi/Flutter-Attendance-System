import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path/path.dart';
import '../models/cat_result.dart';
import '../models/excel_import.dart';
import 'supabase_cat_service.dart';

enum MarkStatus { draft, final_mark }

class CatService {
  final SupabaseCatService _supabaseService = SupabaseCatService();
  
  // Add getter for supabaseService
  SupabaseCatService get supabaseService => _supabaseService;

  // Get registered students for a unit
  Future<List<Map<String, dynamic>>> getRegisteredStudents(String unitId) async {
    try {
      final response = await _supabaseService.client
          .rpc('get_registered_students', 
          params: {
            'p_unit_id': unitId as Object,
          });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to get registered students: $e';
    }
  }

  // Save or update CAT mark
  Future<void> saveMark({
    required String unitId,
    required String studentId,
    required String lecturerId,
    required CatType catType,
    required double marks,
    String? comments,
  }) async {
    try {
      final result = CatResult(
        unitId: unitId,
        studentId: studentId,
        lecturerId: lecturerId,
        catType: catType,
        marks: marks,
        comments: comments,
        status: MarkStatus.draft.toString().split('.').last,
      );
      await _supabaseService.saveCatResult(result);
    } catch (e) {
      throw 'Failed to save mark: $e';
    }
  }

  // Get CAT results for a student in a unit
  Future<List<CatResult>> getStudentResults(String studentId, String unitId) async {
    try {
      final results = await _supabaseService.getStudentCatResults(studentId);
      return results.where((result) => result.unitId == unitId).toList();
    } catch (e) {
      throw 'Failed to get student results: $e';
    }
  }

  // Get all CAT results for a unit (lecturer view)
  Future<List<CatResult>> getUnitResults(String unitId, String lecturerId) async {
    try {
      final results = await _supabaseService.getLecturerResults(lecturerId);
      return results.where((result) => result.unitId == unitId).toList();
    } catch (e) {
      throw 'Failed to get unit results: $e';
    }
  }

  // Search students in a unit
  Future<List<Map<String, dynamic>>> searchStudents(
    String unitId,
    String searchTerm,
  ) async {
    try {
      return await _supabaseService.searchUnitStudents(unitId, searchTerm);
    } catch (e) {
      throw 'Failed to search students: $e';
    }
  }

  // Finalize CAT marks (change status from draft to final)
  Future<void> finalizeMarks(
    String unitId,
    String lecturerId,
    CatType catType,
  ) async {
    try {
      await _supabaseService.finalizeCatResults(unitId, lecturerId, catType);
    } catch (e) {
      throw 'Failed to finalize marks: $e';
    }
  }

  // Get student list for a unit
  Future<List<Map<String, dynamic>>> getUnitStudents(String unitId) async {
    try {
      return await _supabaseService.getUnitStudents(unitId);
    } catch (e) {
      throw 'Failed to get unit students: $e';
    }
  }

  // Single Operations
  Future<CatResult> createCatResult({
    required String unitId,
    required String studentId,
    required String lecturerId,
    required CatType catType,
    required double marks,
    String? comments,
  }) async {
    final result = CatResult(
      unitId: unitId,
      studentId: studentId,
      lecturerId: lecturerId,
      catType: catType,
      marks: marks,
      comments: comments,
      status: MarkStatus.draft.toString().split('.').last,
    );

    return await _supabaseService.saveCatResult(result);
  }

  Future<CatResult> updateCatResult({
    required String id,
    required double marks,
    String? comments,
  }) async {
    final existingResult = await _supabaseService.getCatResult(id);
    if (existingResult == null) {
      throw 'CAT result not found';
    }

    final updatedResult = existingResult.copyWith(
      marks: marks,
      comments: comments,
    );

    return await _supabaseService.saveCatResult(updatedResult);
  }

  Future<List<CatResult>> getCatResults(String unitId) async {
    try {
      final results = await _supabaseService.getUnitResults(unitId);
      return results.where((result) => result.unitId == unitId).toList();
    } catch (e) {
      throw 'Failed to get CAT results: $e';
    }
  }

  Future<List<CatResult>> getLecturerResults(String lecturerId) async {
    try {
      return await _supabaseService.getLecturerResults(lecturerId);
    } catch (e) {
      throw 'Failed to get lecturer results: $e';
    }
  }

  // Note: Excel-related functionality is temporarily disabled
  // Will be implemented in a future update
} 
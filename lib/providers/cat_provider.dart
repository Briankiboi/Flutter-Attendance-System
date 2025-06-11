import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cat_result.dart';
import '../models/excel_import.dart';
import '../services/cat_service.dart';

class CatProvider extends ChangeNotifier {
  final CatService _catService = CatService();
  final _supabase = Supabase.instance.client;
  
  // State variables
  bool _isLoading = false;
  String? _error;
  List<CatResult> _results = [];
  Map<String, List<CatResult>> _resultsByUnit = {};
  ExcelImport? _activeImport;
  String? _selectedUnitId;
  String? _lecturerId;
  CatType _selectedCatType = CatType.CAT1;
  int _currentPage = 1;
  final int _pageSize = 50;
  String _searchQuery = '';

  CatProvider() {
    _initializeLecturerId();
  }

  Future<void> _initializeLecturerId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final lecturer = await _supabase
            .from('lecturers')
            .select()
            .eq('user_id', user.id)
            .single();
        _lecturerId = lecturer['id'];
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to initialize lecturer: $e';
      notifyListeners();
    }
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CatResult> get results => _results;
  Map<String, List<CatResult>> get resultsByUnit => _resultsByUnit;
  ExcelImport? get activeImport => _activeImport;
  String? get selectedUnitId => _selectedUnitId;
  String? get lecturerId => _lecturerId;
  CatType get selectedCatType => _selectedCatType;
  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  String get searchQuery => _searchQuery;

  // Methods
  void setSelectedUnit(String unitId) {
    _selectedUnitId = unitId;
    notifyListeners();
    loadResults();
  }

  void setSelectedCatType(CatType type) {
    _selectedCatType = type;
    notifyListeners();
    loadResults();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1;
    notifyListeners();
    loadResults();
  }

  void nextPage() {
    _currentPage++;
    notifyListeners();
    loadResults();
  }

  void previousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      notifyListeners();
      loadResults();
    }
  }

  Future<void> loadResults() async {
    if (_selectedUnitId == null || _lecturerId == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final results = await _catService.getUnitResults(_selectedUnitId!, _lecturerId!);
      
      // Filter by CAT type
      _results = results.where((r) => r.catType == _selectedCatType).toList();
      
      // Group by unit
      _resultsByUnit.clear();
      for (var result in _results) {
        if (!_resultsByUnit.containsKey(result.unitId)) {
          _resultsByUnit[result.unitId] = [];
        }
        _resultsByUnit[result.unitId]!.add(result);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveMark({
    required String studentId,
    required double marks,
    String? comments,
  }) async {
    if (_selectedUnitId == null || _lecturerId == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _catService.saveMark(
        unitId: _selectedUnitId!,
        studentId: studentId,
        lecturerId: _lecturerId!,
        catType: _selectedCatType,
        marks: marks,
        comments: comments,
      );

      await loadResults();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> importFromExcel(File file) async {
    if (_selectedUnitId == null || _lecturerId == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _activeImport = await _catService.importFromExcel(
        file: file,
        unitId: _selectedUnitId!,
        lecturerId: _lecturerId!,
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> exportToExcel() async {
    if (_selectedUnitId == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _catService.exportToExcel(_selectedUnitId!);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> finalizeMarks() async {
    if (_selectedUnitId == null || _lecturerId == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _catService.finalizeMarks(
        _selectedUnitId!,
        _lecturerId!,
        _selectedCatType,
      );

      await loadResults();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearActiveImport() {
    _activeImport = null;
    notifyListeners();
  }
} 
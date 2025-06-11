import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cat_result.dart';
import 'dart:async';

class CatGridWidget extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final CatType selectedCatType;
  final Function(String, double) onMarkSaved;
  final bool isLoading;
  final String searchQuery;

  const CatGridWidget({
    Key? key,
    required this.students,
    required this.selectedCatType,
    required this.onMarkSaved,
    required this.isLoading,
    this.searchQuery = '',
  }) : super(key: key);

  @override
  State<CatGridWidget> createState() => _CatGridWidgetState();
}

class _CatGridWidgetState extends State<CatGridWidget> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _isSaving = {};
  final Map<String, bool> _hasError = {};
  final Map<String, String?> _errorMessages = {};
  Timer? _debounceTimer;
  int _currentSheet = 0;
  static const int _studentsPerSheet = 100;
  final ScrollController _horizontalScrollController = ScrollController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredStudents = [];
  int _maxSheets = 10; // Support up to 1000 students (10 sheets * 100 students)

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _filteredStudents = widget.students;
    _updateSearchResults();
  }

  @override
  void didUpdateWidget(CatGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.students != oldWidget.students) {
      _initializeControllers();
      // Only update filteredStudents if not searching
      if (widget.searchQuery.isEmpty) {
        setState(() {
          _filteredStudents = widget.students;
        });
      } else {
        _updateSearchResults();
      }
    }
    
    if (widget.searchQuery != oldWidget.searchQuery) {
      _searchQuery = widget.searchQuery;
      _updateSearchResults();
    }
  }

  void _updateSearchResults() {
    final query = widget.searchQuery.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStudents = widget.students;
      } else {
        _filteredStudents = widget.students.where((student) {
          final regNumber = student['registration_number'].toString().toLowerCase();
          final name = student['student_name'].toString().toLowerCase();
          return regNumber.contains(query) || name.contains(query);
        }).toList();
      }
      _currentSheet = 0;  // Reset to first sheet when searching
    });
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    _debounceTimer?.cancel();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  bool _isValidMark(String value) {
    if (value.isEmpty) return true;
    final mark = double.tryParse(value);
    if (mark == null) return false;
    if (mark < 0 || mark > 15) return false;
    // Check if mark ends in .0 or .5
    final decimal = mark - mark.floor();
    return decimal == 0 || decimal == 0.5;
  }

  String? _getErrorMessage(String value) {
    if (value.isEmpty) return null;
    final mark = double.tryParse(value);
    if (mark == null) return 'Invalid mark';
    if (mark < 0 || mark > 15) return '≤ 15';
    final decimal = mark - mark.floor();
    if (decimal != 0 && decimal != 0.5) return '.0 or .5 only';
    return null;
  }

  void _initializeControllers() {
    // Clear any controllers for students that are no longer in the list
    _controllers.removeWhere((studentId, _) => 
      !widget.students.any((s) => s['student_id'] == studentId));

    // Update or create controllers for current students
    for (var student in widget.students) {
      final studentId = student['student_id'] as String;
      final marks = student['marks'] as String?;
      
      if (!_controllers.containsKey(studentId)) {
        final controller = TextEditingController(text: marks ?? '');
        controller.addListener(() {
          _validateAndSaveMark(studentId, controller);
        });
        _controllers[studentId] = controller;
        _hasError[studentId] = false;
        _errorMessages[studentId] = null;
        _isSaving[studentId] = false;
      } else if (_controllers[studentId]!.text != marks && !(_isSaving[studentId] ?? false)) {
        // Only update if the value is different and not currently saving
        _controllers[studentId]!.text = marks ?? '';
      }
    }
  }

  void _validateAndSaveMark(String studentId, TextEditingController controller) {
    final errorMessage = _getErrorMessage(controller.text);
    setState(() {
      _hasError[studentId] = errorMessage != null;
      _errorMessages[studentId] = errorMessage;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_isValidMark(controller.text)) {
        final mark = double.tryParse(controller.text);
        if (mark != null && mark >= 0 && mark <= 15) {
          setState(() => _isSaving[studentId] = true);
          widget.onMarkSaved(studentId, mark).then((_) {
            if (mounted) {
              setState(() => _isSaving[studentId] = false);
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total number of sheets based on student count
    final totalStudents = _filteredStudents.length;
    final totalSheets = (totalStudents / _studentsPerSheet).ceil().clamp(1, _maxSheets);
    
    // Calculate start and end indices for current sheet
    final startIndex = _currentSheet * _studentsPerSheet;
    final endIndex = (startIndex + _studentsPerSheet < totalStudents) 
        ? startIndex + _studentsPerSheet 
        : totalStudents;
    
    // Get students for current sheet only (better memory usage)
    final currentStudents = _filteredStudents.isEmpty 
        ? [] 
        : _filteredStudents.sublist(startIndex, endIndex);
    
    final bool hasSelectedUnit = widget.students.isNotEmpty || widget.isLoading;
    final tableWidth = 540.0; // Total width of the table (sum of column widths)

    return Column(
      children: [
        // Results count when searching
        if (_searchQuery.isNotEmpty && hasSelectedUnit)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Found ${_filteredStudents.length} students',
              style: TextStyle(
                color: _filteredStudents.isEmpty ? Colors.red : Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
        // Main content - Wrapped in a Card
        Expanded(
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: hasSelectedUnit 
              ? _filteredStudents.isEmpty && _searchQuery.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'No students matching "$_searchQuery"',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
    return SingleChildScrollView(
                        controller: _horizontalScrollController,
      scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                            children: [
                              // Header row that scrolls horizontally with data
                              Container(
                                color: const Color(0xFFE6F3E7), // Light green background
                                child: Row(
                                  children: [
                                    _buildHeaderCell('#', width: 40),
                                    _buildHeaderCell('Reg Number', width: 150),
                                    _buildHeaderCell('Name', width: 150),
                                    _buildHeaderCell('Marks', width: 100),
                                    _buildHeaderCell('Status', width: 100),
                                  ],
                                ),
                              ),
                              
                              // Data rows
                              Expanded(
                                child: ListView.builder(
                                  itemCount: currentStudents.isEmpty 
                                    ? _studentsPerSheet // Empty template rows
                                    : currentStudents.length, // Only actual data
                                  itemBuilder: (context, index) {
                                    final rowIndex = startIndex + index + 1;
                                    final hasData = index < currentStudents.length;
                                    final student = hasData ? currentStudents[index] : null;
                                    return _buildDataRow(student, rowIndex);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 75),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart, size: 36, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('Please select a unit to view students',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        ),
        
        // Total student count indicator
        if (totalStudents > 0 && hasSelectedUnit)
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Total: $totalStudents students (${startIndex + 1}-$endIndex shown)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        
        // Sheet tabs - preserve original style as requested
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              // Sheet tabs
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: totalSheets,
                  itemBuilder: (context, index) {
                    final startNum = (index * _studentsPerSheet) + 1;
                    final endNum = ((index + 1) * _studentsPerSheet) > totalStudents 
                        ? totalStudents 
                        : ((index + 1) * _studentsPerSheet);
                    return _buildSheetTab(index, totalSheets, startNum, endNum);
                  },
                ),
              ),
              // Add sheet button (disabled but shown for UI completeness)
              Container(
                width: 24,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Icon(Icons.add, size: 16, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {required double width}) {
    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F7246), // Excel-like green
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic>? student, int rowIndex) {
    // Using const for optimization of empty cells
    final bool hasData = student != null;
    final studentId = hasData ? student['student_id'] as String : '';
    final controller = hasData ? _controllers[studentId]! : TextEditingController();
    final isCurrentlySaving = hasData ? (_isSaving[studentId] ?? false) : false;
    final showError = hasData ? (_hasError[studentId] ?? false) : false;
    final errorMessage = hasData ? _errorMessages[studentId] : null;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: rowIndex.isEven ? Colors.grey.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // Row number
          Container(
            width: 40,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Center(
              child: Text(
                rowIndex.toString(),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          // Registration number
          Container(
            width: 150,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: hasData 
                ? Text(
                    student['registration_number'] as String,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            ),
          ),
          
          // Name
          Container(
            width: 150,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: hasData 
                ? Text(
                    student['student_name'] as String,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            ),
          ),
          
          // Marks - improved styling for the mark input
          Container(
            width: 100,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Center(
              child: hasData 
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: showError 
                            ? Border.all(color: Colors.red.shade300, width: 1.0)
                            : Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: showError ? Colors.red : Colors.blue.shade800,
                            fontFamily: 'Consolas',
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            isDense: true,
                            border: InputBorder.none,
                            errorStyle: const TextStyle(height: 0),
                            helperText: errorMessage,
                            helperStyle: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 10,
                            ),
                          ),
                        inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d?')),
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              if (newValue.text.isEmpty) return newValue;
                              final mark = double.tryParse(newValue.text);
                              if (mark == null) return oldValue;
                              if (mark > 15) return oldValue;
                              final decimal = mark - mark.floor();
                              if (decimal != 0 && decimal != 0.5) return oldValue;
                              return newValue;
                            }),
                          ],
                        ),
                      ),
                      if (isCurrentlySaving)
                        Positioned(
                          right: 8,
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    ],
                  )
                : Container(
                    width: 80,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
            ),
          ),
          
          // Status - keeping the original styling as requested
                    Container(
            width: 100,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Center(
              child: hasData 
                ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                      color: student['status'] == 'final' 
                            ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                      (student['status'] as String).toUpperCase(),
                        style: TextStyle(
                        color: student['status'] == 'final' ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                          fontSize: 12,
                      ),
                    ),
                  )
                : null,
            ),
          ),
        ],
                                ),
                              );
                            }

  Widget _buildSheetTab(int index, int totalSheets, int startNum, int endNum) {
    final isSelected = index == _currentSheet;
    return GestureDetector(
      onTap: () {
        setState(() => _currentSheet = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey.shade100,
          border: Border(
            right: BorderSide(color: Colors.grey.shade300),
            top: BorderSide(
              color: isSelected ? const Color(0xFF1F7246) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          'Sheet ${index + 1} ($startNum-$endNum)',
          style: TextStyle(
            color: isSelected ? const Color(0xFF1F7246) : Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/cat_result.dart';
import '../../services/cat_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/excel_upload_widget.dart';
import '../../widgets/import_progress_widget.dart';
import '../../widgets/cat_grid_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class CatMarksEntryPage extends StatefulWidget {
  const CatMarksEntryPage({super.key});

  @override
  State<CatMarksEntryPage> createState() => _CatMarksEntryPageState();
}

class _CatMarksEntryPageState extends State<CatMarksEntryPage> {
  final CatService _catService = CatService();
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  
  String? _lecturerId;
  String? _selectedUnitCode;
  String? _selectedUnitId;
  Map<String, dynamic>? _selectedUnit;
  CatType _selectedCatType = CatType.CAT1;
  
  List<Map<String, dynamic>> _students = [];
  Map<String, String> _markStatus = {};
  bool _isLoading = false;
  String? _activeImportId;
  bool _hasUnfinalizedMarks = false;
  Color _finalizeButtonColor = Colors.grey;
  String _finalizeButtonText = 'No Drafts to Finalize';
  bool _canFinalize = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeLecturerData();
  }

  Future<void> _initializeLecturerData() async {
    print('Initializing lecturer data...');
    setState(() => _isLoading = true);
    
    try {
      // Get cached user data first
      final userData = _supabaseService.getCurrentUser();
      print('Cached user data: $userData');
      
      if (userData != null && userData['lecturer_id'] != null) {
        print('Found lecturer_id in cached data: ${userData['lecturer_id']}');
        setState(() => _lecturerId = userData['lecturer_id']);
        return;
      }

      // Fallback to getting data from Supabase if cache miss
    final user = _supabase.auth.currentUser;
      print('Current user: ${user?.email}');
      
    if (user != null) {
        // Try to get lecturer by user_id first
        print('Trying to get lecturer by user_id: ${user.id}');
        var lecturer = await _supabase
          .from('lecturers')
            .select('id, name, email')
          .eq('user_id', user.id)
            .maybeSingle();
            
        print('Lecturer by user_id result: $lecturer');
            
        // If not found, try by email
        if (lecturer == null && user.email != null) {
          print('Trying to get lecturer by email: ${user.email}');
          lecturer = await _supabase
              .from('lecturers')
              .select('id, name, email')
              .eq('email', user.email as Object)
              .maybeSingle();
          print('Lecturer by email result: $lecturer');
        }
            
        if (!mounted) return;
        
        final lecturerId = lecturer?['id'] as String?;
        print('Final lecturer ID: $lecturerId');
        
        if (lecturerId != null) {
          // Update both state and cache
          setState(() => _lecturerId = lecturerId);
          _supabaseService.updateCurrentUserCache({
            'lecturer_id': lecturerId
          });
          print('Lecturer ID set successfully');
        } else {
          print('No lecturer ID found');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lecturer profile not found. Please contact support.')),
          );
        }
      } else {
        print('No user logged in');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in again')),
          );
          // TODO: Navigate to login screen if needed
        }
      }
    } catch (e) {
      print('Error loading lecturer data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lecturer data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchStudents() async {
    if (_selectedUnitId == null || _lecturerId == null) {
      setState(() {
        _students = [];
        _isLoading = false;
      });
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      await _catService.supabaseService.verifyStudentRegistrations(_selectedUnitId!);
      final studentsResponse = await _catService.getUnitStudents(_selectedUnitId!);

      // Get existing CAT results with explicit ordering and status check
      final catResults = await _supabase
          .from('cat_results')
          .select()
          .eq('unit_id', _selectedUnitId!)
          .eq('cat_number', _selectedCatType == CatType.CAT1 ? 'CAT1' : 'CAT2')
          .order('updated_at', ascending: false); // Get latest status first
      
      final studentsWithMarks = studentsResponse.map((record) {
        final student = record['student'];
        final user = student['user'];
        
        // Find the most recent result for this student
        final studentResults = (catResults as List).where(
          (result) => result['student_id'] == student['id']
        ).toList();
        
        final latestResult = studentResults.isNotEmpty ? studentResults.first : null;
        
        final email = user['email'] as String;
        final regNumber = email.split('@')[0].toUpperCase();
        
        return {
          'student_id': student['id'],
          'email': email,
          'student_name': user['name'],
          'registration_number': regNumber,
          'marks': latestResult?['marks']?.toString() ?? '',
          'status': latestResult?['status'] ?? 'pending',
          'updated_at': latestResult?['updated_at'],
        };
      }).toList();
      
      if (mounted) {
        setState(() {
          _students = studentsWithMarks;
          _isLoading = false;
        });
        _updateFinalizeButtonState();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Please check your internet connection and try again';
        if (e is PostgrestException) {
          errorMessage = 'Unable to load data. Please try again later.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      setState(() {
        _students = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMark(String studentId, double mark) async {
    if (_selectedUnitId == null || _lecturerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit or lecturer information missing')),
      );
      return;
    }

    try {
      // Get the current status of the student's marks
        final existingRecords = await _supabase
            .from('cat_results')
          .select()
            .eq('unit_id', _selectedUnitId.toString())
            .eq('student_id', studentId.toString())
            .eq('cat_number', _selectedCatType == CatType.CAT1 ? 'CAT1' : 'CAT2')
          .order('updated_at', ascending: false)
          .limit(1);

      final existingRecord = (existingRecords as List).isNotEmpty ? existingRecords.first : null;
      final currentStatus = existingRecord?['status'] ?? 'draft';

      // Only update to draft if it's not already finalized
      final newStatus = currentStatus == 'final' ? 'final' : 'draft';

        if (existingRecord != null) {
          await _supabase
              .from('cat_results')
              .update({
                'marks': mark,
              'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingRecord['id']);
        } else {
          await _supabase
              .from('cat_results')
              .insert({
                'unit_id': _selectedUnitId.toString(),
                'student_id': studentId.toString(),
                'lecturer_id': _lecturerId.toString(),
                'cat_number': _selectedCatType == CatType.CAT1 ? 'CAT1' : 'CAT2',
                'marks': mark,
                'status': 'draft',
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
        }

      // Update the local student data
      setState(() {
        final studentIndex = _students.indexWhere((s) => s['student_id'] == studentId);
        if (studentIndex != -1) {
          _students[studentIndex] = {
            ..._students[studentIndex],
            'marks': mark.toString(),
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }
      });

      _updateFinalizeButtonState();

      // Show a small snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'final' 
              ? 'Mark updated (finalized)' 
              : 'Mark saved as draft'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving mark: $e')),
        );
      }
    }
  }

  Future<void> _finalizeMarks() async {
    if (_selectedUnitId == null || _lecturerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit or lecturer information missing')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      await _catService.finalizeMarks(
        _selectedUnitId!,
        _lecturerId!,
        _selectedCatType,
      );

      // Update local status without reloading
      setState(() {
        for (var i = 0; i < _students.length; i++) {
          if (_students[i]['status'] == 'draft') {
            _students[i] = {
              ..._students[i],
              'status': 'final',
            };
          }
        }
        _isLoading = false;
      });

      _updateFinalizeButtonState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marks finalized successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finalizing marks: $e')),
      );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    // Temporarily disabled
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Excel export is temporarily disabled. Will be available in a future update.'),
      ),
    );
  }

  void _handleImportStarted(String importId) {
    setState(() => _activeImportId = importId);
  }

  void _handleImportComplete() {
    setState(() => _activeImportId = null);
    _searchStudents();
  }

  void _handleImportError(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: $message')),
    );
  }

  Future<void> _updateFinalizeButtonState() async {
    if (_selectedUnitId == null || _lecturerId == null) {
      setState(() {
        _finalizeButtonColor = Colors.grey;
        _finalizeButtonText = 'No Drafts to Finalize';
        _canFinalize = false;
      });
      return;
    }

    try {
      // Count the number of draft and final marks
      int draftCount = 0;
      int finalCount = 0;
      int totalStudents = _students.length;

      for (var student in _students) {
        if (student['status'] == 'draft') {
          draftCount++;
        } else if (student['status'] == 'final') {
          finalCount++;
        }
      }

      setState(() {
        if (finalCount == totalStudents) {
          _finalizeButtonColor = Colors.green;
          _finalizeButtonText = 'All Marks Finalized';
          _canFinalize = false;
        } else if (draftCount > 0) {
          _finalizeButtonColor = Colors.orange;
          _finalizeButtonText = 'Finalize Draft Marks ($draftCount)';
          _canFinalize = true;
        } else {
          _finalizeButtonColor = Colors.grey;
          _finalizeButtonText = 'No Drafts to Finalize';
          _canFinalize = false;
        }
      });
    } catch (e) {
      print('Error updating finalize button state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Enter CAT Marks'),
          backgroundColor: const Color(0xFF2196F3), // Blue matching QR code page
          elevation: 0,
          foregroundColor: Colors.white,
        actions: [
          // Only print button
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print CAT Marks',
            onPressed: _isLoading ? null : () => _printCatMarks(),
          ),
        ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(140),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
                child: Column(
                  children: [
                  // Unit dropdown with better UI
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _lecturerId == null 
                      ? const SizedBox(height: 48)
                      : FutureBuilder<List<Map<String, dynamic>>>(
                        future: _supabase
                          .from('lecturer_assigned_units')
                          .select('''
                            unit_code,
                            unit_name,
                            unit_id,
                            department,
                            course_name,
                            year,
                            semester
                          ''')
                          .eq('lecturer_id', _lecturerId!)
                          .order('unit_code', ascending: true),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF2196F3),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                              return Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  snapshot.hasError ? 'Error loading units' : 'No units found',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              );
                            }
                            
                            return DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down),
                            value: _selectedUnitId,
                                hint: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text('Select Unit'),
                                ),
                                dropdownColor: Colors.white,
                            items: snapshot.data!.map((unit) {
                              return DropdownMenuItem<String>(
                                value: unit['unit_id'] as String,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  '${unit['unit_code']} - ${unit['unit_name']} (${unit['year']} ${unit['semester']})',
                                  overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                ),
                              );
                            }).toList(),
                            onChanged: (selectedUnitId) {
                              if (selectedUnitId != null) {
                                final selectedUnit = snapshot.data!.firstWhere(
                                  (unit) => unit['unit_id'] == selectedUnitId
                                );
                                setState(() {
                                  _selectedUnitId = selectedUnitId;
                                  _selectedUnitCode = selectedUnit['unit_code'] as String;
                                  _selectedUnit = selectedUnit;
                                  _students = [];
                                });
                                _searchStudents();
                              }
                            },
                              ),
                          );
                        },
                      ),
                    ),

                  // CAT type selector - Clean pill design
                    Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    height: 50,
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCatType = CatType.CAT1;
                                _students = [];
                              });
                              if (_selectedUnitId != null) {
                                _searchStudents();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _selectedCatType == CatType.CAT1
                                    ? const Color(0xFFE6E1F3) // Light purple background
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_selectedCatType == CatType.CAT1)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: Icon(
                                          Icons.check,
                                          color: Color(0xFF6750A4), // Purple check
                                          size: 18,
                                        ),
                                      ),
                                    const Text(
                                      'CAT 1',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                          setState(() {
                                _selectedCatType = CatType.CAT2;
                            _students = [];
                          });
                          if (_selectedUnitId != null) {
                            _searchStudents();
                          }
                        },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _selectedCatType == CatType.CAT2
                                    ? const Color(0xFFE6E1F3) // Light purple background
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Center(
                                child: Text(
                                  'CAT 2',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _lecturerId == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    // Search bar with correct search functionality
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: CatSearchField(
                        onSearch: (query) {
                          setState(() {
                            _searchQuery = query;
                          });
                        },
                      ),
                    ),
                    
                    // Data table area - Expanded to fill available space with padding for buttons
                    Expanded(
                      child: Stack(
                        children: [
                          // Table with bottom padding to prevent content being hidden by button
                          Padding(
                            padding: EdgeInsets.only(bottom: _searchQuery.isEmpty ? 90 : 16), // Reduce padding when searching
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                              child: CatGridWidget(
                                students: _students,
                                selectedCatType: _selectedCatType,
                                onMarkSaved: (String studentId, double mark) async {
                                  await _saveMark(studentId, mark);
                                  _updateFinalizeButtonState();
                                },
                                isLoading: _isLoading,
                                searchQuery: _searchQuery,
                              ),
                            ),
                          ),
                          
                          // Loading indicator positioned at the top of the content area
                          if (_isLoading)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Please wait a moment...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      floatingActionButton: _searchQuery.isEmpty ? FloatingActionButton.extended(
          onPressed: _canFinalize ? () async {
            await _finalizeMarks();
            _updateFinalizeButtonState();
          } : null,
          backgroundColor: _finalizeButtonColor,
          label: Text(_finalizeButtonText),
          icon: const Icon(Icons.check),
        ) : null,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final hasDraftsCAT1 = await _checkUnfinalizedMarks(CatType.CAT1);
    final hasDraftsCAT2 = await _checkUnfinalizedMarks(CatType.CAT2);

    if (!hasDraftsCAT1 && !hasDraftsCAT2) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Unfinalized Marks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You have unfinalized marks:'),
            if (hasDraftsCAT1)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('• CAT 1 has draft marks'),
              ),
            if (hasDraftsCAT2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('• CAT 2 has draft marks'),
              ),
            const SizedBox(height: 16),
            const Text('Would you like to finalize them before leaving?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child: const Text('Leave Without Finalizing'),
          ),
          if (hasDraftsCAT1)
            TextButton(
              onPressed: () => Navigator.pop(context, 'cat1'),
              child: const Text('Finalize CAT 1'),
            ),
          if (hasDraftsCAT2)
            TextButton(
              onPressed: () => Navigator.pop(context, 'cat2'),
              child: const Text('Finalize CAT 2'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'both'),
            child: const Text('Finalize All'),
          ),
        ],
      ),
    );

    if (result == null || result == 'leave') return true;

    if (result == 'cat1' || result == 'both') {
      final savedCatType = _selectedCatType;
      setState(() => _selectedCatType = CatType.CAT1);
      await _finalizeMarks();
      setState(() => _selectedCatType = savedCatType);
    }

    if (result == 'cat2' || result == 'both') {
      final savedCatType = _selectedCatType;
      setState(() => _selectedCatType = CatType.CAT2);
      await _finalizeMarks();
      setState(() => _selectedCatType = savedCatType);
    }

    return result == 'leave';
  }

  Future<bool> _checkUnfinalizedMarks(CatType catType) async {
    if (_selectedUnitId == null || _lecturerId == null) return false;

    try {
      final results = await _supabase
          .from('cat_results')
          .select()
          .eq('unit_id', _selectedUnitId!)
          .eq('lecturer_id', _lecturerId!)
          .eq('cat_number', catType == CatType.CAT1 ? 'CAT1' : 'CAT2')
          .eq('status', 'draft');

      return (results as List).isNotEmpty;
    } catch (e) {
      print('Error checking unfinalized marks: $e');
      return false;
    }
  }

  // Update print function
  Future<void> _printCatMarks() async {
    if (_selectedUnitId == null || _students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to print')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Get unit details from selected unit
      final department = _selectedUnit?['department'] ?? 'N/A';
      final course = _selectedUnit?['course_name'] ?? 'N/A';
      final year = _selectedUnit?['year']?.toString() ?? 'N/A';
      final semester = _selectedUnit?['semester']?.toString() ?? 'N/A';
      final unitCode = _selectedUnit?['unit_code'] ?? 'N/A';
      final unitName = _selectedUnit?['unit_name'] ?? 'N/A';

      // Create PDF document
      final pdf = pw.Document();

      // Load the university logo
      final ByteData logoData = await rootBundle.load('assets/images/university_logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final logoImage = pw.MemoryImage(logoBytes);

      // Calculate how many students can fit on one page (excluding header and footer space)
      const int rowsPerPage = 35; // Increased from 25 to fit more students per page
      final int totalPages = (_students.length / rowsPerPage).ceil();

      // Generate pages
      for (int pageNum = 0; pageNum < totalPages; pageNum++) {
        final startIndex = pageNum * rowsPerPage;
        final endIndex = min((pageNum + 1) * rowsPerPage, _students.length);
        final isLastPage = pageNum == totalPages - 1;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header with Logo (only on first page)
                  if (pageNum == 0) ...[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 400,
                          child: pw.Image(logoImage),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),

                    // Title
                    pw.Center(
                      child: pw.Text(
                        'CAT MARKS REPORT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    // Course Information Box with blue border
                    pw.Container(
                      padding: pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.blue,
                          width: 1,
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Department: $department'),
                          pw.Text('Course: $course'),
                          pw.Text('Year: $year, Semester: $semester'),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    // Unit details
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Unit Code: $unitCode'),
                        pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
                      ],
                    ),
                    pw.Text('Unit Title: $unitName'),
                    pw.Text('${_selectedCatType == CatType.CAT1 ? 'CAT 1' : 'CAT 2'}'),
                    pw.SizedBox(height: 30),
                  ] else ...[
                    // Continuation header for other pages
                    pw.Container(
                      padding: pw.EdgeInsets.only(bottom: 10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'CAT MARKS REPORT - Continued',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Unit: $unitCode - ${_selectedCatType == CatType.CAT1 ? 'CAT 1' : 'CAT 2'}',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                  ],

                  // Students Table
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(width: 0.5),
                      columnWidths: {
                        0: pw.FlexColumnWidth(0.5),
                        1: pw.FlexColumnWidth(2.5),
                        2: pw.FlexColumnWidth(2),
                        3: pw.FlexColumnWidth(1),
                        4: pw.FlexColumnWidth(1),
                      },
                      children: [
                        // Table Header
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '#',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Name',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Reg Number',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Marks',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Status',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        // Table Rows for current page
                        ..._students.sublist(startIndex, endIndex).asMap().entries.map((entry) {
                          final index = startIndex + entry.key;
                          final student = entry.value;
                          final marks = student['marks']?.toString() ?? '-';
                          final status = student['status'] ?? 'pending';
                          final regNumber = student['registration_number'] ?? 'N/A';

                          return pw.TableRow(
                            decoration: index % 2 == 0 
                              ? pw.BoxDecoration(color: PdfColors.grey100)
                              : null,
                            children: [
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text('${index + 1}'),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text(student['student_name'] ?? 'N/A'),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text(regNumber),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text(marks),
                              ),
                              pw.Padding(
                                padding: pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  status,
                                  style: pw.TextStyle(
                                    color: status == 'final' ? PdfColors.green : PdfColors.grey,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                  // Summary Box (only on last page)
                  if (isLastPage) ...[
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 0.5),
                        borderRadius: pw.BorderRadius.circular(5),
                        color: PdfColors.grey100,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Summary Report',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              decoration: pw.TextDecoration.underline,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Total Students: ${_students.length}'),
                                  pw.Text('Marks Entered: ${_students.where((s) => s['marks'] != null && s['marks'].toString().isNotEmpty).length}'),
                                ],
                              ),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Finalized: ${_students.where((s) => s['status'] == 'final').length}'),
                                  pw.Text('Pending: ${_students.where((s) => s['status'] != 'final').length}'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Footer
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 0.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Generated: ${DateTime.now().toString().substring(0, 19)}',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Page ${pageNum + 1} of $totalPages',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      // Print the document
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// Search field widget
class CatSearchField extends StatefulWidget {
  final Function(String) onSearch;

  const CatSearchField({Key? key, required this.onSearch}) : super(key: key);

  @override
  State<CatSearchField> createState() => _CatSearchFieldState();
}

class _CatSearchFieldState extends State<CatSearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      height: 48,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search by name or reg number',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.blue[400], size: 20),
          suffixIcon: _controller.text.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.onSearch('');
                },
              )
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          constraints: const BoxConstraints(maxHeight: 48),
          isDense: true,
        ),
        maxLines: 1,
        onChanged: widget.onSearch,
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../routes/app_routes.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class RegisterUnitsPage extends StatefulWidget {
  const RegisterUnitsPage({super.key});

  @override
  State<RegisterUnitsPage> createState() => _RegisterUnitsPageState();
}

class _RegisterUnitsPageState extends State<RegisterUnitsPage> {
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  String? _studentId;
  String? _selectedUnitId;
  List<Map<String, dynamic>> _registeredUnits = [];
  List<Map<String, dynamic>> _catResults = [];
  bool _isLoadingProfile = false;
  bool _isLoadingUnits = false;
  bool _isLoadingCat = false;
  String? _error;
  
  // Student profile info
  String _studentName = '';
  String _studentEmail = '';
  String _course = '';
  String _department = '';
  String _currentYear = '';
  String _currentSemester = '';

  @override
  void initState() {
    super.initState();
    print('DEBUG: RegisterUnitsPage initState called');
    _checkAuthAndInitialize();
  }

  Future<void> _checkAuthAndInitialize() async {
    try {
      print('DEBUG: Starting _checkAuthAndInitialize');
      
      // Check Supabase connection
      try {
        setState(() {
          _isLoadingProfile = true;
          _isLoadingUnits = true;
        });
        
        final healthCheck = await _supabase
            .from('student_units')
            .select('count')
            .limit(1)
            .single();
        print('DEBUG: Supabase connection check successful');
        print('DEBUG: Health check result: $healthCheck');
      } catch (e) {
        print('DEBUG: Supabase connection check failed: $e');
        if (mounted) {
          setState(() {
            _error = 'Unable to connect to server. Please check your internet connection and try again.';
            _isLoadingProfile = false;
            _isLoadingUnits = false;
          });
        }
        return;
      }
      
      // Get current user data from service
      final userData = _supabaseService.getCurrentUser();
      print('DEBUG: Current user data:');
      print(userData);
      
      if (userData == null || userData['student_id'] == null) {
        print('DEBUG: No user data found, trying to refresh');
        try {
          final refreshedData = await _supabaseService.refreshUserData();
          print('DEBUG: Refreshed user data:');
          print(refreshedData);
          
          if (refreshedData == null || refreshedData['student_id'] == null) {
            if (mounted) {
              setState(() {
                _error = 'Session expired. Please log in again.';
                _isLoadingProfile = false;
                _isLoadingUnits = false;
              });
            }
            return;
          }
          
          _studentId = refreshedData['student_id'] as String;
        } catch (e) {
          print('DEBUG: Error refreshing user data: $e');
          if (mounted) {
            setState(() {
              _error = 'Unable to load your data. Please check your connection and try again.';
              _isLoadingProfile = false;
              _isLoadingUnits = false;
            });
          }
          return;
        }
      } else {
        _studentId = userData['student_id'] as String;
      }

      print('DEBUG: Final student ID set to: $_studentId');

      // Load profile and units in parallel
      await Future.wait([
        _loadStudentProfile(),
        _loadRegisteredUnits(),
      ]);
    } catch (e) {
      print('DEBUG: Error in _checkAuthAndInitialize: $e');
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please check your connection and try again.';
          _isLoadingProfile = false;
          _isLoadingUnits = false;
        });
      }
    }
  }

  Future<void> _loadStudentProfile() async {
    try {
      if (_studentId != null) {
        final studentProfile = await _supabase
            .from('students')
            .select('''
              *,
              user:user_id (
                email,
                name
              )
            ''')
            .eq('id', _studentId as String)
            .single();
        
        print('DEBUG: Student profile:');
        print(studentProfile);

        if (mounted && studentProfile != null) {
          final userInfo = studentProfile['user'] as Map<String, dynamic>;
          setState(() {
            _studentName = userInfo['name'] ?? 'Student Name Not Set';
            // Get email without domain
            final email = userInfo['email'] as String;
            _studentEmail = email.split('@')[0];
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error getting student profile: $e');
      if (mounted) {
        setState(() {
          _error = 'Unable to load your profile. Please check your connection and try again.';
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadRegisteredUnits() async {
    if (!mounted) return;

    try {
      print('DEBUG: Starting _loadRegisteredUnits');
      
      final userData = _supabaseService.getCurrentUser();
      print('DEBUG: Current user data:');
      print(userData);

      if (userData == null) {
        throw Exception('Session expired');
      }

      final studentId = userData['student_id'] as String?;
      if (studentId == null) {
        throw Exception('Session expired');
      }

      print('DEBUG: Using student ID: $studentId');

      final results = await _supabase
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
          .eq('student_id', studentId);

      print('DEBUG: Query results from student_registered_units:');
      print(results);

      if (!mounted) return;

      if (results == null) {
        setState(() {
          _registeredUnits = [];
          _selectedUnitId = null;
          _error = 'No registered units found. Please try again later.';
          _isLoadingUnits = false;
        });
        return;
      }

      final units = List<Map<String, dynamic>>.from(results);
      print('DEBUG: Parsed ${units.length} units');

      setState(() {
        _registeredUnits = units;
        _selectedUnitId = null;
        _isLoadingUnits = false;
      });

    } catch (e, stack) {
      print('DEBUG: Error in _loadRegisteredUnits:');
      print(e);
      print('Stack trace:');
      print(stack);
      
      if (!mounted) return;
      
      String errorMessage = 'Unable to load your units.';
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Network is unreachable')) {
        errorMessage = 'Please check your internet connection and try again.';
      } else if (e.toString().contains('Session expired')) {
        errorMessage = 'Your session has expired. Please log in again.';
      }
      
      setState(() {
        _error = errorMessage;
        _isLoadingUnits = false;
      });
    }
  }

  Future<void> _loadCatResults(String unitId) async {
    final studentId = _studentId;
    if (studentId == null) return;

    setState(() {
      _isLoadingCat = true;
      _error = null;
    });

    try {
      // Verify this is a registered unit first
      final isRegistered = _registeredUnits.any((unit) => unit['unit_id'] == unitId);
      if (!isRegistered) {
        throw 'Not registered for this unit';
      }

      // Get CAT results for this specific unit
      final results = await _supabase
          .from('cat_results')
          .select('cat_number, marks, status')
          .eq('student_id', studentId)
          .eq('unit_id', unitId)
          .eq('status', 'final');

      if (mounted) {
        setState(() {
          _catResults = List<Map<String, dynamic>>.from(results);
          _isLoadingCat = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load CAT results: $e';
          _isLoadingCat = false;
        });
      }
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    
    try {
      // Load the university logo
      final logoImage = await imageFromAssetBundle('assets/images/university_logo.png');
      
      // Get current unit details
      final currentUnit = _registeredUnits.firstWhere(
        (unit) => unit['unit_id'] == _selectedUnitId,
        orElse: () => {},
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with only logo centered
                pw.Center(
                  child: pw.Container(
                    width: 400,
                    height: 150,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ),
                pw.SizedBox(height: 20),

                // Blue line separator
                pw.Container(
                  height: 2,
                  color: PdfColors.blue800,
                ),
                pw.SizedBox(height: 20),

                // CAT MARKS REPORT title
                pw.Center(
                  child: pw.Text(
                    'CAT MARKS REPORT',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),

                // Department info box with blue border
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.blue800,
                      width: 0.5,
                    ),
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Department: ${currentUnit['department'] ?? 'Engineering'}'),
                      pw.Text('Course: ${currentUnit['course_name'] ?? 'Civil Engineering'}'),
                      pw.Text('Year 4, Semester 2'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Unit info
                pw.Text('Unit Code: ${currentUnit['unit_code'] ?? 'N/A'}'),
                pw.Text('Unit Title: ${currentUnit['unit_name'] ?? 'N/A'}'),
                pw.SizedBox(height: 16),

                // Student info - using data from state
                pw.Text('Student Name: $_studentName'),
                pw.Text('Registration No: $_studentEmail'),
                pw.SizedBox(height: 20),

                // CAT Results Cards in a row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    // CAT 1 Card
                    pw.Container(
                      width: 150,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        border: pw.Border.all(color: PdfColors.green500),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('CAT 1',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            '${_catResults.firstWhere((r) => r['cat_number'] == 'CAT1', orElse: () => {'marks': 'N/A'})['marks']}',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('FINAL',
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // CAT 2 Card
                    pw.Container(
                      width: 150,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        border: pw.Border.all(color: PdfColors.green500),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('CAT 2',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            '${_catResults.firstWhere((r) => r['cat_number'] == 'CAT2', orElse: () => {'marks': 'N/A'})['marks']}',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('FINAL',
                            style: const pw.TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Total Marks Card
                pw.Center(
                  child: pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green500),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Total CAT Marks',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          '${_catResults.fold<num>(0, (sum, result) => sum + (result['marks'] ?? 0))}',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),

                // Warning section
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    border: pw.Border.all(color: PdfColors.amber),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'IMPORTANT NOTICE',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber900,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Please note:\n'
                        '1. These marks are provisional and subject to moderation.\n'
                        '2. Any discrepancies should be reported to the department within 7 days.\n'
                        '3. Final marks will be published through the official university portal.',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Generated timestamp at the bottom
                pw.Spacer(),
                pw.Text(
                  'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page 1 of 1',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            );
          },
        ),
      );

      // Print the document
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CAT Results',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_catResults.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: _generatePdf,
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoadingProfile = true;
                        _isLoadingUnits = true;
                      });
                      _checkAuthAndInitialize();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _isLoadingProfile = true;
                  _isLoadingUnits = true;
                });
                await Future.wait([
                  _loadStudentProfile(),
                  _loadRegisteredUnits(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Blue gradient background for top section
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2196F3), Color(0xFF1E88E5)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.book,
                                      color: Color(0xFF2196F3),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Unit Selection',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                                ),
                                child: _isLoadingUnits
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : _buildUnitSelector(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedUnitId != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // CAT Results Card
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.grey.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2196F3).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.assessment,
                                            color: Color(0xFF2196F3),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'CAT Results',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _isLoadingCat
                                        ? const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child: CircularProgressIndicator(),
                                            ),
                                          )
                                        : _buildCatResults(),
                                  ],
                                ),
                              ),
                            ),
                            // Total Marks Card
                            if (_catResults.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Colors.grey.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF22C55E).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.stars,
                                              color: Color(0xFF22C55E),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Total CAT Marks',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTotalMarks(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUnitSelector() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.signal_wifi_off,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoadingProfile = true;
                  _isLoadingUnits = true;
                });
                _checkAuthAndInitialize();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_registeredUnits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 32,
              color: Colors.blue[300],
            ),
            const SizedBox(height: 12),
            const Text(
              'View Your CAT Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a registered unit from the dropdown below to view your CAT marks and assessment status.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Only registered units will appear in the list',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedUnitId,
      isExpanded: true,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintText: 'Select a unit to view CAT results',
        hintStyle: TextStyle(
          color: Colors.grey,
          fontSize: 16,
        ),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down,
        color: Color(0xFF2196F3),
      ),
      items: _registeredUnits.map((unit) {
        final unitCode = unit['unit_code'] as String? ?? 'Unknown Code';
        final unitName = unit['unit_name'] as String? ?? 'Unknown Name';
        final unitId = unit['unit_id'] as String?;
        
        if (unitId == null) return null;
        
        // Limit the unit name length
        final truncatedName = unitName.length > 20 
            ? '${unitName.substring(0, 20)}...'
            : unitName;
        
        return DropdownMenuItem<String>(
          value: unitId,
          child: Text(
            '$unitCode - $truncatedName',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1F2937),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).whereType<DropdownMenuItem<String>>().toList(),
      onChanged: (unitId) {
        if (unitId == null) return;
        setState(() {
          _selectedUnitId = unitId;
          _catResults = [];
        });
        _loadCatResults(unitId);
      },
    );
  }

  Widget _buildCatResults() {
    if (_isLoadingCat) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
          ),
        ),
      );
    }

    // Determine which statuses are present in the results
    final Set<String> activeStatuses = _catResults.isEmpty 
        ? {'pending'} 
        : _catResults.map((r) => (r['status'] as String?) ?? 'pending').toSet();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_catResults.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assessment_outlined,
                  size: 40,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'No CAT results available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: _buildCatCard(1)),
                const SizedBox(width: 12),
                Expanded(child: _buildCatCard(2)),
              ],
            ),
          ),
        // Compact Status Guide
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Status:',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 4),
              // Final status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 10,
                    color: activeStatuses.contains('final') 
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Final',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: activeStatuses.contains('final')
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Draft status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 10,
                    color: activeStatuses.contains('draft')
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Draft',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: activeStatuses.contains('draft')
                          ? const Color(0xFFFF9800)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Pending status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pending,
                    size: 10,
                    color: activeStatuses.contains('pending')
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: activeStatuses.contains('pending')
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'final':
        return const Color(0xFF22C55E); // Green
      case 'draft':
        return const Color(0xFFFF9800); // Orange
      case 'pending':
      default:
        return const Color(0xFF94A3B8); // Grey
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'final':
        return Icons.check_circle;
      case 'draft':
        return Icons.edit_note;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  Widget _buildCatCard(int catNumber) {
    final result = _catResults.firstWhere(
      (r) => r['cat_number'] == 'CAT$catNumber',
      orElse: () => {'marks': null, 'status': 'pending'},
    );

    final marks = result['marks'] as num?;
    final String status = (result['status'] as String?) ?? 'pending';
    final bool isFinalized = status == 'final';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                color: statusColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CAT $catNumber',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (marks != null)
                    Text(
                      marks.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    )
                  else
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalMarks() {
    num totalMarks = 0;
    int finalizedCount = 0;
    int draftCount = 0;
    int pendingCount = 0;

    for (var result in _catResults) {
      final status = (result['status'] as String?) ?? 'pending';
      if (result['marks'] != null) {
        totalMarks += result['marks'] as num;
        
        switch (status.toLowerCase()) {
          case 'final':
            finalizedCount++;
            break;
          case 'draft':
            draftCount++;
            break;
          case 'pending':
            pendingCount++;
            break;
        }
      }
    }

    final bool hasNonFinalMarks = draftCount > 0 || pendingCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Marks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (hasNonFinalMarks ? const Color(0xFFFBBF24) : const Color(0xFF22C55E)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasNonFinalMarks ? Icons.info_outline : Icons.check_circle,
                        size: 16,
                        color: hasNonFinalMarks ? const Color(0xFFFBBF24) : const Color(0xFF22C55E),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        totalMarks.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hasNonFinalMarks ? const Color(0xFFFBBF24) : const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasNonFinalMarks) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Some marks are not finalized',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 
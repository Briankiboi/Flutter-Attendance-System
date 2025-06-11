import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/attendance_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  final _attendanceService = AttendanceService();
  
  String? _lecturerId;
  String? _selectedUnitId;
  Map<String, dynamic>? _selectedUnit;
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _attendanceStats;
  bool _isLoading = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _initializeLecturerData();
  }

  Future<void> _initializeLecturerData() async {
    setState(() => _isLoading = true);
    
    try {
      final userData = _supabaseService.getCurrentUser();
      
      if (userData != null && userData['lecturer_id'] != null) {
        setState(() => _lecturerId = userData['lecturer_id']);
        await _loadUnits();
        return;
      }

      final user = _supabase.auth.currentUser;
      
      if (user != null) {
        final userId = user.id;
        final userEmail = user.email;
        
        if (userId != null) {
          var lecturer = await _supabase
            .from('lecturers')
            .select('id, name, email')
            .eq('user_id', userId as Object)
            .maybeSingle();
                
          if (lecturer == null && userEmail != null) {
            lecturer = await _supabase
                .from('lecturers')
                .select('id, name, email')
                .eq('email', userEmail as Object)
                .maybeSingle();
          }
                
          if (!mounted) return;
          
          final lecturerId = lecturer?['id'] as String?;
          
          if (lecturerId != null) {
            setState(() => _lecturerId = lecturerId);
            _supabaseService.updateCurrentUserCache({
              'lecturer_id': lecturerId
            });
            await _loadUnits();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lecturer profile not found. Please contact support.')),
            );
          }
        }
      }
    } catch (e) {
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

  Future<void> _loadUnits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('units')
          .select()
          .order('code');

      setState(() {
        _units = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load units: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAttendanceStats() async {
    if (_selectedUnitId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _attendanceStats = null;
    });

    try {
      // We'll implement the actual data loading later
      // For now, just show the UI with placeholder data
      await Future.delayed(Duration(seconds: 1)); // Simulate loading
      setState(() {
        _attendanceStats = {
          'total_students': 45,
          'eligible_students': 38,
          'at_risk_students': 7,
          'student_records': [
            {
              'name': 'John Doe',
              'registration_number': 'SCT221-0001/2021',
              'attendance_percentage': 85.5,
              'is_eligible': true,
            },
            {
              'name': 'Jane Smith',
              'registration_number': 'SCT221-0002/2021',
              'attendance_percentage': 65.0,
              'is_eligible': false,
            },
          ],
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attendance statistics: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateReport() async {
    try {
      setState(() => _isLoading = true);

      // Get unit details
      final unitDetails = _selectedUnit!;
      final departmentDetails = unitDetails['department'];

      // Create PDF document
      final pdf = pw.Document();

      // Load university logo
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final logo = pw.MemoryImage(logoBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with logo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(logo, width: 60, height: 60),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('MASENO UNIVERSITY',
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Private Bag, Maseno',
                            style: pw.TextStyle(fontSize: 10)),
                        pw.Text('www.maseno.ac.ke',
                            style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Report title
                pw.Center(
                  child: pw.Text(
                    'ATTENDANCE ANALYSIS REPORT',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold
                    )
                  ),
                ),
                pw.SizedBox(height: 10),

                // Unit and department details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Unit Code: ${unitDetails['code']}'),
                        pw.Text('Unit Name: ${unitDetails['name']}'),
                        pw.Text('Department: ${departmentDetails['name']}'),
                        pw.Text('Date Generated: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Students: ${_attendanceStats!['total_students']}'),
                        pw.Text('Present: ${_attendanceStats!['present_percentage'].toStringAsFixed(1)}%'),
                        pw.Text('Absent: ${_attendanceStats!['absent_percentage'].toStringAsFixed(1)}%'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Attendance Statistics
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Attendance Requirements',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold
                        )
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Expected Sessions:'),
                          pw.Text('${_attendanceStats!['total_expected_sessions']}'),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Required Sessions (70%):'),
                          pw.Text('${_attendanceStats!['required_sessions']}'),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Student Statistics',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold
                        )
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Eligible for Exams (≥70%):'),
                          pw.Text('${_attendanceStats!['eligible_count']}/${_attendanceStats!['total_students']} (${((_attendanceStats!['eligible_count'] / _attendanceStats!['total_students']) * 100).toStringAsFixed(1)}%)'),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('At Risk Students (<70%):'),
                          pw.Text('${_attendanceStats!['at_risk_count']}/${_attendanceStats!['total_students']} (${((_attendanceStats!['at_risk_count'] / _attendanceStats!['total_students']) * 100).toStringAsFixed(1)}%)'),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Full Attendance:'),
                          pw.Text('${_attendanceStats!['full_attendance']}/${_attendanceStats!['total_students']} (${((_attendanceStats!['full_attendance'] / _attendanceStats!['total_students']) * 100).toStringAsFixed(1)}%)'),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Low Attendance:'),
                          pw.Text('${_attendanceStats!['low_attendance']}/${_attendanceStats!['total_students']} (${((_attendanceStats!['low_attendance'] / _attendanceStats!['total_students']) * 100).toStringAsFixed(1)}%)'),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Student Details Table
                pw.Text(
                  'Student Attendance Details',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold
                  )
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300
                      ),
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Reg Number', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Present/Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Required', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                        ),
                      ],
                    ),
                    // Data rows
                    ..._attendanceStats!['student_records'].map<pw.TableRow>((student) {
                      final attendancePercentage = student['attendance_percentage'] as double;
                      final presentSessions = student['present_sessions'] as int;
                      final requiredSessions = student['required_sessions'] as int;
                      final neededForEligibility = student['sessions_needed_for_eligibility'] as int;
                      final status = presentSessions >= requiredSessions ? 
                        'Eligible' : 'Needs $neededForEligibility more';
                      
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text(student['reg_number'] ?? 'N/A')
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text(student['name'])
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text('$presentSessions/${_attendanceStats!['total_expected_sessions']} (${attendancePercentage.toStringAsFixed(1)}%)')
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text('$requiredSessions')
                          ),
                          pw.Padding(
                            padding: pw.EdgeInsets.all(5),
                            child: pw.Text(status)
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                
                // Footer
                pw.Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                      pw.Text('Page 1 of 1'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

    } catch (e) {
      print('Error generating report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Analysis'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unit Selection Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Unit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedUnitId,
                      decoration: InputDecoration(
                        hintText: 'Select a unit to view statistics',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit['id'].toString(),
                          child: Text('${unit['code']} - ${unit['name']}'),
                        );
                      }).toList(),
                      onChanged: (String? unitId) {
                        setState(() {
                          _selectedUnitId = unitId;
                        });
                        if (unitId != null) {
                          _loadAttendanceStats();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading attendance statistics...')
                  ],
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (_attendanceStats != null) ...[
              // Overview Statistics Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            'Total Students',
                            _attendanceStats!['total_students'].toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'Eligible',
                            _attendanceStats!['eligible_students'].toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                          _buildStatCard(
                            'At Risk',
                            _attendanceStats!['at_risk_students'].toString(),
                            Icons.warning,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Attendance Requirements Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Requirements',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildRequirementRow('Hours per Session:', '2 hours'),
                      _buildRequirementRow('Sessions per Week:', '2 sessions'),
                      _buildRequirementRow('Required Semester Hours:', '34 hours'),
                      _buildRequirementRow('Eligibility Threshold:', '70%'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Student Records Card
              if (_attendanceStats!['student_records']?.isNotEmpty == true)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Records',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: (_attendanceStats!['student_records'] as List).length,
                          itemBuilder: (context, index) {
                            final student = _attendanceStats!['student_records'][index];
                            return _buildStudentRecordCard(student);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRecordCard(Map<String, dynamic> student) {
    final attendancePercentage = student['attendance_percentage'] as double;
    final isEligible = student['is_eligible'] as bool;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(student['name'] as String),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student['registration_number'] as String),
            SizedBox(height: 4),
            LinearProgressIndicator(
              value: attendancePercentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isEligible ? Colors.green : Colors.orange,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Attendance: ${attendancePercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: isEligible ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Icon(
          isEligible ? Icons.check_circle : Icons.warning,
          color: isEligible ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
} 
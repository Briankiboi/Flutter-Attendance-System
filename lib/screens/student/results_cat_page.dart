import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/custom_error_widget.dart';

class ResultsCATPage extends StatefulWidget {
  const ResultsCATPage({super.key});

  @override
  State<ResultsCATPage> createState() => _ResultsCATPageState();
}

class _ResultsCATPageState extends State<ResultsCATPage> {
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  String? _error;
  
  // Student profile info
  String _studentId = '';
  String _course = '';
  String _department = '';
  String _currentYear = '';
  String _currentSemester = '';
  
  // Dropdown controllers
  String _selectedYear = '1';
  String _selectedSemester = '1';
  
  // Available years and semesters
  final List<String> _availableYears = ['1', '2', '3', '4'];
  final List<String> _availableSemesters = ['1', '2'];
  
  // Available and selected units
  List<Map<String, dynamic>> _availableUnits = [];
  List<Map<String, dynamic>> _registeredUnits = [];
  List<String> _selectedUnits = [];

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
  }

  Future<void> _loadStudentProfile() async {
    try {
      setState(() => _isLoading = true);

      print('==================== DEBUG: Loading Student Profile ====================');

      // Get current user
      final user = await _supabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('session_expired');
      }

      print('Current User:');
      print(user);

      try {
        // Get student profile with all related data
        final studentProfile = await _supabaseService.client
            .from('students')
            .select('''
              *,
              departments:department_id (*),
              courses:course_id (
                *,
                departments (*)
              )
            ''')
            .eq('user_id', user['id'])
            .single();

        if (studentProfile == null) {
          throw Exception('profile_not_found');
        }

        print('Student Profile:');
        print(studentProfile);

        // Extract course and department info
        String? courseId = studentProfile['course_id'];
        String? departmentId = studentProfile['department_id'];
        String? departmentName;
        String? courseName;

        // Get department info
        if (studentProfile['departments'] != null) {
          departmentName = studentProfile['departments']['name'];
          departmentId = studentProfile['departments']['id'];
        }

        // Get course info
        if (studentProfile['courses'] != null) {
          courseName = studentProfile['courses']['name'];
          courseId = studentProfile['courses']['id'];
          // If we have a course but no department, get it from the course
          if (departmentId == null && studentProfile['courses']['departments'] != null) {
            departmentId = studentProfile['courses']['departments']['id'];
            departmentName = studentProfile['courses']['departments']['name'];
          }
        }

        // Extract year and semester, removing any "Year " or "Semester " prefix
        String year = (studentProfile['year'] ?? '').toString().replaceAll(RegExp(r'^Year\s*'), '');
        String semester = (studentProfile['semester'] ?? '').toString().replaceAll(RegExp(r'^Semester\s*'), '');

        setState(() {
          _studentId = studentProfile['id'];
          _course = courseName ?? studentProfile['course'] ?? '';
          _department = departmentName ?? studentProfile['department'] ?? '';
          _currentYear = year;
          _currentSemester = semester;
          _selectedYear = year;
          _selectedSemester = semester;
        });

        print('Profile Info Set:');
        print('- Student ID: $_studentId');
        print('- Course: $_course');
        print('- Department: $_department');
        print('- Year: $_currentYear');
        print('- Semester: $_currentSemester');
        print('- Course ID: $courseId');
        print('- Department ID: $departmentId');

        print('==================== DEBUG: Profile Loading Complete ====================');
        
        await _loadUnits();
      } catch (e) {
        print('Error loading student profile details: $e');
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Network is unreachable')) {
          throw Exception('network_error');
        } else {
          throw Exception('profile_error');
        }
      }
    } catch (e, stackTrace) {
      print('Error in profile loading flow: $e');
      print('Stack trace: $stackTrace');
      
      String errorMessage = 'Unable to load your profile.';
      if (e.toString().contains('session_expired')) {
        errorMessage = 'Your session has expired. Please log in again.';
      } else if (e.toString().contains('network_error')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection and try again.';
      } else if (e.toString().contains('profile_not_found')) {
        errorMessage = 'Unable to find your student profile. Please contact support.';
      } else if (e.toString().contains('profile_error')) {
        errorMessage = 'Unable to load your profile. Please try again later.';
      }
      
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUnits() async {
    try {
      if (_studentId.isEmpty) {
        throw Exception('missing_student_info');
      }

      print('\n==================== DEBUG: Loading Units ====================');
      print('Student Context:');
      print('- Student ID: $_studentId');
      print('- Year: $_selectedYear');
      print('- Semester: $_selectedSemester');
      print('- Department: $_department');
      print('- Course: $_course');

      try {
        // First get already registered units
        final registeredUnitsResponse = await _supabaseService.client
            .from('student_units')
            .select('''
              id,
              unit_id,
              status,
              units!inner (
                id,
                code,
                name,
                course_id,
                year,
                semester
              )
            ''')
            .eq('student_id', _studentId)
            .eq('year', _selectedYear)
            .eq('semester', _selectedSemester)
            .eq('status', 'registered');

        final List<Map<String, dynamic>> registeredUnits = 
            List<Map<String, dynamic>>.from(registeredUnitsResponse ?? []);

        print('\nRegistered Units:');
        for (var ru in registeredUnits) {
          final unit = ru['units'];
          print('- ${unit['code']}: ${unit['name']} (Status: ${ru['status']})');
        }

        // Get available units using our function
        print('\nFetching available units...');
        final availableUnitsData = await _supabaseService.client
            .rpc('get_available_units', params: {
              'p_student_id': _studentId,
              'p_year': _selectedYear,
              'p_semester': _selectedSemester
            });

        print('\nAvailable Units Response:');
        print(availableUnitsData);

        // Transform the response and filter out already registered units
        final List<Map<String, dynamic>> transformedUnits = 
          (availableUnitsData as List).map((unit) => {
            'unit_id': unit['unit_id'],
            'unit_code': unit['unit_code'],
            'unit_name': unit['unit_name'],
            'course_name': unit['course_name'],
            'year': unit['year'],
            'semester': unit['semester']
          }).where((unit) => !registeredUnits.any((ru) => 
            ru['unit_id'] == unit['unit_id']
          )).toList();

        setState(() {
          _registeredUnits = registeredUnits;
          _availableUnits = transformedUnits;
          _isLoading = false;
          _error = null;
        });

      } catch (e) {
        print('Error in units loading operation: $e');
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Network is unreachable')) {
          throw Exception('network_error');
        } else {
          throw Exception('units_error');
        }
      }
    } catch (e, stackTrace) {
      print('Error in units loading flow: $e');
      print('Stack trace: $stackTrace');
      
      String errorMessage = 'Unable to load your units.';
      if (e.toString().contains('missing_student_info')) {
        errorMessage = 'Student information is missing. Please try logging in again.';
      } else if (e.toString().contains('network_error')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection and try again.';
      } else if (e.toString().contains('units_error')) {
        errorMessage = 'Unable to load your units. Please try again later.';
      }
      
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _registerUnits() async {
    if (_selectedUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one unit'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Register each unit individually using our new function
      for (String unitId in _selectedUnits) {
        final result = await _supabaseService.client
            .rpc('register_unit', params: {
              'p_student_id': _studentId,
              'p_unit_id': unitId,
              'p_year': _selectedYear,
              'p_semester': _selectedSemester
            });

        print('Registration result for unit $unitId: $result');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Units registered successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear selected units and reload
      setState(() => _selectedUnits.clear());
      await _loadUnits(); // This will refresh both available and registered units
    } catch (e) {
      print('Error registering units: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to register units: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  bool _isUnitRegistered(String unitId) {
    return _registeredUnits.any((ru) => ru['unit_id'] == unitId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
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
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.signal_wifi_off,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadStudentProfile();
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
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Register Units'),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _selectedUnits.isNotEmpty
          ? Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton.extended(
              onPressed: _registerUnits,
              label: Text('Register ${_selectedUnits.length} Unit${_selectedUnits.length > 1 ? 's' : ''}'),
              icon: const Icon(Icons.check),
                backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadUnits,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _department,
                        style: const TextStyle(
                            fontSize: 24,
                          fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          _course,
                        style: TextStyle(
                            fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                        const SizedBox(height: 24),
                        
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Year',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedYear,
                                        isExpanded: true,
                                        icon: const Icon(Icons.keyboard_arrow_down),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        items: _availableYears.map((year) {
                                          return DropdownMenuItem(
                                            value: year,
                                            child: Text('Year $year'),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedYear = value;
                                              _loadUnits();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Semester',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedSemester,
                                        isExpanded: true,
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        items: _availableSemesters.map((semester) {
                                          return DropdownMenuItem(
                                            value: semester,
                                            child: Text(
                                              'Semester $semester',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedSemester = value;
                                              _loadUnits();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const Text(
                'Available Units',
                style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2196F3),
                ),
              ),
                    const SizedBox(height: 16),
              
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                        ),
                      )
                    else if (_availableUnits.isEmpty && _registeredUnits.isEmpty)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_outline,
                                size: 48,
                                color: Colors.green[400],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Successfully registered all units',
                      textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                  ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                    child: Text(
                                      'For special or missed previous units,\nplease select the year and semester you deferred',
                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green[700],
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                    ),
                          ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _availableUnits.length,
                  itemBuilder: (context, index) {
                    final unit = _availableUnits[index];
                    
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          '${unit['unit_code']} - ${unit['unit_name']}',
                          style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                          ),
                        ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                          'Course: ${unit['course_name']}',
                          style: TextStyle(
                                    fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                              ),
                              trailing: Transform.scale(
                                scale: 0.9,
                                child: Checkbox(
                        value: _selectedUnits.contains(unit['unit_id']),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedUnits.add(unit['unit_id']);
                            } else {
                              _selectedUnits.remove(unit['unit_id']);
                            }
                          });
                        },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                        ),
                                  activeColor: const Color(0xFF2196F3),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
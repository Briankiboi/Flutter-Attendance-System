import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/connectivity_service.dart';
import 'package:qr_attendance/widgets/connectivity_message.dart';
import 'dart:async';

class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({super.key});

  @override
  _StudentSignupScreenState createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isLoadingInitialData = true;
  bool _isLoadingCourses = false;
  String _errorMessage = '';
  bool _hasInternet = true;
  
  // Selected dropdown values
  String? _selectedDepartment;
  String? _selectedCourse;
  String? _selectedYear;
  String? _selectedSemester;
  
  // Create an instance of the SupabaseService
  final _supabaseService = SupabaseService();
  
  // Dropdown data storage
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _academicYears = [];
  List<Map<String, dynamic>> _semesters = [];
  
  late final ConnectivityService _connectivityService;
  NetworkStatus _networkStatus = NetworkStatus.online;
  StreamSubscription? _connectivitySubscription;
  
  @override
  void initState() {
    super.initState();
    _connectivityService = ConnectivityService();
    _setupConnectivity();
    
    // Force lowercase for email input
    _emailController.addListener(() {
      final text = _emailController.text;
      final lowercase = text.toLowerCase();
      if (text != lowercase) {
        _emailController.value = TextEditingValue(
          text: lowercase,
          selection: TextSelection.collapsed(offset: lowercase.length),
        );
      }
    });
  }
  
  Future<void> _setupConnectivity() async {
    await _connectivityService.initialize();
    _connectivitySubscription = _connectivityService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _networkStatus = status;
          _hasInternet = status == NetworkStatus.online;
        });
        
        if (status == NetworkStatus.online) {
          _fetchInitialData();
          
          // If department is selected, also refresh courses
          if (_selectedDepartment != null) {
            final dept = _departments.firstWhere(
              (d) => d['name'] == _selectedDepartment,
              orElse: () => {'id': ''},
            );
            if (dept['id'].isNotEmpty) {
              _fetchCoursesByDepartment(dept['id']);
            }
          }
        }
      }
    });
    
    // Initial data fetch
    _fetchInitialData();
  }
  
  // Fetch initial dropdown data (departments, years, semesters)
  Future<void> _fetchInitialData() async {
    if (_networkStatus != NetworkStatus.online) {
      setState(() {
        _isLoadingInitialData = false;
        _departments = [];  // Clear departments when offline
        _selectedDepartment = null;  // Reset selection
        _errorMessage = 'Please connect to the internet to load data';
      });
      return;
    }

    try {
    setState(() {
      _isLoadingInitialData = true;
      _errorMessage = '';
    });
    
      final result = await _supabaseService.getStudentSignupData();
      if (!mounted) return;
      
      if (result['success'] && result['data'] != null) {
        final data = result['data'];
        setState(() {
            _departments = List<Map<String, dynamic>>.from(data['departments']);
            _academicYears = List<Map<String, dynamic>>.from(data['academic_years']);
            _semesters = List<Map<String, dynamic>>.from(data['semesters']);
          _isLoadingInitialData = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _departments = [];  // Clear departments on error
          _selectedDepartment = null;  // Reset selection
          _errorMessage = result['message'] ?? 'Failed to load data. Please try again.';
          _isLoadingInitialData = false;
        });
        
        // Show error in snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load data. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _fetchInitialData();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _departments = [];  // Clear departments on error
        _selectedDepartment = null;  // Reset selection
        _errorMessage = 'Network error. Please check your connection and try again.';
        _isLoadingInitialData = false;
      });
      
      // Show error in snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error. Please check your connection and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _fetchInitialData();
            },
          ),
        ),
      );
    }
  }
  
  // Fetch courses when department is selected
  Future<void> _fetchCoursesByDepartment(String departmentId) async {
    if (_networkStatus != NetworkStatus.online) {
      setState(() {
        _isLoadingCourses = false;
        _courses = [];  // Clear courses when offline
        _selectedCourse = null;  // Reset selection
        _errorMessage = 'Please connect to the internet to load courses';
      });
      return;
    }

    try {
    setState(() {
      _isLoadingCourses = true;
      _courses = [];
        _selectedCourse = null;
      _errorMessage = '';
    });

      final result = await _supabaseService.getCoursesByDepartment(departmentId);
      if (!mounted) return;

      if (result['success'] && result['data'] != null) {
        setState(() {
            _courses = List<Map<String, dynamic>>.from(result['data']);
          _isLoadingCourses = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _courses = [];  // Clear courses on error
          _selectedCourse = null;  // Reset selection
          _errorMessage = result['message'] ?? 'Failed to load courses. Please try again.';
          _isLoadingCourses = false;
        });
        
        // Show error in snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load courses. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _fetchCoursesByDepartment(departmentId);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _courses = [];  // Clear courses on error
        _selectedCourse = null;  // Reset selection
        _errorMessage = 'Network error. Please check your connection and try again.';
        _isLoadingCourses = false;
      });
      
      // Show error in snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error. Please check your connection and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _fetchCoursesByDepartment(departmentId);
            },
          ),
        ),
      );
    }
  }
  
  bool _isSchoolEmail(String email) {
    return email.endsWith('@student.tharaka.ac.ke');
  }
  
  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasNumbers = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUppercase && hasLowercase && hasNumbers && hasSpecialCharacters;
  }

  String _getPasswordStrength(String password) {
    if (password.isEmpty) return '';
    if (password.length < 8) return 'Weak';
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasNumbers = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    int strength = 0;
    if (hasUppercase) strength++;
    if (hasLowercase) strength++;
    if (hasNumbers) strength++;
    if (hasSpecialCharacters) strength++;
    
    if (strength == 4) return 'Strong';
    if (strength >= 2) return 'Medium';
    return 'Weak';
  }

  Color _getPasswordStrengthColor(String strength) {
    switch (strength) {
      case 'Strong':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'Weak':
        return Colors.red;
      default:
        return Colors.transparent;
    }
  }
  
  String _getConnectivityMessage() {
    switch (_networkStatus) {
      case NetworkStatus.offline:
        return 'No internet connection. Please check your Wi-Fi or mobile data.';
      case NetworkStatus.slow:
        return 'Your internet connection is slow or unstable. Some features may not work properly.';
      case NetworkStatus.noData:
        return 'You\'re connected, but there\'s no data. Please check your data plan or network settings.';
      default:
        return 'Connection error. Please try again.';
    }
  }
  
  Future<void> _signUp() async {
    if (_networkStatus != NetworkStatus.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getConnectivityMessage()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        final String email = _emailController.text.trim();
        final String password = _passwordController.text.trim();
        
        final userData = {
          'name': _nameController.text.trim(),
          'email': email,
          'password': password,
          'department': _selectedDepartment,
          'course': _selectedCourse,
          'year': _selectedYear,
          'semester': _selectedSemester,
        };
        
        final result = await _supabaseService.studentSignup(userData);
        
        if (!mounted) return;
        
        if (!result['success']) {
          setState(() {
            _errorMessage = result['message'];
            _isLoading = false;
          });
          return;
        }
        
        final createdUserData = result['userData'];
        print('User data saved: ${createdUserData['name']}');
        
        setState(() {
          _isLoading = false;
        });
        
        Navigator.pushNamed(
          context, 
          AppRoutes.emailVerification,
          arguments: {
            'name': _nameController.text.trim(),
            'email': email,
            'password': password,
            'department': _selectedDepartment,
            'course': _selectedCourse,
            'year': _selectedYear,
            'semester': _selectedSemester,
            'isFromLogin': false,
          },
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Network error. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Signup'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Student Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 20),
                  Card(
                margin: EdgeInsets.zero,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                            if (_networkStatus != NetworkStatus.online)
                              ConnectivityMessage(
                                type: _networkStatus == NetworkStatus.offline 
                                  ? 'no_connection' 
                                  : _networkStatus == NetworkStatus.slow 
                                    ? 'slow' 
                                    : 'no_data',
                                isConnected: false,
                                  ),
                            
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                            prefixIcon: Icon(Icons.person),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                            SizedBox(height: 16),
                            
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'School Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                            prefixIcon: Icon(Icons.email),
                                hintText: 'username@student.thara.ac.ke',
                                filled: true,
                                fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!_isSchoolEmail(value)) {
                                  return 'Please use your @student.thara.ac.ke email';
                            }
                            return null;
                          },
                        ),
                            SizedBox(height: 16),
                            
                            // Department Dropdown
                            _buildDepartmentDropdown(),
                            SizedBox(height: 16),
                            
                            // Course Dropdown (dependent on department)
                            _buildCourseDropdown(),
                            SizedBox(height: 16),
                            
                            // Year Dropdown
                            _buildYearDropdown(),
                            SizedBox(height: 16),
                            
                            // Semester Dropdown
                            _buildSemesterDropdown(),
                            SizedBox(height: 16),
                            
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (!_isPasswordStrong(value)) {
                              return 'Password must have uppercase, lowercase, number, and special character';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {}); // Trigger rebuild for strength indicator
                          },
                        ),
                        if (_passwordController.text.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Text(
                                  'Password Strength: ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  _getPasswordStrength(_passwordController.text),
                                  style: TextStyle(
                                    color: _getPasswordStrengthColor(
                                      _getPasswordStrength(_passwordController.text),
                                    ),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                            prefixIcon: Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                                filled: true,
                                fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                            SizedBox(height: 24),
                            
                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                        SizedBox(
                          width: double.infinity,
                              height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                              ),
                                  elevation: 2,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                      width: 24,
                                      height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),
                            SizedBox(height: 16),
                            
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                                Text('Already have an account? '),
                            TextButton(
                              onPressed: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.login,
                                    );
                              },
                                  child: Text('Login'),
                              ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Widget _buildDepartmentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          decoration: InputDecoration(
            labelText: 'Department',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            prefixIcon: Icon(Icons.business),
            filled: true,
            fillColor: Colors.grey[50],
            errorStyle: TextStyle(color: Colors.red),
            errorText: _networkStatus != NetworkStatus.online 
              ? 'Internet connection required'
              : _errorMessage.isNotEmpty ? _errorMessage : null,
          ),
          items: _isLoadingInitialData
            ? []
            : _departments.map((dept) {
                return DropdownMenuItem<String>(
                  value: dept['name'],
                  child: Text(dept['name']),
                );
              }).toList(),
          onChanged: _isLoadingInitialData || _networkStatus != NetworkStatus.online
            ? null
            : (String? newValue) {
                if (newValue != null) {
                  // Find department ID and fetch courses
                  final dept = _departments.firstWhere(
                    (d) => d['name'] == newValue,
                    orElse: () => {'id': ''},
                  );
                  
                  setState(() {
                    _selectedDepartment = newValue;
                    // Don't reset course here anymore
                  });
                  
                  _fetchCoursesByDepartment(dept['id']);
                }
              },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your department';
            }
            return null;
          },
          hint: _isLoadingInitialData
            ? Text('Loading departments...')
            : _networkStatus != NetworkStatus.online
              ? Text('Connect to internet to load departments')
              : Text('Select Department'),
        ),
        if (_isLoadingInitialData)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildCourseDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCourse,
          decoration: InputDecoration(
            labelText: 'Course',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            prefixIcon: Icon(Icons.school),
            filled: true,
            fillColor: Colors.grey[50],
            errorStyle: TextStyle(color: Colors.red),
          ),
          items: _selectedDepartment == null || _isLoadingCourses
            ? []
            : _courses.map((course) {
                return DropdownMenuItem<String>(
                  value: course['name'],
                  child: Text(course['name']),
                );
              }).toList(),
          onChanged: _selectedDepartment == null || _isLoadingCourses || _networkStatus != NetworkStatus.online
            ? null
            : (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCourse = newValue;
                  });
                }
              },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your course';
            }
            return null;
          },
          hint: _selectedDepartment == null
            ? Text('Select department first')
            : _isLoadingCourses
              ? Text('Loading courses...')
              : _networkStatus != NetworkStatus.online
                ? Text('Connect to internet to load courses')
                : Text('Select Course'),
        ),
        if (_isLoadingCourses)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedYear,
      decoration: InputDecoration(
        labelText: 'Year of Study',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        prefixIcon: Icon(Icons.calendar_today),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _isLoadingInitialData
        ? []
        : _academicYears.map((year) {
            return DropdownMenuItem<String>(
              value: year['year'],
              child: Text(year['year']),
            );
          }).toList(),
      onChanged: _isLoadingInitialData || _networkStatus != NetworkStatus.online
        ? null
        : (String? newValue) {
            setState(() {
              _selectedYear = newValue;
            });
          },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your year of study';
        }
        return null;
      },
      hint: _isLoadingInitialData
        ? Text('Loading years...')
        : _networkStatus != NetworkStatus.online
          ? Text('Connect to internet to load years')
          : Text('Select Year'),
    );
  }

  Widget _buildSemesterDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSemester,
      decoration: InputDecoration(
        labelText: 'Semester',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        prefixIcon: Icon(Icons.schedule),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _isLoadingInitialData
        ? []
        : _semesters.map((semester) {
            return DropdownMenuItem<String>(
              value: semester['name'],
              child: Text(semester['name']),
            );
          }).toList(),
      onChanged: _isLoadingInitialData || _networkStatus != NetworkStatus.online
        ? null
        : (String? newValue) {
            setState(() {
              _selectedSemester = newValue;
            });
          },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your semester';
        }
        return null;
      },
      hint: _isLoadingInitialData
        ? Text('Loading semesters...')
        : _networkStatus != NetworkStatus.online
          ? Text('Connect to internet to load semesters')
          : Text('Select Semester'),
    );
  }
} 
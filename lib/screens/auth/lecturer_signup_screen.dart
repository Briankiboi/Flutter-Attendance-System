import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/connectivity_service.dart';
import 'package:qr_attendance/widgets/connectivity_message.dart';
import 'dart:async';

class LecturerSignupScreen extends StatefulWidget {
  const LecturerSignupScreen({super.key});

  @override
  _LecturerSignupScreenState createState() => _LecturerSignupScreenState();
}

class _LecturerSignupScreenState extends State<LecturerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _hasInternet = true;
  String _errorMessage = '';
  
  // Selected dropdown values
  String? _selectedDepartment;
  String? _selectedOccupation;
  String? _selectedEmploymentType;
  String? _selectedGender;

  // Department list
  List<Map<String, dynamic>> _departments = [];
  bool _loadingDepartments = true;
  
  // Create an instance of the SupabaseService
  final _supabaseService = SupabaseService();
  
  late final ConnectivityService _connectivityService;
  NetworkStatus _networkStatus = NetworkStatus.online;
  StreamSubscription? _connectivitySubscription;
  
  final List<String> _occupations = [
    'Professor',
    'Doctor',
    'Master Lecturer',
    'Senior Lecturer',
    'Lecturer',
    'Assistant Staff',
  ];

  final List<String> _employmentTypes = [
    'Part Time',
    'Full Time',
  ];

  final List<String> _genders = ['Male', 'Female'];
  
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
          _loadDepartments();
        }
      }
    });
    
    // Initial data fetch
    _loadDepartments();
  }
  
  Future<void> _loadDepartments() async {
    if (_networkStatus != NetworkStatus.online) {
      setState(() {
        _loadingDepartments = false;
        _departments = [];  // Clear departments when offline
        _selectedDepartment = null;  // Reset selection
        _errorMessage = 'Please connect to the internet to load departments';
      });
      return;
    }

    try {
      setState(() {
        _loadingDepartments = true;
        _errorMessage = '';
      });

      final result = await _supabaseService.getLecturerDepartments();
      if (!mounted) return;

      if (result['success'] && result['data'] != null) {
        setState(() {
          _departments = List<Map<String, dynamic>>.from(result['data']);
          _loadingDepartments = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _departments = [];  // Clear departments on error
          _selectedDepartment = null;  // Reset selection
          _errorMessage = result['message'] ?? 'Failed to load departments. Please try again.';
          _loadingDepartments = false;
        });
        
        // Show error in snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load departments. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _loadDepartments();
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
        _loadingDepartments = false;
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
              _loadDepartments();
            },
          ),
        ),
      );
    }
  }
  
  bool _isSchoolEmail(String email) {
    return email.endsWith('@tharaka.ac.ke');
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

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    
    // Check for numbers
    if (value.contains(RegExp(r'[0-9]'))) {
      return 'Name cannot contain numbers';
    }
    
    // Check for at least two words (first and last name)
    List<String> nameParts = value.trim().split(' ');
    if (nameParts.length < 2) {
      return 'Please enter both first and last name';
    }
    
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Confirm password validation
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _signUp() async {
    if (_networkStatus != NetworkStatus.online) {
      String message = '';
      switch (_networkStatus) {
        case NetworkStatus.offline:
          message = 'No internet connection. Please check your connection and try again.';
          break;
        case NetworkStatus.slow:
          message = 'Your connection is unstable. Please try again when you have a better connection.';
          break;
        case NetworkStatus.noData:
          message = 'No data connection. Please check your data plan and try again.';
          break;
        default:
          message = 'Connection error. Please try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
          'occupation': _selectedOccupation,
          'employmentType': _selectedEmploymentType,
          'gender': _selectedGender,
        };
        
        // Show processing message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing signup request...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        final result = await _supabaseService.lecturerSignup(userData);
        
        if (!mounted) return;
        
        if (!result['success']) {
          // Log detailed error
          print('Signup error: ${result['message']}');
          
          setState(() {
            _errorMessage = result['message'] ?? 'An unknown error occurred';
            _isLoading = false;
          });
          
          // Show error in snackbar too
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
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
            'occupation': _selectedOccupation,
            'employmentType': _selectedEmploymentType,
            'gender': _selectedGender,
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
        title: Text('Lecturer Signup'),
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
                    'Create Lecturer Account',
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
                              validator: _validateName,
                            ),
                            SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.email),
                                hintText: 'username@tharaka.ac.ke',
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!_isSchoolEmail(value)) {
                                  return 'Please use your @tharaka.ac.ke email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            
                            // Department Dropdown
                            _buildDepartmentDropdown(),
                            SizedBox(height: 16),
                            
                            // Occupation Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedOccupation,
                              decoration: InputDecoration(
                                labelText: 'Occupation',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.work),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: _occupations.map((String occupation) {
                                return DropdownMenuItem(
                                  value: occupation,
                                  child: Text(occupation),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedOccupation = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your occupation';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            
                            // Employment Type Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedEmploymentType,
                              decoration: InputDecoration(
                                labelText: 'Employment Type',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.business_center),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: _employmentTypes.map((String type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedEmploymentType = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your employment type';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            
                            // Gender Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.person_outline),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: _genders.map((String gender) {
                                return DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedGender = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your gender';
                                }
                                return null;
                              },
                            ),
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
                              validator: _validatePassword,
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
                              validator: _validateConfirmPassword,
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
                                      AppRoutes.lecturerLogin,
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
            // Show error state when offline or error
            errorStyle: TextStyle(color: Colors.red),
            errorText: _networkStatus != NetworkStatus.online 
              ? 'Internet connection required'
              : _errorMessage.isNotEmpty ? _errorMessage : null,
          ),
          items: _loadingDepartments
            ? <DropdownMenuItem<String>>[]
            : _departments.map((dept) {
                return DropdownMenuItem<String>(
                  value: dept['name'],
                  child: Text(dept['name']),
                );
              }).toList(),
          onChanged: _loadingDepartments || _networkStatus != NetworkStatus.online
            ? null
            : (String? newValue) {
                setState(() {
                  _selectedDepartment = newValue;
                });
              },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your department';
            }
            return null;
          },
          hint: _loadingDepartments
            ? Text('Loading departments...')
            : _networkStatus != NetworkStatus.online
              ? Text('Connect to internet to load departments')
              : Text('Select Department'),
        ),
        if (_loadingDepartments)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
} 
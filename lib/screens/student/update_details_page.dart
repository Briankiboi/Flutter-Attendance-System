import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:qr_attendance/services/supabase_service.dart';

class UpdateDetailsPage extends StatefulWidget {
  const UpdateDetailsPage({super.key});

  @override
  State<UpdateDetailsPage> createState() => _UpdateDetailsPageState();
}

class _UpdateDetailsPageState extends State<UpdateDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _email;
  String? _selectedDepartment;
  String? _selectedCourse;
  String? _selectedYear;
  String? _selectedSemester;
  String? _currentStoredPassword;
  String? _userId;
  String? _studentId;
  
  // Original values to track changes
  String? _originalName;
  String? _originalDepartment;
  String? _originalCourse;
  String? _originalYear;
  String? _originalSemester;
  
  bool _obscureCurrentPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isChangingPassword = false;
  String _successMessage = '';
  String _errorMessage = '';

  // Supabase service
  final _supabaseService = SupabaseService();
  
  final Map<String, List<String>> _departmentCourses = {
    'Computer Science': ['Computer Science', 'Software Engineering', 'Data Science'],
    'Engineering': ['Mechanical Engineering', 'Electrical Engineering', 'Civil Engineering'],
    'Business': ['Business Administration', 'Marketing', 'Finance'],
    'Education': ['Math/bio', 'phys/chem', 'kiswa/history'],
  };
  
  final List<String> _years = ['1', '2', '3', '4'];
  final List<String> _semesters = ['1', '2'];
  
  List<String> _getCourses() {
    return _selectedDepartment != null 
        ? _departmentCourses[_selectedDepartment] ?? []
        : [];
  }
  
  // Helper method to format year for display
  String _formatYearForDisplay(String year) {
    return 'Year $year';
  }
  
  // Helper method to extract year value from display text
  String _extractYearValue(String displayText) {
    return displayText.replaceAll('Year ', '');
  }
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get data from navigation arguments if available
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      // If data is passed directly from dashboard, use it to pre-populate fields
      if (args.containsKey('userData') && args['userData'] != null) {
        final userData = args['userData'] as Map<String, dynamic>;
        _populateUserDataFromArgs(userData);
      }
    }
  }
  
  void _populateUserDataFromArgs(Map<String, dynamic> userData) {
    if (mounted) {
      setState(() {
        _email = userData['email'];
        _nameController.text = userData['name'] ?? '';
        _originalName = userData['name'];
        
        _selectedDepartment = userData['department'];
        _originalDepartment = userData['department'];
        
        _selectedCourse = userData['course'];
        _originalCourse = userData['course'];
        
        // Process year value
        String yearValue = (userData['year'] ?? '').toString().replaceAll('Year ', '');
        _selectedYear = yearValue;
        _originalYear = yearValue;
        
        _selectedSemester = userData['semester']?.toString().replaceAll('Semester ', '');
        _originalSemester = _selectedSemester;
        
        _userId = userData['id'];
        _studentId = userData['student_id'];
        _currentStoredPassword = userData['password'];
      });
      
      // Ensure course list contains the selected course
      _ensureCoursesContainSelected();
    }
  }
  
  void _ensureCoursesContainSelected() {
    if (_selectedDepartment != null && _selectedCourse != null) {
      if (!_departmentCourses.containsKey(_selectedDepartment)) {
        _departmentCourses[_selectedDepartment!] = [_selectedCourse!];
      } else if (!_departmentCourses[_selectedDepartment]!.contains(_selectedCourse)) {
        _departmentCourses[_selectedDepartment]!.add(_selectedCourse!);
      }
    }
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    
    try {
      // Get current user data from Supabase service
      final userData = _supabaseService.getCurrentUser();
      
      if (userData != null) {
        // Store original values to track changes
        _originalName = userData['name'];
        _originalDepartment = userData['department'];
        _originalCourse = userData['course'];
        
        // Process year value
        String yearValue = (userData['year'] ?? '').toString().replaceAll('Year ', '');
        _originalYear = yearValue;
        
        String semesterValue = (userData['semester'] ?? '').toString().replaceAll('Semester ', '');
        _originalSemester = semesterValue;
        
        // Store current password for verification
        _currentStoredPassword = userData['password'];
        
        // Ensure the full department-course information is displayed correctly
        final String? department = userData['department'];
        final String? course = userData['course'];
        
        // Handle compound course names like "Computer Science - Software Engineering"
        // by ensuring both department and course are properly set
        
        // First, check if course contains department info (e.g., "Computer Science - Software Engineering")
        String? processedDepartment = department;
        String? processedCourse = course;
        
        if (course != null && course.contains('-')) {
          // If course contains a hyphen, it might be a compound name
          // Add both the full name and components to the appropriate dropdown lists
          final parts = course.split('-').map((part) => part.trim()).toList();
          
          if (parts.length > 1) {
            // First part is often the department
            if (department == null || department.isEmpty || department == parts[0]) {
              processedDepartment = parts[0];
              
              // Using the full course name as it appears in the dashboard
              processedCourse = course;
              
              // Ensure this compound name is available in dropdown
              if (!_departmentCourses.containsKey(processedDepartment)) {
                _departmentCourses[processedDepartment] = [processedCourse];
              } else if (!_departmentCourses[processedDepartment]!.contains(processedCourse)) {
                _departmentCourses[processedDepartment]!.add(processedCourse);
              }
            }
          }
        }
        
        setState(() {
          _email = userData['email'];
          _nameController.text = userData['name'] ?? '';
          _selectedDepartment = processedDepartment;
          _selectedCourse = processedCourse;
          _selectedYear = yearValue;
          _selectedSemester = semesterValue;
          _userId = userData['id'];
          _studentId = userData['student_id'];
        });
        
        // Ensure the course list contains the selected course
        _ensureCoursesContainSelected();
        
        print('Loaded user data for profile update: Name=${_nameController.text}, Department=$_selectedDepartment, Course=$_selectedCourse, Year=$_selectedYear, Semester=$_selectedSemester');
      } else {
        print('No user data available - user not logged in');
        setState(() {
          _errorMessage = 'User data not found. Please log in again.';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Enhanced password validation method
  String? _validatePassword(String? value) {
    if (_isChangingPassword) {
      if (value == null || value.isEmpty) {
        return 'Password cannot be empty';
      }
      if (value.length < 8) {
        return 'Password must be at least 8 characters long';
      }
      // Check for complexity
      if (!RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
          .hasMatch(value)) {
        return 'Password must include uppercase, lowercase, number, and special character';
      }
    }
    return null;
  }

  // Comprehensive profile update method
  Future<void> _updateProfile() async {
    // Validate form before submission
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    
    try {
      // Prepare update data with all fields
      Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'department': _selectedDepartment,
        'course': _selectedCourse,
        'year': 'Year $_selectedYear',
        'semester': 'Semester $_selectedSemester',
      };

      // Check if password is being changed
      if (_isChangingPassword) {
        // Verify current password
        bool isCurrentPasswordCorrect = await _supabaseService.verifyPassword(
          email: _email!, 
          password: _currentPasswordController.text
        );

        if (!isCurrentPasswordCorrect) {
          setState(() {
            _errorMessage = 'Current password is incorrect';
            _isLoading = false;
          });
          return;
        }
        
        // Update password in Supabase
        final passwordResult = await _supabaseService.updatePassword(
          email: _email!, 
          newPassword: _passwordController.text
        );

        if (!passwordResult['success']) {
          setState(() {
            _errorMessage = passwordResult['message'] ?? 'Failed to update password';
            _isLoading = false;
          });
          return;
        }
        
        // Add password to update data
        updateData['password'] = _passwordController.text;
        }
        
      // Perform profile update in Supabase
      final result = await _supabaseService.updateStudentProfile(
        studentId: _studentId!, 
        updateData: updateData
      );
        
      if (result['success']) {
        // Update local cache
        _supabaseService.updateCurrentUserCache(updateData);
        
        print('Update successful, formatting data to pass back to dashboard');

        setState(() {
          _successMessage = 'Profile updated successfully';
          _isLoading = false;
        });

        // Ensure we pass back properly formatted data with consistent format
        final updatedUserData = {
          ...updateData,
          'email': _email,
          'student_id': _studentId,
          // Make sure year and semester are correctly formatted
          'year': _selectedYear, // Just the number without "Year " prefix
          'semester': _selectedSemester, // Just the number without "Semester " prefix
        };
        
        print('Returning to dashboard with updated name: ${updatedUserData['name']}');

        // Navigate back to dashboard with updated data
        Navigator.of(context).pop({
          'updated': true,
          'userData': updatedUserData
        });
      } else {
        setState(() {
          // Check if the message is about no changes
          if (result['message'] == 'No changes detected') {
            _successMessage = 'No changes were made to your profile';
          } else {
            _errorMessage = result['message'] ?? 'Failed to update profile';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
      print('Error in profile update: $e');
    }
  }

  // Build password change section
  Widget _buildPasswordChangeSection() {
    if (!_isChangingPassword) {
      return SizedBox.shrink();
    }

    return Column(
      children: [
        TextFormField(
          controller: _currentPasswordController,
          decoration: InputDecoration(
            labelText: 'Current Password',
            prefixIcon: Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureCurrentPassword 
                  ? Icons.visibility 
                  : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscureCurrentPassword = !_obscureCurrentPassword;
                });
              },
            ),
          ),
          obscureText: _obscureCurrentPassword,
          validator: (value) {
            if (_isChangingPassword && (value == null || value.isEmpty)) {
              return 'Please enter your current password';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword 
                  ? Icons.visibility 
                  : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          obscureText: _obscurePassword,
          validator: _validatePassword,
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword 
                  ? Icons.visibility 
                  : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          obscureText: _obscureConfirmPassword,
          validator: (value) {
            if (_isChangingPassword) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
            }
            return null;
          },
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Profile'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
                  child: Padding(
          padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                // Existing form fields for name, department, course, etc.
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                SizedBox(height: 16),

                // Department Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedDepartment,
                            decoration: InputDecoration(
                              labelText: 'Department',
                    prefixIcon: Icon(Icons.school),
                            ),
                  items: _departmentCourses.keys
                      .map((dept) => DropdownMenuItem(
                            value: dept,
                            child: Text(dept),
                          ))
                      .toList(),
                  onChanged: (value) {
                              setState(() {
                      _selectedDepartment = value;
                      _selectedCourse = null; // Reset course when department changes
                              });
                            },
                            validator: (value) {
                    if (value == null) {
                                return 'Please select a department';
                              }
                              return null;
                            },
                          ),
                SizedBox(height: 16),

                // Course Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCourse,
                            decoration: InputDecoration(
                              labelText: 'Course',
                    prefixIcon: Icon(Icons.book),
                              ),
                  items: _getCourses()
                      .map((course) => DropdownMenuItem(
                                value: course,
                                child: Text(course),
                          ))
                      .toList(),
                  onChanged: (value) {
                              setState(() {
                      _selectedCourse = value;
                              });
                            },
                            validator: (value) {
                    if (value == null) {
                                return 'Please select a course';
                              }
                              return null;
                            },
                          ),
                SizedBox(height: 16),

                // Year Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedYear,
                            decoration: InputDecoration(
                              labelText: 'Year of Study',
                              prefixIcon: Icon(Icons.calendar_today),
                              ),
                  items: _years
                      .map((year) => DropdownMenuItem(
                                value: year,
                                child: Text('Year $year'),
                          ))
                      .toList(),
                  onChanged: (value) {
                              setState(() {
                      _selectedYear = value;
                              });
                            },
                            validator: (value) {
                    if (value == null) {
                      return 'Please select year of study';
                              }
                              return null;
                            },
                          ),
                SizedBox(height: 16),

                // Semester Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedSemester,
                            decoration: InputDecoration(
                              labelText: 'Semester',
                    prefixIcon: Icon(Icons.calendar_month),
                              ),
                  items: _semesters
                      .map((semester) => DropdownMenuItem(
                                value: semester,
                                child: Text('Semester $semester'),
                          ))
                      .toList(),
                  onChanged: (value) {
                              setState(() {
                      _selectedSemester = value;
                              });
                            },
                            validator: (value) {
                    if (value == null) {
                      return 'Please select semester';
                              }
                              return null;
                            },
                          ),
                SizedBox(height: 16),

                // Password Change Toggle
                          SwitchListTile(
                            title: Text('Change Password'),
                            value: _isChangingPassword,
                  onChanged: (bool value) {
                              setState(() {
                                _isChangingPassword = value;
                      // Reset password fields when toggling
                                if (!value) {
                                  _currentPasswordController.clear();
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                }
                              });
                            },
                          ),

                // Conditional Password Change Section
                _buildPasswordChangeSection(),

                // Error Message Display
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                                ),
                              ),

                // Success Message Display
                if (_successMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _successMessage,
                      style: TextStyle(color: Colors.green),
                      textAlign: TextAlign.center,
                            ),
                  ),

                // Update Profile Button
                          ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Update Profile',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                  ),
                ),
              ),
            ),
    );
  }
} 
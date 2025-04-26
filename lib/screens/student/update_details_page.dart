import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UpdateDetailsPage extends StatefulWidget {
  const UpdateDetailsPage({Key? key}) : super(key: key);

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
  
  bool _obscureCurrentPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isChangingPassword = false;
  String _successMessage = '';
  String _errorMessage = '';
  
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
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('current_user_email');
      
      if (email != null && email.isNotEmpty) {
        final userDataString = prefs.getString(email);
        if (userDataString != null) {
          final userData = json.decode(userDataString) as Map<String, dynamic>;
          
          // Store current password for verification
          _currentStoredPassword = userData['password'];
          
          setState(() {
            _email = email;
            _nameController.text = userData['name'] ?? '';
            _selectedDepartment = userData['department'];
            _selectedCourse = userData['course'];
            _selectedYear = userData['year'];
            _selectedSemester = userData['semester'];
          });
          
          // Print loaded data for debugging
          print('Loaded user data: Name=${_nameController.text}, Dept=${_selectedDepartment}, Course=${_selectedCourse}, Year=${_selectedYear}, Semester=${_selectedSemester}');
        } else {
          print('No user data found for email: $email');
          setState(() {
            _email = email;
            _nameController.text = prefs.getString('user_name_$email') ?? prefs.getString('current_user_name') ?? '';
            _selectedDepartment = prefs.getString('user_department_$email') ?? prefs.getString('current_user_department');
            _selectedCourse = prefs.getString('user_course_$email') ?? prefs.getString('current_user_course');
            _selectedYear = prefs.getString('user_year_$email') ?? prefs.getString('current_user_year');
            _selectedSemester = prefs.getString('user_semester_$email') ?? prefs.getString('current_user_semester');
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _errorMessage = 'Error loading user data. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _updateUserDetails() async {
    // Reset messages
    setState(() {
      _errorMessage = '';
      _successMessage = '';
    });
    
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final prefs = await SharedPreferences.getInstance();
        
        if (_email == null || _email!.isEmpty) {
          setState(() {
            _errorMessage = 'User email is not available. Please log in again.';
            _isLoading = false;
          });
          return;
        }
        
        // Get existing user data
        final userDataString = prefs.getString(_email!);
        Map<String, dynamic> userData;
        
        if (userDataString != null) {
          userData = json.decode(userDataString) as Map<String, dynamic>;
        } else {
          // If user data doesn't exist, create a new map with available data
          userData = {
            'email': _email!,
            'registrationDate': DateTime.now().toIso8601String(),
          };
        }
        
        // Password verification and update
        if (_isChangingPassword) {
          // Verify current password
          if (_currentPasswordController.text.trim() != _currentStoredPassword) {
            setState(() {
              _errorMessage = 'Current password is incorrect';
              _isLoading = false;
            });
            return;
          }
          
          // Verify new password is different from current
          if (_passwordController.text.trim() == _currentStoredPassword) {
            setState(() {
              _errorMessage = 'New password must be different from current password';
              _isLoading = false;
            });
            return;
          }
          
          // Update password
          userData['password'] = _passwordController.text.trim();
          print('Password updated successfully');
        }
        
        // Update the user data with new values
        userData['name'] = _nameController.text.trim();
        userData['department'] = _selectedDepartment;
        userData['course'] = _selectedCourse;
        userData['year'] = _selectedYear;
        userData['semester'] = _selectedSemester;
        
        // Debug output
        print('Updating user data: Name=${userData['name']}, Dept=${userData['department']}, Course=${userData['course']}, Year=${userData['year']}, Semester=${userData['semester']}');
        
        // Save the updated data to main user data store FIRST
        // This is the primary source of truth
        final jsonData = json.encode(userData);
        await prefs.setString(_email!, jsonData);
        print('Saved complete user data to main storage');
        
        // Then update the individual fields as backup
        await prefs.setString('current_user_name', _nameController.text.trim());
        await prefs.setString('current_user_department', _selectedDepartment ?? '');
        await prefs.setString('current_user_course', _selectedCourse ?? '');
        await prefs.setString('current_user_year', _selectedYear ?? '');
        await prefs.setString('current_user_semester', _selectedSemester ?? '');
        
        await prefs.setString('user_name_$_email', _nameController.text.trim());
        await prefs.setString('user_department_$_email', _selectedDepartment ?? '');
        await prefs.setString('user_course_$_email', _selectedCourse ?? '');
        await prefs.setString('user_year_$_email', _selectedYear ?? '');
        await prefs.setString('user_semester_$_email', _selectedSemester ?? '');
        
        // Verify the data was saved correctly
        final verifyData = prefs.getString(_email!);
        if (verifyData != null) {
          final verifiedUserData = json.decode(verifyData) as Map<String, dynamic>;
          print('Verification - saved user data: Name=${verifiedUserData['name']}, Year=${verifiedUserData['year']}, Semester=${verifiedUserData['semester']}');
        }
        
        setState(() {
          _successMessage = 'Profile updated successfully!';
          _isLoading = false;
          // Clear password fields after successful update
          _currentPasswordController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          _isChangingPassword = false;
        });
        
        // After successful update, wait a moment to show success message
        // then log the user out to role selection page for effective refresh
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            // Clear current login session (partial logout)
            _clearCurrentLoginSession();
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profile updated. Please log in again with your updated details.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            
            // Navigate directly to role selection page
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/role-selection', 
              (route) => false, // Clear all routes in the stack
            );
          }
        });
      } catch (e) {
        print('Error updating user data: $e');
        setState(() {
          _errorMessage = 'An error occurred while updating your profile. Please try again.';
          _isLoading = false;
        });
      }
    }
  }
  
  // Method to clear current login session data
  Future<void> _clearCurrentLoginSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Only clear session data, not user profile data
      await prefs.remove('isLoggedIn');
      await prefs.remove('current_user_email');
      await prefs.remove('currentUser');
      
      // Clear any dashboard-specific temporary data
      await prefs.remove('current_profile_loaded');
      await prefs.remove('current_timetable_loaded');
      
      print('Current login session cleared after profile update');
    } catch (e) {
      print('Error clearing current login session: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        child: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Update Your Profile',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          // Success message
                          if (_successMessage.isNotEmpty)
                            Container(
                              padding: EdgeInsets.all(10),
                              margin: EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _successMessage,
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Error message
                          if (_errorMessage.isNotEmpty)
                            Container(
                              padding: EdgeInsets.all(10),
                              margin: EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Email field (disabled)
                          TextFormField(
                            initialValue: _email,
                            enabled: false, // Disable email editing
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Your email cannot be changed',
                              prefixIcon: Icon(Icons.email),
                              filled: true,
                              fillColor: Colors.grey.shade200,
                            ),
                          ),
                          SizedBox(height: 16),
                          // Name field with auto capitalize
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person),
                              hintText: 'Enter your full name',
                            ),
                            textCapitalization: TextCapitalization.words,
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                // Auto-capitalize first letter of each word
                                final words = value.split(' ');
                                final capitalizedWords = words.map((word) {
                                  if (word.isEmpty) return '';
                                  return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
                                }).join(' ');
                                
                                if (value != capitalizedWords) {
                                  _nameController.value = TextEditingValue(
                                    text: capitalizedWords,
                                    selection: TextSelection.collapsed(offset: capitalizedWords.length),
                                  );
                                }
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              if (RegExp(r'[0-9]').hasMatch(value)) {
                                return 'Name cannot contain numbers';
                              }
                              // Check if it has at least first and last name
                              final nameParts = value.trim().split(' ');
                              if (nameParts.length < 2 || nameParts.any((part) => part.isEmpty)) {
                                return 'Please enter both first and last name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Department dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedDepartment,
                            decoration: InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.business),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final department in _departmentCourses.keys)
                                DropdownMenuItem(
                                  value: department,
                                  child: Text(department),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedDepartment = value;
                                // Reset course if department changes
                                _selectedCourse = null;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a department';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Course dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCourse,
                            decoration: InputDecoration(
                              labelText: 'Course',
                              prefixIcon: Icon(Icons.school),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final course in _getCourses())
                                DropdownMenuItem(
                                  value: course,
                                  child: Text(course),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCourse = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a course';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Year of study dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedYear,
                            decoration: InputDecoration(
                              labelText: 'Year of Study',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final year in _years)
                                DropdownMenuItem(
                                  value: year,
                                  child: Text('Year $year'),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedYear = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your year of study';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Semester dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedSemester,
                            decoration: InputDecoration(
                              labelText: 'Semester',
                              prefixIcon: Icon(Icons.event),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final semester in _semesters)
                                DropdownMenuItem(
                                  value: semester,
                                  child: Text('Semester $semester'),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedSemester = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your semester';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          
                          // Password Update Toggle
                          SwitchListTile(
                            title: Text(
                              'Change Password',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            value: _isChangingPassword,
                            onChanged: (value) {
                              setState(() {
                                _isChangingPassword = value;
                                // Clear password fields when toggling
                                if (!value) {
                                  _currentPasswordController.clear();
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                }
                              });
                            },
                            activeColor: Colors.blue,
                          ),
                          
                          if (_isChangingPassword) ...[
                            SizedBox(height: 16),
                            // Current Password field
                            TextFormField(
                              controller: _currentPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Current Password',
                                prefixIcon: Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureCurrentPassword = !_obscureCurrentPassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscureCurrentPassword,
                              validator: (value) {
                                if (_isChangingPassword) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your current password';
                                  }
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            // New Password field
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'New Password',
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
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (_isChangingPassword) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a new password';
                                  }
                                  if (value.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  if (value == _currentPasswordController.text) {
                                    return 'New password must be different from current password';
                                  }
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            // Confirm password field
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
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
                              ),
                              obscureText: _obscureConfirmPassword,
                              validator: (value) {
                                if (_isChangingPassword) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your new password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                          SizedBox(height: 24),
                          // Update button
                          ElevatedButton(
                            onPressed: _updateUserDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 15),
                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text('Update Profile'),
                          ),
                        ],
                      ),
                    ),
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
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
} 
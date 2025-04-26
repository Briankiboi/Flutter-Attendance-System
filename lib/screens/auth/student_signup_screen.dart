import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StudentSignupScreen extends StatefulWidget {
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
  String _errorMessage = '';
  
  String? _selectedDepartment;
  String? _selectedCourse;
  String? _selectedYear;
  String? _selectedSemester;
  
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
  
  bool _isSchoolEmail(String email) {
    // This is a simple check. In a real app, you'd validate against your school's domain
    return email.endsWith('.edu') || email.endsWith('.ac.ke');
  }
  
  bool _isPasswordStrong(String password) {
    return password.length >= 8;
  }
  
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        // Get SharedPreferences instance
        final prefs = await SharedPreferences.getInstance();
        
        // Clean up the email to ensure consistent lookup
        final String email = _emailController.text.trim();
        
        // Check if email already exists
        if (prefs.containsKey(email)) {
          setState(() {
            _errorMessage = 'An account with this email already exists';
            _isLoading = false;
          });
          return;
        }
        
        // Create user data map - explicitly ensure password is included
        final String password = _passwordController.text.trim();
        final userData = {
          'name': _nameController.text.trim(),
          'email': email,
          'password': password,
          'department': _selectedDepartment,
          'course': _selectedCourse,
          'year': _selectedYear,
          'semester': _selectedSemester,
          'registrationDate': DateTime.now().toIso8601String(),
        };
        
        // CRITICAL: Double check password is in the map and not null
        if (userData['password'] == null || (userData['password'] as String).isEmpty) {
          print('CRITICAL ERROR: Password is missing from userData map!');
          print('Original password: $password');
          print('Entered password length: ${password.length}');
          // Force set it again with explicit casting to ensure it's stored correctly
          userData['password'] = password.toString();
          print('Fixed password in userData: ${userData['password']}');
        }
        
        // Create JSON with explicit handling of the password field
        final jsonString = json.encode(userData);
        final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
        if (jsonMap['password'] == null || (jsonMap['password'] as String).isEmpty) {
          print('CRITICAL ERROR: Password lost during JSON encoding!');
          jsonMap['password'] = password.toString();
        }
        
        final String jsonData = json.encode(jsonMap);
        
        // Store user data using email as key
        await prefs.setString(email, jsonData);
        
        // Mark this email as the current user
        await prefs.setString('currentUser', email);
        
        // Verify data was stored correctly
        final String? storedData = prefs.getString(email);
        if (storedData != null) {
          final Map<String, dynamic> decodedData = json.decode(storedData);
          print('VERIFICATION - Stored user data: $decodedData');
          print('VERIFICATION - Password stored correctly: ${decodedData.containsKey('password') && decodedData['password'] == password}');
          print('VERIFICATION - Password value: ${decodedData['password'] ?? 'STILL NULL!'}');
        }
        
        setState(() {
          _isLoading = false;
        });
        
        // Navigate to email verification page
        Navigator.pushNamed(
          context, 
          AppRoutes.emailVerification,
          arguments: {
            'name': _nameController.text.trim(),
            'email': email,
            'password': password, // Include password in navigation args
            'department': _selectedDepartment,
            'course': _selectedCourse,
            'year': _selectedYear,
            'semester': _selectedSemester,
            'isFromLogin': false,
          },
        );
      } catch (e) {
        print('Error during signup: $e');
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
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
              child: Card(
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
                        Text(
                          'Create Student Account',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 20),
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
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person),
                            hintText: 'e.g. Brian Kiboi',
                          ),
                          textCapitalization: TextCapitalization.words,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              // Auto-capitalize first letter of each word, ensure rest are lowercase
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
                        SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedDepartment,
                          decoration: InputDecoration(
                            labelText: 'Department',
                            prefixIcon: Icon(Icons.business),
                          ),
                          items: _departmentCourses.keys.map((String department) {
                            return DropdownMenuItem<String>(
                              value: department,
                              child: Text(department),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDepartment = newValue;
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
                        SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedCourse,
                          decoration: InputDecoration(
                            labelText: 'Course',
                            prefixIcon: Icon(Icons.school),
                          ),
                          items: _getCourses().map((String course) {
                            return DropdownMenuItem<String>(
                              value: course,
                              child: Text(course),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCourse = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a course';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedYear,
                          decoration: InputDecoration(
                            labelText: 'Year of Study',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          items: _years.map((String year) {
                            return DropdownMenuItem<String>(
                              value: year,
                              child: Text(year),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedYear = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a year of study';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedSemester,
                          decoration: InputDecoration(
                            labelText: 'Semester',
                            prefixIcon: Icon(Icons.school),
                          ),
                          items: _semesters.map((String semester) {
                            return DropdownMenuItem<String>(
                              value: semester,
                              child: Text(semester),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedSemester = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a semester';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'School Email',
                            hintText: 'e.g., admission_no@student.tharaka.ac.ke',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!_isSchoolEmail(value)) {
                              return 'Please use a valid school email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
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
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (!_isPasswordStrong(value)) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
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
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 15),
                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Sign Up'),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account?'),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.login);
                              },
                              child: Text(
                                'Login here',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
} 
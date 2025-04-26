import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LecturerSignupScreen extends StatefulWidget {
  @override
  _LecturerSignupScreenState createState() => _LecturerSignupScreenState();
}

class _LecturerSignupScreenState extends State<LecturerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lectureNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController();
  final _courseController = TextEditingController();
  final _occupationController = TextEditingController();
  final _employmentTypeController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _errorMessage = '';
  
  final Map<String, List<String>> _departmentCourses = {
    'Computer Science': ['Computer Science', 'Software Engineering', 'Data Science'],
    'Engineering': ['Mechanical Engineering', 'Electrical Engineering', 'Civil Engineering'],
    'Business': ['Business Administration', 'Marketing', 'Finance'],
    'Education': ['Math/bio', 'Phys/chem', 'Kiswa/history'],
  };

  String? _selectedDepartment;
  String? _selectedCourse;
  String? _selectedOccupation;
  String? _selectedEmploymentType;
  String? _selectedGender;

  final String lectureNumberFormat = 'LCxxxx';

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

  List<String> _getCourses() {
    return _selectedDepartment != null 
        ? _departmentCourses[_selectedDepartment] ?? []
        : [];
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        final prefs = await SharedPreferences.getInstance();
        
        if (prefs.containsKey(_lectureNumberController.text)) {
          setState(() {
            _errorMessage = 'An account with this lecture number already exists';
            _isLoading = false;
          });
          return;
        }
        
        final userData = {
          'name': _nameController.text,
          'lectureNumber': _lectureNumberController.text,
          'password': _passwordController.text,
          'department': _selectedDepartment,
          'occupation': _selectedOccupation,
          'employmentType': _selectedEmploymentType,
          'gender': _selectedGender,
        };
        
        await prefs.setString(_lectureNumberController.text, json.encode(userData));
        
        setState(() {
          _isLoading = false;
        });
        
        Navigator.pushNamed(
          context, 
          AppRoutes.lecturerDashboard,
          arguments: {
            'name': _nameController.text,
            'lectureNumber': _lectureNumberController.text,
            'department': _selectedDepartment,
            'occupation': _selectedOccupation,
            'employmentType': _selectedEmploymentType,
            'gender': _selectedGender,
          },
        );
      } catch (e) {
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
                          'Create Lecturer Account',
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
                        TextFormField(
                          controller: _lectureNumberController,
                          decoration: InputDecoration(
                            labelText: 'Lecture Number ($lectureNumberFormat)',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your lecture number';
                            }
                            if (!RegExp(r'^LC\d{4}').hasMatch(value)) {
                              return 'Lecture number must be in the format $lectureNumberFormat';
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
                          value: _selectedOccupation,
                          decoration: InputDecoration(
                            labelText: 'Occupation',
                            prefixIcon: Icon(Icons.work),
                          ),
                          items: _occupations.map((String occupation) {
                            return DropdownMenuItem<String>(
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
                              return 'Please select an occupation';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedEmploymentType,
                          decoration: InputDecoration(
                            labelText: 'Employment Type',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          items: _employmentTypes.map((String type) {
                            return DropdownMenuItem<String>(
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
                              return 'Please select an employment type';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: _genders.map((String gender) {
                            return DropdownMenuItem<String>(
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
                              return 'Please select a gender';
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
                            if (value.length < 8) {
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
                                Navigator.pushNamed(context, AppRoutes.lecturerLogin);
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
    _lectureNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _departmentController.dispose();
    _courseController.dispose();
    _occupationController.dispose();
    _employmentTypeController.dispose();
    super.dispose();
  }
} 
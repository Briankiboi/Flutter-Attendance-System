import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:qr_attendance/routes/app_routes.dart';

class UpdateLecturerDetailsScreen extends StatefulWidget {
  const UpdateLecturerDetailsScreen({Key? key}) : super(key: key);

  @override
  State<UpdateLecturerDetailsScreen> createState() => _UpdateLecturerDetailsScreenState();
}

class _UpdateLecturerDetailsScreenState extends State<UpdateLecturerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Form data
  String? _lectureNumber;
  String? _selectedDepartment;
  String? _selectedOccupation;
  String? _selectedEmploymentType;
  String? _selectedGender;
  bool _isLoading = false;
  String _errorMessage = '';
  String? _storedPassword;

  // Password visibility
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _changePassword = false;

  // Dropdown options
  final Map<String, List<String>> _departmentCourses = {
    'Computer Science': ['Computer Science', 'Software Engineering', 'Data Science'],
    'Engineering': ['Mechanical Engineering', 'Electrical Engineering', 'Civil Engineering'],
    'Business': ['Business Administration', 'Marketing', 'Finance'],
    'Education': ['Math/bio', 'Phys/chem', 'Kiswa/history'],
  };

  final List<String> _departments = [
    'Computer Science',
    'Engineering',
    'Business',
    'Education'
  ];

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
    Future.microtask(() {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _lectureNumber = args['lectureNumber'];
          _nameController.text = args['name'] ?? '';
          _selectedDepartment = args['department'];
          _selectedOccupation = args['occupation'];
          _selectedEmploymentType = args['employmentType'];
          _selectedGender = args['gender'];
        });
        _loadPassword();
      }
    });
  }

  void _capitalizeNames(String value) {
    if (value.isNotEmpty) {
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
  }

  Future<void> _loadPassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lectureNumber != null) {
        final userDataString = prefs.getString(_lectureNumber!);
        if (userDataString != null) {
          final userData = json.decode(userDataString);
          _storedPassword = userData['password'];
        }
      }
    } catch (e) {
      print('Error loading password: $e');
    }
  }

  Future<void> _updateDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_lectureNumber == null) {
        setState(() {
          _errorMessage = 'Error: Lecture number not found';
          _isLoading = false;
        });
        return;
      }

      // Get existing user data
      final userDataString = prefs.getString(_lectureNumber!);
      Map<String, dynamic> userData;
      
      if (userDataString != null) {
        userData = json.decode(userDataString);
      } else {
        userData = {};
      }

      // Update the fields while preserving the lecture number and password
      userData.addAll({
        'name': _nameController.text,
        'lectureNumber': _lectureNumber,
        'department': _selectedDepartment,
        'occupation': _selectedOccupation,
        'employmentType': _selectedEmploymentType,
        'gender': _selectedGender,
      });

      // Update password if change password is enabled
      if (_changePassword) {
        if (_currentPasswordController.text != _storedPassword) {
          setState(() {
            _errorMessage = 'Current password is incorrect';
            _isLoading = false;
          });
          return;
        }
        userData['password'] = _newPasswordController.text;
      }

      // Save updated data
      await prefs.setString(_lectureNumber!, json.encode(userData));
      
      // Update current user data
      await prefs.setString('current_lecturer_name', _nameController.text);
      await prefs.setString('current_lecturer_department', _selectedDepartment ?? '');
      await prefs.setString('current_lecturer_occupation', _selectedOccupation ?? '');
      await prefs.setString('current_lecturer_employment_type', _selectedEmploymentType ?? '');
      await prefs.setString('current_lecturer_gender', _selectedGender ?? '');

      // Also update the specific user data
      await prefs.setString('lecturer_name_$_lectureNumber', _nameController.text);
      await prefs.setString('lecturer_department_$_lectureNumber', _selectedDepartment ?? '');
      await prefs.setString('lecturer_occupation_$_lectureNumber', _selectedOccupation ?? '');
      await prefs.setString('lecturer_employment_type_$_lectureNumber', _selectedEmploymentType ?? '');
      await prefs.setString('lecturer_gender_$_lectureNumber', _selectedGender ?? '');

      setState(() {
        _isLoading = false;
      });

      // Clear login session
      await prefs.remove('current_lecture_number');
      await prefs.remove('isLoggedIn');
      
      // Show success message and navigate to login screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully. Please login again.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate to login screen after a short delay
      Future.delayed(Duration(seconds: 1), () {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          AppRoutes.lecturerLogin,
          (route) => false,
        );
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while updating details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Details'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Lecture Number (Read-only but visible)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lecture Number',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.badge, color: Colors.grey.shade700),
                                  SizedBox(width: 12),
                                  Text(
                                    _lectureNumber ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Name
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full Name',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: 'e.g. John Doe',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.blue, width: 2),
                                ),
                                prefixIcon: Icon(Icons.person, color: Colors.grey.shade700),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              onChanged: _capitalizeNames,
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                
                                // Check if it has at least first and last name
                                final nameParts = value.trim().split(' ').where((part) => part.isNotEmpty).toList();
                                if (nameParts.length < 2) {
                                  return 'Please enter both first and last name';
                                }
                                
                                return null;
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Department
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Department',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedDepartment,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.blue, width: 2),
                                ),
                                prefixIcon: Icon(Icons.business, color: Colors.grey.shade700),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                              items: _departments.map((String department) {
                                return DropdownMenuItem<String>(
                                  value: department,
                                  child: Text(department),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedDepartment = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a department';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Occupation
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Occupation',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedOccupation,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.blue, width: 2),
                                ),
                                prefixIcon: Icon(Icons.work, color: Colors.grey.shade700),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
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
                          ],
                        ),
                        SizedBox(height: 20),

                        // Employment Type
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Employment Type',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedEmploymentType,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.blue, width: 2),
                                ),
                                prefixIcon: Icon(Icons.business_center, color: Colors.grey.shade700),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
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
                                  return 'Please select employment type';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Gender
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gender',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(color: Colors.blue, width: 2),
                                ),
                                prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade700),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
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
                                  return 'Please select gender';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        
                        // Change Password Section
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Change Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Switch(
                                      value: _changePassword,
                                      onChanged: (value) {
                                        setState(() {
                                          _changePassword = value;
                                          if (!value) {
                                            _currentPasswordController.clear();
                                            _newPasswordController.clear();
                                            _confirmPasswordController.clear();
                                          }
                                        });
                                      },
                                      activeColor: Colors.blue,
                                      activeTrackColor: Colors.blue.withOpacity(0.4),
                                    ),
                                  ],
                                ),
                                
                                if (_changePassword) ...[
                                  SizedBox(height: 16),
                                  
                                  // Current Password
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Password',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _currentPasswordController,
                                        obscureText: !_showCurrentPassword,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.blue, width: 2),
                                          ),
                                          prefixIcon: Icon(Icons.lock, color: Colors.grey.shade700),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                                              color: Colors.grey.shade700,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _showCurrentPassword = !_showCurrentPassword;
                                              });
                                            },
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                          filled: true,
                                          fillColor: Colors.grey.shade100,
                                        ),
                                        validator: _changePassword ? (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your current password';
                                          }
                                          return null;
                                        } : null,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  
                                  // New Password
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'New Password',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _newPasswordController,
                                        obscureText: !_showNewPassword,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.blue, width: 2),
                                          ),
                                          prefixIcon: Icon(Icons.lock, color: Colors.grey.shade700),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _showNewPassword ? Icons.visibility_off : Icons.visibility,
                                              color: Colors.grey.shade700,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _showNewPassword = !_showNewPassword;
                                              });
                                            },
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                          filled: true,
                                          fillColor: Colors.grey.shade100,
                                        ),
                                        validator: _changePassword ? (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a new password';
                                          }
                                          if (value.length < 8) {
                                            return 'Password must be at least 8 characters';
                                          }
                                          if (value == _currentPasswordController.text) {
                                            return 'New password cannot be the same as current password';
                                          }
                                          return null;
                                        } : null,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  
                                  // Confirm New Password
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Confirm New Password',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: !_showConfirmPassword,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.grey.shade400),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(28),
                                            borderSide: BorderSide(color: Colors.blue, width: 2),
                                          ),
                                          prefixIcon: Icon(Icons.lock, color: Colors.grey.shade700),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                              color: Colors.grey.shade700,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _showConfirmPassword = !_showConfirmPassword;
                                              });
                                            },
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                          filled: true,
                                          fillColor: Colors.grey.shade100,
                                        ),
                                        validator: _changePassword ? (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please confirm your new password';
                                          }
                                          if (value != _newPasswordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        } : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
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

                        SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateDetails,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Update Profile',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 30),
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
} 
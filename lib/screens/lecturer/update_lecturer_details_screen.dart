import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:qr_attendance/services/supabase_service.dart';

class UpdateLecturerDetailsScreen extends StatefulWidget {
  const UpdateLecturerDetailsScreen({super.key});

  @override
  State<UpdateLecturerDetailsScreen> createState() => _UpdateLecturerDetailsScreenState();
}

class _UpdateLecturerDetailsScreenState extends State<UpdateLecturerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();
  
  // Text controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Form data
  String? _email;
  String? _selectedDepartment;
  String? _selectedOccupation;
  String? _selectedEmploymentType;
  String? _selectedGender;
  bool _isLoading = false;
  String _errorMessage = '';

  // Dropdown options
  List<String> _departments = [];

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

  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      final result = await _supabaseService.getLecturerDepartments();
      if (result['success']) {
        setState(() {
          _departments = (result['data'] as List)
              .map((dept) => dept['name'] as String)
              .toList();
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load departments';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading departments: $e';
      });
      print('Error loading departments: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final fullName = args['name'] as String? ?? '';
      final nameParts = fullName.split(' ');
      
      setState(() {
        _email = args['email'];
        _firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
        _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        _emailController.text = args['email'] ?? '';
          _selectedDepartment = args['department'];
          _selectedOccupation = args['occupation'];
          _selectedEmploymentType = args['employmentType'];
          _selectedGender = args['gender'];
        });
    }
  }

  Future<void> _updateDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if any field is empty
    if (_selectedDepartment == null ||
        _selectedOccupation == null ||
        _selectedEmploymentType == null ||
        _selectedGender == null) {
      setState(() {
        _errorMessage = 'Please fill in all required fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final fullName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
      
      final result = await _supabaseService.updateLecturerDetails({
        'name': fullName,
        'email': _emailController.text,
        'department': _selectedDepartment,
        'occupation': _selectedOccupation,
        'employmentType': _selectedEmploymentType,
        'gender': _selectedGender,
      });

      if (result['success']) {
        if (mounted) {
          Navigator.pop(context, {'updated': true});
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to update details';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
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
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
            padding: EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  if (_errorMessage.isNotEmpty)
                            Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red),
                              ),
                    ),
                    
                  // First Name
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                                  ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your first name';
                      }
                      return null;
                    },
                            ),
                  SizedBox(height: 16),
                  
                  // Last Name
                            TextFormField(
                    controller: _lastNameController,
                              decoration: InputDecoration(
                      labelText: 'Last Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                      ),
                                ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                        return 'Please enter your last name';
                                }
                                return null;
                              },
                            ),
                  SizedBox(height: 16),

                  // Email (non-editable)
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    enabled: false,
                            ),
                  SizedBox(height: 16),
                  
                  // Department Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedDepartment,
                              decoration: InputDecoration(
                      labelText: 'Department',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                      ),
                                ),
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
                  SizedBox(height: 16),

                  // Occupation Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedOccupation,
                              decoration: InputDecoration(
                      labelText: 'Occupation',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                      ),
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
                  SizedBox(height: 16),

                  // Employment Type Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedEmploymentType,
                              decoration: InputDecoration(
                      labelText: 'Employment Type',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                      ),
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
                  SizedBox(height: 16),

                  // Gender Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                      labelText: 'Gender',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                      ),
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
                        SizedBox(height: 24),
                        
                  // Update Button
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
} 
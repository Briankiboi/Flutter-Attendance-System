import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GetAssignedUnitsPage extends StatefulWidget {
  const GetAssignedUnitsPage({super.key});

  @override
  State<GetAssignedUnitsPage> createState() => _GetAssignedUnitsPageState();
}

class _GetAssignedUnitsPageState extends State<GetAssignedUnitsPage> {
  // User data fields
  late String _lecturerEmail = '';
  late String _lecturerName = '';
  late String _department = '';
  
  // Selection fields
  String? selectedCourse;
  String? selectedYear;
  String? selectedSemester;
  String? selectedUnitCode;
  String? selectedUnitName;
  
  // Data lists
  List<Map<String, dynamic>> courses = [];
  List<String> years = ['1', '2', '3', '4'];
  List<String> semesters = ['1', '2'];
  List<Map<String, dynamic>> availableUnits = [];
  List<Map<String, dynamic>> assignedUnits = [];
  
  // Loading and error states
  bool isLoading = false;
  String? errorMessage;
  
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _lecturerEmail = args['email'] ?? '';
        _lecturerName = args['name'] ?? '';
        _department = args['department'] ?? '';
      });
      _loadDepartmentCourses();
      _loadAssignedUnits();
    }
  }

  Future<void> _loadDepartmentCourses() async {
    if (_department.isEmpty) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get courses for this department using a join
      final coursesData = await supabase
          .from('courses')
          .select('id, name, departments!inner(id, name)')
          .eq('departments.name', _department);

      setState(() {
        courses = List<Map<String, dynamic>>.from(coursesData);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load courses: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _loadUnitsForSelection() async {
    if (selectedCourse == null || selectedYear == null || selectedSemester == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get units for this course, year and semester using a join
      final units = await supabase
          .from('units')
          .select('code, name')
          .eq('course_id', courses.firstWhere((c) => c['name'] == selectedCourse)['id'])
          .eq('year', selectedYear!)
          .eq('semester', selectedSemester!);

      setState(() {
        availableUnits = List<Map<String, dynamic>>.from(units);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load units: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _loadAssignedUnits() async {
    if (_lecturerEmail.isEmpty) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get lecturer ID using email
      final lecturerData = await supabase
          .from('lecturers')
          .select('id')
          .eq('email', _lecturerEmail)
          .single();

      final lecturerId = lecturerData['id'];

      // Get assigned units
      final response = await supabase
          .from('lecturer_assigned_units')
          .select('unit_code, unit_name, course_name, year, semester')
          .eq('lecturer_id', lecturerId)
          .order('created_at');

      setState(() {
        assignedUnits = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load assigned units: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _assignUnit() async {
    if (selectedUnitCode == null || selectedUnitName == null || 
        selectedCourse == null || selectedYear == null || 
        selectedSemester == null || _department.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get lecturer ID using email
      final lecturerData = await supabase
          .from('lecturers')
          .select('id')
          .eq('email', _lecturerEmail)
          .single();

      final lecturerId = lecturerData['id'];

      // Insert new assigned unit with simplified auth
      await supabase.from('lecturer_assigned_units').insert({
        'lecturer_id': lecturerId,
        'unit_code': selectedUnitCode,
        'unit_name': selectedUnitName,
        'department': _department,
        'course_name': selectedCourse,
        'year': selectedYear,
        'semester': selectedSemester,
      });

      // Reload assigned units
      await _loadAssignedUnits();

      // Reset selection
      setState(() {
        selectedUnitCode = null;
        selectedUnitName = null;
        selectedYear = null;
        selectedSemester = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unit assigned successfully')),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to assign unit: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage!)),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _unassignUnit(String unitCode) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get lecturer ID directly from email
      final lecturerData = await supabase
          .from('lecturers')
          .select('id')
          .eq('email', _lecturerEmail)
          .single();

      final lecturerId = lecturerData['id'];

      // Delete the assigned unit
      await supabase
          .from('lecturer_assigned_units')
          .delete()
          .eq('lecturer_id', lecturerId)
          .eq('unit_code', unitCode);

      // Reload assigned units
      await _loadAssignedUnits();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unit unassigned successfully')),
      );
    } catch (e) {
      print('Error unassigning unit: $e'); // Add debug print
      setState(() {
        errorMessage = 'Failed to unassign unit';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unassign unit')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Assigned Units',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.blue.shade100],
          ),
        ),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Assigned Units',
              style: TextStyle(
                  fontSize: 28,
                fontWeight: FontWeight.bold,
                  color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'View and manage your assigned units for all semesters.',
              style: TextStyle(
                fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
              ),
            ),
            if (_department.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Department: $_department',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                      color: Colors.white,
                  ),
                ),
              ),
            SizedBox(height: 24),
            
            // Unit Assignment Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 5),
              ),
                  ],
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign New Unit',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // Course Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Course',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                        ),
                          filled: true,
                          fillColor: Colors.grey[100],
                      ),
                      value: selectedCourse,
                      items: courses.map((course) {
                        return DropdownMenuItem<String>(
                          value: course['name'] as String,
                          child: Text(course['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCourse = value;
                          selectedUnitCode = null;
                          selectedUnitName = null;
                          _loadUnitsForSelection();
                        });
                      },
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Year and Semester Row
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                          child: DropdownButtonFormField<String>(
                              isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                              ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: selectedYear,
                            items: years.map((year) {
                              return DropdownMenuItem<String>(
                                value: year,
                                child: Text('Year $year'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedYear = value;
                                selectedUnitCode = null;
                                selectedUnitName = null;
                                _loadUnitsForSelection();
                              });
                            },
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                          child: DropdownButtonFormField<String>(
                              isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Semester',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                              ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: selectedSemester,
                            items: semesters.map((semester) {
                              return DropdownMenuItem<String>(
                                value: semester,
                                child: Text('Semester $semester'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSemester = value;
                                selectedUnitCode = null;
                                selectedUnitName = null;
                                _loadUnitsForSelection();
                              });
                            },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    // Unit Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Unit',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                        ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: selectedUnitCode,
                      items: availableUnits.map((unit) {
                        return DropdownMenuItem<String>(
                          value: unit['code'] as String,
                          child: Text('${unit['code']} - ${unit['name']}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedUnitCode = value;
                          if (value != null) {
                            final selectedUnit = availableUnits.firstWhere(
                              (unit) => unit['code'] == value,
                              orElse: () => {'name': ''},
                            );
                            selectedUnitName = selectedUnit['name'] as String;
                          }
                        });
                      },
                    ),
                    ),
                    SizedBox(height: 24),
                    
                    // Assign Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _assignUnit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Assign Unit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
              ),
            ),
            
            SizedBox(height: 24),
            
              // Currently Assigned Units Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(
              'Currently Assigned Units',
              style: TextStyle(
                        fontSize: 24,
                fontWeight: FontWeight.bold,
                        color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              )
            else if (assignedUnits.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No units assigned yet.',
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: assignedUnits.length,
                itemBuilder: (context, index) {
                  final unit = assignedUnits[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        '${unit['unit_code']} - ${unit['unit_name']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                      ),
                      subtitle: Text(
                        '${unit['course_name']} • Year ${unit['year']} • Semester ${unit['semester']}',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _unassignUnit(unit['unit_code']),
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
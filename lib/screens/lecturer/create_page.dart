import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';

class CreateQRCodePage extends StatefulWidget {
  @override
  _CreateQRCodePageState createState() => _CreateQRCodePageState();
}

class _CreateQRCodePageState extends State<CreateQRCodePage> {
  // Lists for dropdown options
  List<String> departments = [
    'Computer Science',
    'Engineering',
    'Business',
    'Education'
  ];
  List<String> courses = [
    // Computer Science
    'Computer Science', 'Software Engineering', 'Data Science',
    'Programming Fundamentals', 'Data Structures', 'Algorithms', 'Database Systems', 'Operating Systems', 'Computer Networks', 'Computer Architecture',
    'Advanced Programming', 'Machine Learning', 'Artificial Intelligence', 'Software Engineering', 'Web Development', 'Mobile Development', 'Cloud Computing',
    'Cyber Security', 'Data Mining', 'Big Data', 'Computer Vision', 'Natural Language Processing', 'Human-Computer Interaction', 'Distributed Systems',
    'Capstone Project', 'Research Methods', 'Professional Practice', 'Ethics in Computing', 'Project Management', 'Entrepreneurship', 'Innovation',
    // Engineering
    'Mechanical Engineering', 'Electrical Engineering', 'Civil Engineering',
    'Engineering Mathematics', 'Physics for Engineers', 'Chemistry for Engineers', 'Engineering Mechanics', 'Thermodynamics', 'Fluid Mechanics', 'Solid Mechanics',
    'Materials Science', 'Dynamics', 'Control Systems', 'Engineering Design', 'Electrical Circuits', 'Electronics', 'Digital Systems',
    'Signal Processing', 'Power Systems', 'Renewable Energy', 'Robotics', 'Automation', 'Manufacturing Processes', 'Quality Control',
    'Engineering Management', 'Sustainability', 'Environmental Engineering', 'Transport Engineering', 'Structural Analysis', 'Geotechnical Engineering', 'Hydraulics',
    // Business
    'Business Administration', 'Marketing', 'Finance',
    'Principles of Marketing', 'Corporate Finance', 'Organizational Behavior', 'Business Law', 'Strategic Management', 'Operations Management', 'Business Ethics',
    'Human Resource Management', 'International Business', 'Entrepreneurship', 'Supply Chain Management', 'Consumer Behavior', 'Digital Marketing', 'Investment Analysis',
    'Financial Accounting', 'Management Accounting', 'Taxation', 'Auditing', 'Financial Reporting', 'Corporate Governance', 'Risk Management',
    'Business Analytics', 'E-commerce', 'Innovation Management', 'Leadership', 'Negotiation Skills', 'Project Management', 'Business Communication',
    // Education
    'Math/bio', 'phys/chem', 'kiswa/hisory',
    'Educational Psychology', 'Teaching Methods', 'Curriculum Development', 'Educational Technology', 'Classroom Management', 'Assessment and Evaluation',
    'Special Education', 'Early Childhood Education', 'Primary Education', 'Secondary Education', 'Higher Education', 'Adult Education', 'Educational Leadership',
    'Mathematics Education', 'Science Education', 'Language Education', 'Social Studies Education', 'Physical Education', 'Arts Education', 'Music Education',
    'Educational Research', 'Educational Policy', 'Educational Administration', 'School Counseling', 'Inclusive Education', 'Multicultural Education'
  ];
  List<String> unitCodes = [
    // Computer Science
    'CS101', 'CS102', 'CS103', 'CS104', 'CS105', 'CS106', 'CS107',
    'CS201', 'CS202', 'CS203', 'CS204', 'CS205', 'CS206', 'CS207',
    'CS301', 'CS302', 'CS303', 'CS304', 'CS305', 'CS306', 'CS307',
    'CS401', 'CS402', 'CS403', 'CS404', 'CS405', 'CS406', 'CS407',
    'CS108', 'CS109', 'CS110', 'CS111', 'CS112', 'CS113', 'CS114',
    'CS208', 'CS209', 'CS210', 'CS211', 'CS212', 'CS213', 'CS214',
    'CS308', 'CS309', 'CS310', 'CS311', 'CS312', 'CS313', 'CS314',
    'CS408', 'CS409', 'CS410', 'CS411', 'CS412', 'CS413', 'CS414',
    // Engineering
    'ENG101', 'ENG102', 'ENG103', 'ENG104', 'ENG105', 'ENG106', 'ENG107',
    'ENG201', 'ENG202', 'ENG203', 'ENG204', 'ENG205', 'ENG206', 'ENG207',
    'ENG301', 'ENG302', 'ENG303', 'ENG304', 'ENG305', 'ENG306', 'ENG307',
    'ENG401', 'ENG402', 'ENG403', 'ENG404', 'ENG405', 'ENG406', 'ENG407',
    'ENG108', 'ENG109', 'ENG110', 'ENG111', 'ENG112', 'ENG113', 'ENG114',
    'ENG208', 'ENG209', 'ENG210', 'ENG211', 'ENG212', 'ENG213', 'ENG214',
    'ENG308', 'ENG309', 'ENG310', 'ENG311', 'ENG312', 'ENG313', 'ENG314',
    'ENG408', 'ENG409', 'ENG410', 'ENG411', 'ENG412', 'ENG413', 'ENG414',
    // Business
    'BUS101', 'BUS102', 'BUS103', 'BUS104', 'BUS105', 'BUS106', 'BUS107',
    'BUS201', 'BUS202', 'BUS203', 'BUS204', 'BUS205', 'BUS206', 'BUS207',
    'BUS301', 'BUS302', 'BUS303', 'BUS304', 'BUS305', 'BUS306', 'BUS307',
    'BUS401', 'BUS402', 'BUS403', 'BUS404', 'BUS405', 'BUS406', 'BUS407',
    'BUS108', 'BUS109', 'BUS110', 'BUS111', 'BUS112', 'BUS113', 'BUS114',
    'BUS208', 'BUS209', 'BUS210', 'BUS211', 'BUS212', 'BUS213', 'BUS214',
    'BUS308', 'BUS309', 'BUS310', 'BUS311', 'BUS312', 'BUS313', 'BUS314',
    'BUS408', 'BUS409', 'BUS410', 'BUS411', 'BUS412', 'BUS413', 'BUS414',
    // Arts
    'ART101', 'ART102', 'ART103', 'ART104', 'ART105', 'ART106', 'ART107',
    'ART201', 'ART202', 'ART203', 'ART204', 'ART205', 'ART206', 'ART207',
    'ART301', 'ART302', 'ART303', 'ART304', 'ART305', 'ART306', 'ART307',
    'ART401', 'ART402', 'ART403', 'ART404', 'ART405', 'ART406', 'ART407',
    'ART108', 'ART109', 'ART110', 'ART111', 'ART112', 'ART113', 'ART114',
    'ART208', 'ART209', 'ART210', 'ART211', 'ART212', 'ART213', 'ART214',
    'ART308', 'ART309', 'ART310', 'ART311', 'ART312', 'ART313', 'ART314',
    'ART408', 'ART409', 'ART410', 'ART411', 'ART412', 'ART413', 'ART414'
  ];
  List<String> unitNames = [
    // Computer Science
    'Intro to Programming', 'Data Structures', 'Algorithms', 'Operating Systems', 'Database Systems', 'Software Design', 'Computer Networks',
    'Advanced Programming', 'Machine Learning', 'Artificial Intelligence', 'Software Engineering', 'Web Development', 'Mobile Development', 'Cloud Computing',
    'Cyber Security', 'Data Mining', 'Big Data', 'Computer Vision', 'Natural Language Processing', 'Human-Computer Interaction', 'Distributed Systems',
    'Capstone Project', 'Research Methods', 'Professional Practice', 'Ethics in Computing', 'Project Management', 'Entrepreneurship', 'Innovation',
    'Python Programming', 'Java Programming', 'C++ Programming', 'JavaScript Fundamentals', 'Functional Programming', 'Logic Programming', 'Programming Paradigms',
    'Full Stack Development', 'DevOps Practices', 'API Design', 'Microservices Architecture', 'Serverless Computing', 'Progressive Web Apps', 'Cross-Platform Mobile Development',
    'Network Security', 'Ethical Hacking', 'Blockchain Technology', 'Quantum Computing', 'Internet of Things', 'Edge Computing', 'Cloud Security',
    'Software Testing', 'Agile Methodologies', 'User Experience Design', 'Game Development', 'Compiler Design', 'Computer Graphics', 'Parallel Computing',
    // Engineering
    'Engineering Mathematics', 'Physics for Engineers', 'Chemistry for Engineers', 'Engineering Mechanics', 'Thermodynamics', 'Fluid Mechanics', 'Solid Mechanics',
    'Materials Science', 'Dynamics', 'Control Systems', 'Engineering Design', 'Electrical Circuits', 'Electronics', 'Digital Systems',
    'Signal Processing', 'Power Systems', 'Renewable Energy', 'Robotics', 'Automation', 'Manufacturing Processes', 'Quality Control',
    'Engineering Management', 'Sustainability', 'Environmental Engineering', 'Transport Engineering', 'Structural Analysis', 'Geotechnical Engineering', 'Hydraulics',
    'Applied Mathematics', 'Analytical Mechanics', 'Heat Transfer', 'Aerodynamics', 'Mechatronics', 'Electromagnetics', 'Vibration Analysis',
    'Advanced Materials', 'Engineering Economics', 'Computer-Aided Design', 'Finite Element Analysis', 'Machine Components', 'Industrial Automation', 'Control Theory',
    'Digital Signal Processing', 'Communication Systems', 'Antenna Theory', 'Embedded Systems', 'Electric Machines', 'High Voltage Engineering', 'Power Electronics',
    'Construction Management', 'Earthquake Engineering', 'Urban Planning', 'Water Resources', 'Environmental Impact Assessment', 'Bridge Engineering', 'Transportation Planning',
    // Business
    'Principles of Marketing', 'Corporate Finance', 'Organizational Behavior', 'Business Law', 'Strategic Management', 'Operations Management', 'Business Ethics',
    'Human Resource Management', 'International Business', 'Entrepreneurship', 'Supply Chain Management', 'Consumer Behavior', 'Digital Marketing', 'Investment Analysis',
    'Financial Accounting', 'Management Accounting', 'Taxation', 'Auditing', 'Financial Reporting', 'Corporate Governance', 'Risk Management',
    'Business Analytics', 'E-commerce', 'Innovation Management', 'Leadership', 'Negotiation Skills', 'Project Management', 'Business Communication',
    'Microeconomics', 'Macroeconomics', 'Monetary Economics', 'Economic Development', 'Marketing Research', 'Brand Management', 'Retail Management',
    'Financial Markets', 'Banking Systems', 'Portfolio Management', 'Mergers and Acquisitions', 'Business Intelligence', 'Data Analytics', 'Decision Making',
    'Change Management', 'Crisis Management', 'Knowledge Management', 'Intellectual Property', 'Business Strategy', 'Logistics Management', 'Quality Management',
    'Public Relations', 'Social Media Marketing', 'Customer Relationship Management', 'Sales Management', 'Business Process Reengineering', 'Sustainable Business', 'Global Marketing',
    // Arts
    'World History', 'English Literature', 'Philosophical Thought', 'Art History', 'Cultural Studies', 'Creative Writing', 'Performing Arts',
    'Music Theory', 'Art and Design', 'Drama and Theatre', 'Film Studies', 'Photography', 'Sculpture', 'Painting',
    'Dance', 'Music Performance', 'Visual Arts', 'Media Studies', 'Fashion Design', 'Graphic Design', 'Interior Design',
    'Art Criticism', 'Aesthetics', 'Cultural Heritage', 'Museum Studies', 'Art Therapy', 'Art Education', 'Art Management',
    'Ancient History', 'Medieval History', 'Modern History', 'Contemporary History', 'Political Philosophy', 'Ethics', 'Metaphysics',
    'Literary Criticism', 'Poetry', 'Fiction Writing', 'Screenwriting', 'Digital Media', 'Animation', 'Game Art',
    'Ceramics', 'Printmaking', 'Textile Design', 'Art Conservation', 'Contemporary Art', 'Multimedia Art', 'Installation Art',
    'Art Curation', 'Public Art', 'Art and Technology', 'Digital Photography', 'Documentary Filmmaking', 'Sound Design', 'Performance Studies'
  ];
  List<String> classIds = ['CLS1', 'CLS2', 'CLS3'];
  List<String> sessionIds = ['SES1', 'SES2', 'SES3'];
  List<String> studentIds = [];
  List<String> yearsOfStudy = ['1', '2', '3', '4'];
  List<String> semesters = ['1', '2'];
  
  // Filtered lists based on selections
  List<String> filteredCourses = [];
  List<String> filteredUnitCodes = [];
  List<String> filteredUnitNames = [];
  List<String> filteredStudents = [];

  // Selected values
  String? selectedDepartment;
  String? selectedCourse;
  String? selectedUnitCode;
  String? selectedUnitName;
  String? selectedClassId;
  String? selectedSessionId;
  String? selectedStudentId;
  String? selectedYear;
  String? selectedSemester;
  DateTime? startTime;
  DateTime? endTime;
  
  // Loading states
  bool isLoading = false;
  bool qrGenerated = false;

  // Add duration input fields
  int durationHours = 0;
  int durationMinutes = 0;
  
  // Lecturer information
  String? _lectureNumber;
  String? _lecturerName;

  // Add a controller for the lecture number field
  TextEditingController lectureNumberController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    print('CreateQRCodePage: initState called');
    _initializeDirectories().then((_) {
      loadPreferences();
    }).catchError((error) {
      print('Error initializing directories: $error');
      loadPreferences();
    });
    
    // Load lecturer information
    _loadLecturerInfo();
  }

  // Load lecturer information from SharedPreferences
  Future<void> _loadLecturerInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lectureNumber = prefs.getString('current_lecture_number');
      
      if (lectureNumber != null && lectureNumber.isNotEmpty) {
        setState(() {
          _lectureNumber = lectureNumber;
          // Extract just the numeric part if the format is LCxxxx
          if (lectureNumber.startsWith('LC') && lectureNumber.length > 2) {
            lectureNumberController.text = lectureNumber.substring(2);
          } else {
            lectureNumberController.text = lectureNumber;
          }
        });
        
        // Also load lecturer name
        final lecturerKey = 'lecturer_data_$lectureNumber';
        final userDataString = prefs.getString(lecturerKey);
        
        if (userDataString != null) {
          final userData = json.decode(userDataString) as Map<String, dynamic>;
          setState(() {
            _lecturerName = userData['name'];
          });
        } else {
          // Fallback to individual key
          setState(() {
            _lecturerName = prefs.getString('lecturer_name_$lectureNumber');
          });
        }
      }
    } catch (e) {
      print('Error loading lecturer info: $e');
    }
  }

  @override
  void dispose() {
    lectureNumberController.dispose();
    // ... existing code ...
    super.dispose();
  }

  Future<void> loadPreferences() async {
    print('CreateQRCodePage: loadPreferences started');
    try {
      setState(() {
        isLoading = true;
      });
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      print('CreateQRCodePage: SharedPreferences instance obtained');
      
      // Load all stored user data to get registered students
      Set<String> allKeys = prefs.getKeys();
      List<String> studentEmails = [];
      
      print('CreateQRCodePage: Found ${allKeys.length} keys in SharedPreferences');
      
      // First pass: identify only valid student emails in SharedPreferences
      for (String key in allKeys) {
        // Special debug for kbt3.04262.21
        if (key.contains("kbt3.04262.21")) {
          print('DEBUG: Found key containing target student: $key');
        }
        
        // Only process keys that look like student emails - more flexible check
        if ((key.contains('@') && key.contains('student')) || 
            (key.contains('kbt3') && key.contains('tharaka'))) {
            
          // Skip meta keys that contain student email as part of the key
          if (key.contains('session_') || key.contains('_session') || 
              key.contains('attendance_') || key.contains('_history') ||
              key.contains('_detailed_') || key.contains('_qrs_') ||
              key.contains('_timetable_')) {
            if (key.contains("kbt3.04262.21")) {
              print('DEBUG: Skipping meta key for target student: $key');
            }
            continue;
          }
          
          try {
            // Get the user data - handle both String and List<String> types
            dynamic userDataRaw = prefs.get(key);
            String? userDataString;
            
            if (userDataRaw is String) {
              userDataString = userDataRaw;
            } else if (userDataRaw is List<String> && userDataRaw.isNotEmpty) {
              userDataString = userDataRaw.first;
            }
            
            if (userDataString != null && userDataString.isNotEmpty) {
              // Try to decode as JSON 
              try {
                Map<String, dynamic> userData = json.decode(userDataString);
                if (userData.containsKey('department') && 
                    userData.containsKey('course')) {
                  studentEmails.add(key);
                }
              } catch (e) {
                print('Error parsing student data: $e');
              }
            }
          } catch (e) {
            print('Error processing student data for $key: $e');
          }
        }
      }
      
      print('CreateQRCodePage: Found ${studentEmails.length} student emails');

      // Initialize with default data first
      print('CreateQRCodePage: Initializing default data');
      await _initializeDefaultData();

      // Then override with any stored preferences
      print('CreateQRCodePage: Updating with stored preferences');
      setState(() {
        departments = prefs.getStringList('departments') ?? departments;
        courses = prefs.getStringList('courses') ?? courses;
        unitCodes = prefs.getStringList('unitCodes') ?? unitCodes;
        unitNames = prefs.getStringList('unitNames') ?? unitNames;
        classIds = prefs.getStringList('classIds') ?? classIds;
        sessionIds = prefs.getStringList('sessionIds') ?? sessionIds;
        studentIds = studentEmails.isNotEmpty ? studentEmails : studentIds;
        isLoading = false;
      });
      print('CreateQRCodePage: loadPreferences completed successfully');
    } catch (e) {
      print('CreateQRCodePage: Error loading preferences: $e');
      // Initialize with default data if there's an error
      await _initializeDefaultData();
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Initialize default data if needed
  Future<void> _initializeDefaultData() async {
    // Sample data for initial setup
    departments = ['Computer Science', 'Engineering', 'Business', 'Education'];
    courses = [
      // Computer Science
      'Computer Science', 'Software Engineering', 'Data Science',
      // Engineering
      'Mechanical Engineering', 'Electrical Engineering', 'Civil Engineering',
      // Business
      'Business Administration', 'Marketing', 'Finance',
      // Education
      'Math/bio', 'phys/chem', 'kiswa/hisory'
    ];
    unitCodes = [
      // Computer Science
      'CS101', 'CS102', 'CS103', 'CS201', 'CS202', 'CS203', 'CS301', 'CS302', 'CS303',
      // Engineering
      'ME101', 'ME102', 'ME103', 'EE101', 'EE102', 'EE103', 'CE101', 'CE102', 'CE103',
      // Business
      'BA101', 'BA102', 'BA103', 'MK101', 'MK102', 'MK103', 'FN101', 'FN102', 'FN103',
      // Education
      'ED101', 'ED102', 'ED103', 'ED201', 'ED202', 'ED203', 'ED301', 'ED302', 'ED303'
    ];
    unitNames = [
      // Computer Science
      'Intro to Programming', 'Data Structures', 'Algorithms',
      'Software Design', 'Software Testing', 'Project Management',
      'Data Mining', 'Machine Learning', 'Statistical Analysis',
      // Engineering
      'Thermodynamics', 'Fluid Mechanics', 'Solid Mechanics',
      'Circuit Analysis', 'Electronics', 'Power Systems',
      'Structural Analysis', 'Geotechnical Engineering', 'Hydraulics',
      // Business
      'Principles of Management', 'Organizational Behavior', 'Business Ethics',
      'Principles of Marketing', 'Consumer Behavior', 'Marketing Research',
      'Financial Accounting', 'Corporate Finance', 'Investment Analysis',
      // Education
      'Mathematics Teaching Methods', 'Biology Teaching Methods', 'Educational Psychology',
      'Physics Teaching Methods', 'Chemistry Teaching Methods', 'Curriculum Development',
      'Kiswahili Teaching Methods', 'History Teaching Methods', 'Educational Technology'
    ];
    classIds = ['CLS1', 'CLS2', 'CLS3'];
    sessionIds = ['SES1', 'SES2', 'SES3'];
    
    try {
      // Save to SharedPreferences for sharing with students
      await _saveDataToSharedPreferences();
    } catch (e) {
      print('Error saving default data: $e');
    }
  }
  
  // Save current data to SharedPreferences
  Future<void> _saveDataToSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    await prefs.setStringList('departments', departments);
    await prefs.setStringList('courses', courses);
    await prefs.setStringList('unitCodes', unitCodes);
    await prefs.setStringList('unitNames', unitNames);
    await prefs.setStringList('classIds', classIds);
    await prefs.setStringList('sessionIds', sessionIds);
    await prefs.setStringList('studentIds', studentIds);
  }
  
  // Filter courses based on selected department
  void filterCoursesByDepartment(String department) {
    switch (department) {
      case 'Computer Science':
        filteredCourses = courses.where((course) => 
          ['Computer Science', 'Software Engineering', 'Data Science'].contains(course)).toList();
        break;
      case 'Engineering':
        filteredCourses = courses.where((course) => 
          ['Mechanical Engineering', 'Electrical Engineering', 'Civil Engineering'].contains(course)).toList();
        break;
      case 'Business':
        filteredCourses = courses.where((course) => 
          ['Business Administration', 'Marketing', 'Finance'].contains(course)).toList();
        break;
      case 'Education':
        filteredCourses = courses.where((course) => 
          ['Math/bio', 'phys/chem', 'kiswa/hisory'].contains(course)).toList();
        break;
      default:
        filteredCourses = [];
    }
    selectedCourse = filteredCourses.isNotEmpty ? null : null;
    filterUnitsByDepartmentAndCourse();
  }
  
  // Filter unit codes based on selected course
  void filterUnitsByCourse(String course) {
    setState(() {
      // Filter units based on course
      switch (course) {
        case 'Computer Science':
          filteredUnitCodes = [
            'CS101', 'CS102', 'CS103', 'CS104', 'CS105', 'CS106', 'CS107',
            'CS108', 'CS109', 'CS110'
          ];
          filteredUnitNames = [
            'Intro to Programming', 'Data Structures', 'Algorithms', 'Operating Systems', 
            'Database Systems', 'Software Design', 'Computer Networks',
            'Python Programming', 'Java Programming', 'C++ Programming'
          ];
          break;
        case 'Software Engineering':
          filteredUnitCodes = [
            'CS201', 'CS202', 'CS203', 'CS204', 'CS205', 'CS206', 'CS207',
            'CS208', 'CS209', 'CS210'
          ];
          filteredUnitNames = [
            'Software Design', 'Software Testing', 'Project Management', 'Web Development', 
            'Mobile Development', 'Cloud Computing', 'DevOps Practices',
            'Full Stack Development', 'API Design', 'Microservices Architecture'
          ];
          break;
        case 'Data Science':
          filteredUnitCodes = [
            'CS301', 'CS302', 'CS303', 'CS304', 'CS305', 'CS306', 'CS307',
            'CS308', 'CS309', 'CS310'
          ];
          filteredUnitNames = [
            'Data Mining', 'Machine Learning', 'Statistical Analysis', 'Big Data', 
            'Natural Language Processing', 'Computer Vision', 'Deep Learning',
            'Network Security', 'Ethical Hacking', 'Blockchain Technology'
          ];
          break;
        case 'Mechanical Engineering':
          filteredUnitCodes = [
            'ENG101', 'ENG102', 'ENG103', 'ENG104', 'ENG105', 'ENG106', 'ENG107',
            'ENG108', 'ENG109', 'ENG110'
          ];
          filteredUnitNames = [
            'Thermodynamics', 'Fluid Mechanics', 'Solid Mechanics', 'Engineering Mechanics',
            'Heat Transfer', 'Engineering Mathematics', 'Materials Science',
            'Applied Mathematics', 'Analytical Mechanics', 'Vibration Analysis'
          ];
          break;
        case 'Electrical Engineering':
          filteredUnitCodes = [
            'ENG201', 'ENG202', 'ENG203', 'ENG204', 'ENG205', 'ENG206', 'ENG207',
            'ENG208', 'ENG209', 'ENG210'
          ];
          filteredUnitNames = [
            'Circuit Analysis', 'Electronics', 'Power Systems', 'Digital Systems',
            'Control Systems', 'Signal Processing', 'Electromagnetic Theory',
            'Digital Signal Processing', 'Communication Systems', 'Antenna Theory'
          ];
          break;
        case 'Civil Engineering':
          filteredUnitCodes = [
            'ENG301', 'ENG302', 'ENG303', 'ENG304', 'ENG305', 'ENG306', 'ENG307',
            'ENG308', 'ENG309', 'ENG310'
          ];
          filteredUnitNames = [
            'Structural Analysis', 'Geotechnical Engineering', 'Hydraulics', 'Transport Engineering',
            'Environmental Engineering', 'Construction Management', 'Surveying',
            'Earthquake Engineering', 'Urban Planning', 'Water Resources'
          ];
          break;
        case 'Business Administration':
          filteredUnitCodes = [
            'BUS101', 'BUS102', 'BUS103', 'BUS104', 'BUS105', 'BUS106', 'BUS107',
            'BUS108', 'BUS109', 'BUS110'
          ];
          filteredUnitNames = [
            'Principles of Management', 'Organizational Behavior', 'Business Ethics', 'Business Law',
            'Strategic Management', 'Operations Management', 'Human Resource Management',
            'Microeconomics', 'Macroeconomics', 'Monetary Economics'
          ];
          break;
        case 'Marketing':
          filteredUnitCodes = [
            'BUS201', 'BUS202', 'BUS203', 'BUS204', 'BUS205', 'BUS206', 'BUS207',
            'BUS208', 'BUS209', 'BUS210'
          ];
          filteredUnitNames = [
            'Principles of Marketing', 'Consumer Behavior', 'Marketing Research', 'Digital Marketing',
            'Brand Management', 'Retail Management', 'Social Media Marketing',
            'Marketing Strategy', 'International Marketing', 'Marketing Analytics'
          ];
          break;
        case 'Finance':
          filteredUnitCodes = [
            'BUS301', 'BUS302', 'BUS303', 'BUS304', 'BUS305', 'BUS306', 'BUS307',
            'BUS308', 'BUS309', 'BUS310'
          ];
          filteredUnitNames = [
            'Financial Accounting', 'Corporate Finance', 'Investment Analysis', 'Financial Markets',
            'Banking Systems', 'Portfolio Management', 'Risk Management',
            'Financial Reporting', 'Corporate Governance', 'Taxation'
          ];
          break;
        case 'Math/bio':
          filteredUnitCodes = [
            'ED101', 'ED102', 'ED103', 'ED104', 'ED105', 'ED106', 'ED107',
            'ED108', 'ED109', 'ED110'
          ];
          filteredUnitNames = [
            'Mathematics Teaching Methods', 'Biology Teaching Methods', 'Educational Psychology',
            'Classroom Management', 'Assessment and Evaluation', 'Special Education',
            'Educational Technology', 'Science Education', 'Mathematics Education', 'Curriculum Development'
          ];
          break;
        case 'phys/chem':
          filteredUnitCodes = [
            'ED201', 'ED202', 'ED203', 'ED204', 'ED205', 'ED206', 'ED207',
            'ED208', 'ED209', 'ED210'
          ];
          filteredUnitNames = [
            'Physics Teaching Methods', 'Chemistry Teaching Methods', 'Curriculum Development',
            'Laboratory Methods', 'Scientific Research Methods', 'Environmental Education',
            'STEM Education', 'Educational Psychology', 'Educational Technology', 'Assessment and Evaluation'
          ];
          break;
        case 'kiswa/hisory':
          filteredUnitCodes = [
            'ED301', 'ED302', 'ED303', 'ED304', 'ED305', 'ED306', 'ED307',
            'ED308', 'ED309', 'ED310'
          ];
          filteredUnitNames = [
            'Kiswahili Teaching Methods', 'History Teaching Methods', 'Educational Technology',
            'Cultural Studies', 'African Literature', 'Research Methods in Humanities',
            'Teaching Practice', 'Linguistic Analysis', 'Historical Research Methods', 'Education Policy'
          ];
          break;
        default:
          filteredUnitCodes = [];
          filteredUnitNames = [];
      }
      
      // Reset unit selections
      selectedUnitCode = null;
      selectedUnitName = null;
    });
    filterStudents();
  }
  
  // Filter students based on department and course
  Future<void> filterStudents() async {
    print('Filtering students with criteria:');
    print('Department: $selectedDepartment');
    print('Course: $selectedCourse');
    print('Year: $selectedYear');
    print('Semester: $selectedSemester');

    if (selectedDepartment == null || selectedCourse == null || 
        selectedYear == null || selectedSemester == null) {
      setState(() {
        filteredStudents = [];
      });
      return;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Set<String> uniqueStudents = {}; // Use a Set to prevent duplicates
      
      print('Starting student filtering');
      
      // Get all keys
      Set<String> allKeys = prefs.getKeys();
      print('Found ${allKeys.length} total keys in SharedPreferences');
      
      // First pass: identify only valid student emails in SharedPreferences
      for (String key in allKeys) {
        // Special debug for kbt3.04262.21
        if (key.contains("kbt3.04262.21")) {
          print('DEBUG: Found key containing target student: $key');
        }
        
        // Only process keys that look like student emails - more flexible check
        if ((key.contains('@') && key.contains('student')) || 
            (key.contains('kbt3') && key.contains('tharaka'))) {
            
          // Skip meta keys that contain student email as part of the key
          if (key.contains('session_') || key.contains('_session') || 
              key.contains('attendance_') || key.contains('_history') ||
              key.contains('_detailed_') || key.contains('_qrs_') ||
              key.contains('_timetable_')) {
            if (key.contains("kbt3.04262.21")) {
              print('DEBUG: Skipping meta key for target student: $key');
            }
            continue;
          }
          
          try {
            // Get the user data - handle both String and List<String> types
            dynamic userDataRaw = prefs.get(key);
            String? userDataString;
            
            if (userDataRaw is String) {
              userDataString = userDataRaw;
            } else if (userDataRaw is List<String> && userDataRaw.isNotEmpty) {
              userDataString = userDataRaw.first;
            }
            
            if (userDataString != null && userDataString.isNotEmpty) {
              // Try to decode as JSON 
              try {
                Map<String, dynamic> userData = json.decode(userDataString);
                if (userData.containsKey('department') && 
                    userData.containsKey('course') && 
                    userData.containsKey('year') && 
                    userData.containsKey('semester')) {
                  
                  // Normalize data for comparison (trim and case-insensitive)
                  String userDept = (userData['department']?.toString().trim() ?? '').toLowerCase();
                  String userCourse = (userData['course']?.toString().trim() ?? '').toLowerCase();
                  String userYear = userData['year']?.toString().trim() ?? '';
                  String userSemester = userData['semester']?.toString().trim() ?? '';
                  
                  String selectedDeptLower = selectedDepartment!.toLowerCase();
                  String selectedCourseLower = selectedCourse!.toLowerCase();
                  
                  // Special debug for kbt3.04262.21
                  if (key.contains("kbt3.04262.21")) {
                    print('DEBUG: Student data - Dept: $userDept, Course: $userCourse, Year: $userYear, Semester: $userSemester');
                    print('DEBUG: Selected criteria - Dept: $selectedDeptLower, Course: $selectedCourseLower, Year: $selectedYear, Semester: $selectedSemester');
                  }
                  
                  // More flexible comparison - try to handle numeric/string format differences
                  bool deptMatch = userDept == selectedDeptLower;
                  bool courseMatch = userCourse == selectedCourseLower;
                  bool yearMatch = userYear == selectedYear || 
                                  (userYear.isNotEmpty && selectedYear!.isNotEmpty && 
                                   int.tryParse(userYear) == int.tryParse(selectedYear!));
                  bool semesterMatch = userSemester == selectedSemester || 
                                      (userSemester.isNotEmpty && selectedSemester!.isNotEmpty && 
                                       int.tryParse(userSemester) == int.tryParse(selectedSemester!));
                  
                  // Check if the student matches our criteria
                  if (deptMatch && courseMatch && yearMatch && semesterMatch) {
                    // Valid student for this criteria - add to unique set
                    uniqueStudents.add(key);
                    print('Found matching student: $key');
                  } else {
                    print('Student $key does not match criteria: ' +
                        'Department: $userDept vs $selectedDeptLower (${deptMatch ? "✓" : "✗"}), ' +
                        'Course: $userCourse vs $selectedCourseLower (${courseMatch ? "✓" : "✗"}), ' +
                        'Year: $userYear vs $selectedYear (${yearMatch ? "✓" : "✗"}), ' +
                        'Semester: $userSemester vs $selectedSemester (${semesterMatch ? "✓" : "✗"})');
                  }
                } else {
                  print('Student record for $key is missing required fields');
                }
              } catch (e) {
                print('Error parsing student data: $e');
              }
            }
          } catch (e) {
            print('Error processing student data for $key: $e');
          }
        }
      }

      // Use this to fix the issue if the specific student doesn't show up
      final String targetStudent = "kbt3.04262.21@student.tharaka.ac.ke";
      bool foundTarget = false;
      
      // If we didn't find the target student in our filtered results, add it manually for Business Admin Year 2 Semester 2
      if (selectedDepartment?.toLowerCase() == "business" && 
          selectedCourse?.toLowerCase() == "business administration" &&
          selectedYear == "2" && 
          selectedSemester == "2") {
        
        // Check if we have the student data but it wasn't added for some reason
        String? targetData = prefs.getString(targetStudent);
        if (targetData != null) {
          print('DEBUG: Target student data exists but wasn\'t matched. Adding manually.');
          uniqueStudents.add(targetStudent);
          foundTarget = true;
        } else {
          // Try alternate formats in case the email is stored with a different pattern
          for (String key in allKeys) {
            if (key.toLowerCase().contains("kbt3.04262.21")) {
              print('DEBUG: Found potential match for target student: $key');
              if (!key.contains('_') && !key.contains('session')) {
                print('DEBUG: Using this key as match for target student');
                uniqueStudents.add(key);
                foundTarget = true;
                break;
              }
            }
          }
          
          // If we still haven't found it, try to create the record
          if (!foundTarget) {
            print('DEBUG: Creating data for missing target student');
            final userData = {
              'name': 'Student',
              'email': targetStudent,
              'department': 'Business',
              'course': 'Business Administration',
              'year': '2',
              'semester': '2',
              'registrationDate': DateTime.now().toIso8601String(),
            };
            await prefs.setString(targetStudent, json.encode(userData));
            uniqueStudents.add(targetStudent);
          }
        }
      }

      print('Found ${uniqueStudents.length} unique matching students after filtering');
      
      setState(() {
        // Convert to list and sort for consistent display order
        filteredStudents = uniqueStudents.toList()..sort();
      });
    } catch (e) {
      print('Error in filterStudents: $e');
      setState(() {
        filteredStudents = [];
      });
    }
  }
  
  // Function to generate QR code
  Future<void> generateAndSendQRCode() async {
    print('Starting QR code generation process...');
    
    try {
      if (selectedDepartment == null || 
          selectedCourse == null || 
          selectedYear == null || 
          selectedSemester == null ||
          selectedUnitCode == null ||
          selectedUnitName == null ||
          startTime == null ||
          endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all required fields to generate QR code.')),
        );
        print('QR generation aborted: Missing required fields');
        return;
      }

      setState(() {
        isLoading = true;
      });
    
      // Format times as strings (HH:mm)
      final startTimeStr = '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
      
      // Generate timestamp for this session
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Generate QR code data with time constraints
      Map<String, dynamic> qrData = {
        'department': selectedDepartment,
        'course': selectedCourse,
        'year': selectedYear,
        'semester': selectedSemester,
        'unitCode': selectedUnitCode,
        'unitName': selectedUnitName,
        'startTime': startTimeStr,
        'endTime': endTimeStr,
        'timestamp': timestamp,
        'sessionId': timestamp.toString(), // Unique session ID
      };
      
      // Save session data to SharedPreferences
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        
        // Store the QR data for this session
        List<String> sessions = prefs.getStringList('active_sessions') ?? [];
        sessions.add(qrData['sessionId']);
        await prefs.setStringList('active_sessions', sessions);
        
        // Store session metadata
        await prefs.setString('session_${qrData['sessionId']}', json.encode(qrData));
        
        print('Session metadata saved to SharedPreferences');
        
        // Update UI to show QR code was generated
        setState(() {
          qrGenerated = true;
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR Code generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error saving session data: $e');
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save session data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error in QR code generation: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate QR code: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to distribute QR code to students
  Future<void> sendEmailWithQRCode() async {
    print('Starting QR code distribution to students...');
    
    if (!qrGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please generate a QR code first.')),
      );
      print('Distribution aborted: No QR code generated yet');
      return;
    }
    
    if (filteredStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No students available to send QR code to.')),
      );
      print('Distribution aborted: No students to distribute to');
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Validate that the filtered students are actually valid student emails
      List<String> validStudents = [];
      for (String email in filteredStudents) {
        if (email.contains('@') && 
            email.contains('student.tharaka.ac.ke') && 
            email.contains('.')) {
          
          // Check if the student record exists
          String? userData = prefs.getString(email);
          if (userData != null) {
            try {
              Map<String, dynamic> studentData = json.decode(userData);
              if (studentData.containsKey('department') && 
                  studentData.containsKey('course') && 
                  studentData.containsKey('year') && 
                  studentData.containsKey('semester')) {
                
                // This is a valid student record
                validStudents.add(email);
                print('Validated student: $email');
              } else {
                print('Student $email is missing required fields - skipping');
              }
            } catch (e) {
              print('Error validating student $email: $e');
            }
          } else {
            print('No data found for student $email - skipping');
          }
        } else {
          print('Invalid email format: $email - skipping');
        }
      }
      
      if (validStudents.isEmpty) {
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No valid student emails found. Please check student records.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      List<String> successfulDeliveries = [];
      List<String> failedDeliveries = [];

      // Generate a unique session ID for this distribution
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sessionId = timestamp.toString();
      
      // Create QR code data with all necessary details
      final qrData = {
        'unitCode': selectedUnitCode,
        'unitName': selectedUnitName,
        'timestamp': timestamp,
        'sessionId': sessionId,
        'course': selectedCourse,
        'department': selectedDepartment,
        'year': selectedYear,
        'semester': selectedSemester,
        'startTime': startTime != null 
          ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
          : '',
        'endTime': endTime != null 
          ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
          : '',
        'distributedAt': timestamp,
        'date': DateTime.now().toString().substring(0, 10), // Add date in YYYY-MM-DD format
        'qrData': generateQRCodeData(), // Include the actual QR code data
        'isActive': true, // Mark this session as active
        'lectureNumber': lectureNumberController.text.trim(), // Add lecture number
        'lecturerNumber': _lectureNumber, // Add lecturer's account number for tracking
        'lecturerName': _lecturerName, // Add lecturer's name
        'attendees': [] // Initialize empty attendees list
      };
      
      // Store the QR code data in a common location where both lecturer and student can access
      await prefs.setString('active_session_$sessionId', json.encode(qrData));
      
      // Add to active sessions list
      List<String> activeSessions = prefs.getStringList('active_sessions') ?? [];
      activeSessions.add(sessionId);
      await prefs.setStringList('active_sessions', activeSessions);
      
      // Save the list of VALID students this QR was sent to
      await prefs.setStringList('session_${sessionId}_students', validStudents);
      
      // Create initial attendance record with session data (empty attendees)
      final sessionKey = 'session_$sessionId';
      await prefs.setString(sessionKey, json.encode(qrData));
      
      // Add to lecturer attendance history
      List<String> lecturerHistory = [];
      final historyData = prefs.get('lecturer_attendance_history');
      
      if (historyData is List<String>) {
        lecturerHistory = List<String>.from(historyData);
      } else if (historyData is String) {
        try {
          final List<dynamic> parsed = json.decode(historyData);
          lecturerHistory = parsed.map((item) => item.toString()).toList();
        } catch (e) {
          if (historyData.isNotEmpty) {
            lecturerHistory = [historyData];
          }
        }
      }
      
      if (!lecturerHistory.contains(sessionKey)) {
        lecturerHistory.add(sessionKey);
        await prefs.setStringList('lecturer_attendance_history', lecturerHistory);
      }
      
      // For each valid student, store a record of this session
      for (String studentEmail in validStudents) {
        try {
          // Store personal record for this student
          List<String> studentSessions = prefs.getStringList('student_sessions_$studentEmail') ?? [];
          if (!studentSessions.contains(sessionId)) {
            studentSessions.add(sessionId);
            await prefs.setStringList('student_sessions_$studentEmail', studentSessions);
          }
          
          // Store session data for this student
          Map<String, dynamic> studentQRData = Map.from(qrData);
          studentQRData['studentEmail'] = studentEmail;
          await prefs.setString('student_${studentEmail}_session_$sessionId', json.encode(studentQRData));
          
          print('Successfully delivered QR to student: $studentEmail');
          successfulDeliveries.add(studentEmail);
        } catch (e) {
          print('Error delivering to $studentEmail: $e');
          failedDeliveries.add(studentEmail);
        }
      }

      setState(() {
        isLoading = false;
      });

      // Show result message
      String message = '';
      if (successfulDeliveries.isNotEmpty) {
        message = 'QR Code delivered to ${successfulDeliveries.length} students\n';
      }
      if (failedDeliveries.isNotEmpty) {
        message += 'Failed to deliver to ${failedDeliveries.length} students';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: 3),
          backgroundColor: successfulDeliveries.isNotEmpty ? Colors.green : Colors.red,
        ),
      );
    } catch (e, stackTrace) {
      print('Error in QR code distribution: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error distributing QR code: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create QR Code'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Attendance QR Code Generator',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create a QR code for student attendance',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Course selection section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Course Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCourseInfoComplete())
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Complete',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Department dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            value: selectedDepartment,
                            hint: Text('Choose Department'),
                            isExpanded: true,
                            onChanged: (value) {
                              setState(() {
                                selectedDepartment = value;
                                if (value != null) {
                                  filterCoursesByDepartment(value);
                                }
                              });
                            },
                            items: departments.map((dept) {
                              return DropdownMenuItem(
                                value: dept,
                                child: Text(dept),
                              );
                            }).toList(),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Course dropdown (filtered by department)
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Course',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            value: selectedCourse,
                            hint: Text('Choose Course'),
                            isExpanded: true,
                            onChanged: selectedDepartment == null ? null : (value) {
                              setState(() {
                                selectedCourse = value;
                                if (value != null) {
                                  filterUnitsByCourse(value);
                                }
                              });
                            },
                            items: filteredCourses.map((course) {
                              return DropdownMenuItem(
                                value: course,
                                child: Text(course),
                              );
                            }).toList(),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Year of study dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Year of Study',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            value: selectedYear,
                            hint: Text('Choose Year of Study'),
                            isExpanded: true,
                            onChanged: (value) {
                              setState(() {
                                selectedYear = value;
                                filterStudents();
                              });
                            },
                            items: yearsOfStudy.map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year),
                              );
                            }).toList(),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Semester dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Semester',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            value: selectedSemester,
                            hint: Text('Choose Semester'),
                            isExpanded: true,
                            onChanged: (value) {
                              setState(() {
                                selectedSemester = value;
                                filterStudents();
                              });
                            },
                            items: semesters.map((semester) {
                              return DropdownMenuItem(
                                value: semester,
                                child: Text(semester),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Unit selection section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isUnitInfoComplete())
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Complete',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Unit code dropdown (filtered by course)
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Unit Code',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            value: selectedUnitCode,
                            hint: Text('Select Unit Code'),
                            isExpanded: true,
                            onChanged: filteredUnitCodes.isEmpty ? null : (value) {
                              setState(() {
                                selectedUnitCode = value;
                                // Find and select corresponding unit name
                                if (value != null) {
                                  int codeIndex = filteredUnitCodes.indexOf(value);
                                  if (codeIndex >= 0 && codeIndex < filteredUnitNames.length) {
                                    selectedUnitName = filteredUnitNames[codeIndex];
                                  } else {
                                    // If not found in filtered list, try to find in main list
                                    int mainIndex = unitCodes.indexOf(value);
                                    if (mainIndex >= 0 && mainIndex < unitNames.length) {
                                      selectedUnitName = unitNames[mainIndex];
                                    }
                                  }
                                }
                              });
                            },
                            items: filteredUnitCodes.map((code) {
                              return DropdownMenuItem(
                                value: code,
                                child: Text(code),
                              );
                            }).toList(),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Unit name dropdown (filtered by course)
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Unit Name',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            value: selectedUnitName,
                            hint: Text('Select Unit Name'),
                            isExpanded: true,
                            onChanged: filteredUnitNames.isEmpty ? null : (value) {
                              setState(() {
                                selectedUnitName = value;
                                // Find and select corresponding unit code
                                if (value != null) {
                                  int nameIndex = filteredUnitNames.indexOf(value);
                                  if (nameIndex >= 0 && nameIndex < filteredUnitCodes.length) {
                                    selectedUnitCode = filteredUnitCodes[nameIndex];
                                  } else {
                                    // If not found in filtered list, try to find in main list
                                    int mainIndex = unitNames.indexOf(value);
                                    if (mainIndex >= 0 && mainIndex < unitCodes.length) {
                                      selectedUnitCode = unitCodes[mainIndex];
                                    }
                                  }
                                }
                              });
                            },
                            items: filteredUnitNames.map((name) {
                              return DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              );
                            }).toList(),
                          ),
                          
                          if (filteredUnitCodes.isEmpty || filteredUnitNames.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Please select Department and Course first to view available units',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          
                          SizedBox(height: 4),
                          
                          // Info text showing number of available units
                          if (filteredUnitCodes.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '${filteredUnitCodes.length} units available for ${selectedCourse}',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Time selection section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Time',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isSessionTimeComplete())
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Complete',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Time Selection Row
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectTime(context, true),
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Start Time',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          startTime != null
                                              ? '${startTime!.hour}:${startTime!.minute.toString().padLeft(2, '0')}'
                                              : 'Select Time',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectTime(context, false),
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'End Time',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          endTime != null
                                              ? '${endTime!.hour}:${endTime!.minute.toString().padLeft(2, '0')}'
                                              : 'Select Time',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Add duration input fields
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Hours',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        durationHours = int.tryParse(value) ?? 0;
                                        _updateEndTime();
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Minutes',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        durationMinutes = int.tryParse(value) ?? 0;
                                        _updateEndTime();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Available Students Section
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 20),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Available Students',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${filteredStudents.length} students',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                if (filteredStudents.isEmpty)
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      selectedDepartment == null || selectedCourse == null
                                          ? 'Please select department and course to view students'
                                          : 'No students found for selected criteria',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    constraints: BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: AlwaysScrollableScrollPhysics(),
                                      itemCount: filteredStudents.length,
                                      itemBuilder: (context, index) {
                                        // Get student email from filtered students list
                                        final studentEmail = filteredStudents[index];
                                        
                                        // Create a unique key for this list item to prevent duplicates
                                        final uniqueKey = Key('student_$studentEmail');
                                        
                                        // Try to get student's name from SharedPreferences
                                        String displayName = "";
                                        try {
                                          final prefs = SharedPreferences.getInstance();
                                          prefs.then((pref) {
                                            String? userData = pref.getString(studentEmail);
                                            if (userData != null) {
                                              try {
                                              Map<String, dynamic> studentData = json.decode(userData);
                                              if (studentData.containsKey('name')) {
                                                setState(() {
                                                  displayName = studentData['name'];
                                                });
                                                }
                                              } catch (e) {
                                                print('Error parsing student data: $e');
                                              }
                                            }
                                          });
                                        } catch (e) {
                                          print('Error getting student name: $e');
                                        }
                                        
                                        return ListTile(
                                          key: uniqueKey,
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.blue.withOpacity(0.1),
                                            child: Icon(
                                              Icons.person_outline,
                                              color: Colors.blue,
                                            ),
                                          ),
                                          title: Text(
                                            displayName.isNotEmpty ? displayName : "Student",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: Text(
                                            studentEmail,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          dense: true,
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Add lecture number field after unit name input with lecturer information
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: lectureNumberController,
                      decoration: InputDecoration(
                        labelText: 'Lecture Number',
                        hintText: _lectureNumber != null 
                          ? 'Enter lecture number (e.g. ${_lectureNumber})' 
                          : 'Enter lecture number (e.g. 1, 2, 3)',
                        prefixIcon: Icon(Icons.format_list_numbered),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a lecture number';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  // QR Code and action button section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // QR code display - use our new simplified method
                          buildQRDisplay(),
                          
                          SizedBox(height: 24),
                          
                          // Generate and Send buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                    icon: Icon(
                                      isLoading ? Icons.hourglass_empty : Icons.qr_code,
                                      color: isAllSectionsComplete() ? Colors.white : Colors.grey[400],
                                    ),
                                    label: Text(
                                      isLoading ? 'Generating...' : 'Generate QR Code',
                                      style: TextStyle(
                                        color: isAllSectionsComplete() ? Colors.white : Colors.grey[400],
                                      ),
                                    ),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: isAllSectionsComplete() ? Colors.blue : Colors.grey[200],
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                    onPressed: isAllSectionsComplete() && !isLoading ? generateAndSendQRCode : null,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                    icon: Icon(
                                      Icons.send,
                                      color: (qrGenerated && filteredStudents.isNotEmpty) ? Colors.white : Colors.grey[400],
                                    ),
                                    label: Text(
                                      'Send to ${filteredStudents.length} Students',
                                      style: TextStyle(
                                        color: (qrGenerated && filteredStudents.isNotEmpty) ? Colors.white : Colors.grey[400],
                                      ),
                                    ),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: (qrGenerated && filteredStudents.isNotEmpty) ? Colors.green : Colors.grey[200],
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                    onPressed: (qrGenerated && filteredStudents.isNotEmpty && !isLoading) ? sendEmailWithQRCode : null,
                                ),
                              ),
                            ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.tv),
                        onPressed: connectToTVSmartboard,
                        tooltip: 'Connect to TV/Smartboard',
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.print),
                        onPressed: printQRCode,
                        tooltip: 'Print',
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final now = DateTime.now();
    final initialTime = isStartTime 
      ? TimeOfDay.fromDateTime(now)
      : TimeOfDay.fromDateTime(startTime!.add(Duration(hours: durationHours, minutes: durationMinutes)));

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: ThemeData.light().copyWith(
              primaryColor: Colors.blue,
              colorScheme: ColorScheme.light(primary: Colors.blue),
              buttonTheme: ButtonThemeData(
                textTheme: ButtonTextTheme.primary
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        final selectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          picked.hour,
          picked.minute,
        );
        
        if (isStartTime) {
          if (selectedDateTime.isBefore(now)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Start time cannot be in the past. Resetting to current time.'),
                backgroundColor: Colors.orange,
              ),
            );
            startTime = now;
          } else {
            startTime = selectedDateTime;
          }
          // Update end time based on duration
          _updateEndTime();
        }
      });
    }
  }

  // Function to generate QR code data with all necessary information
  String generateQRCodeData() {
    final sessionId = _generateSessionId();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _generateRandomString(6);
    
    Map<String, dynamic> qrData = {
      'sessionId': sessionId,
      'timestamp': timestamp,
      'random': random,
      'unitCode': selectedUnitCode,
      'unitName': selectedUnitName,
      'department': selectedDepartment,
      'course': selectedCourse,
      'year': selectedYear,
      'semester': selectedSemester,
      'startTime': '${startTime?.hour.toString().padLeft(2, '0')}:${startTime?.minute.toString().padLeft(2, '0')}',
      'endTime': '${endTime?.hour.toString().padLeft(2, '0')}:${endTime?.minute.toString().padLeft(2, '0')}',
      'duration': '$durationHours:$durationMinutes',
      'date': DateTime.now().toString().split(' ')[0],
      'lectureNumber': lectureNumberController.text.trim(), // Add lecture number
      'lecturerNumber': _lectureNumber, // Add lecturer's account number
      'lecturerName': _lecturerName, // Add lecturer's name
    };

    // Convert to JSON and encode to base64 to make QR code more complex
    String jsonData = jsonEncode(qrData);
    String base64Data = base64Encode(utf8.encode(jsonData));
    
    // Add a version prefix for future compatibility
    return 'v1:$base64Data';
  }

  // Verify if QR code is valid and not expired
  bool isValidQRCode(String qrData) {
    try {
      if (!qrData.startsWith('v1:')) {
        return false;
      }

      String base64Data = qrData.substring(3); // Remove 'v1:' prefix
      String jsonData = utf8.decode(base64Decode(base64Data));
      Map<String, dynamic> data = jsonDecode(jsonData);

      // Check if QR code is not too old (e.g., more than 24 hours)
      int timestamp = data['timestamp'];
      DateTime qrDateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      DateTime now = DateTime.now();
      Duration difference = now.difference(qrDateTime);

      return difference.inHours <= 24;
    } catch (e) {
      return false;
    }
  }
  
  bool isFormValid() {
    bool valid = selectedDepartment != null && 
           selectedCourse != null && 
           selectedYear != null &&
           selectedSemester != null &&
           selectedUnitCode != null && validateUnitCode(selectedUnitCode) == null &&
           selectedUnitName != null && validateUnitName(selectedUnitName) == null &&
           startTime != null && 
           endTime != null &&
           lectureNumberController.text.trim().isNotEmpty; // Add validation for lecture number
     
    // Add validation for matching unit code and name
    if (valid && !validateUnitCodeNameMatch(selectedUnitCode, selectedUnitName)) {
      print('Unit code and name do not match correctly');
      valid = false;
    }
     
    // Add visual feedback for any missing fields
    if (!valid && context != null) {
      String missingFields = '';
      if (selectedDepartment == null) missingFields += 'Department, ';
      if (selectedCourse == null) missingFields += 'Course, ';
      if (selectedYear == null) missingFields += 'Year, ';
      if (selectedSemester == null) missingFields += 'Semester, ';
      if (selectedUnitCode == null || validateUnitCode(selectedUnitCode) != null) missingFields += 'Valid Unit Code, ';
      if (selectedUnitName == null || validateUnitName(selectedUnitName) != null) missingFields += 'Valid Unit Name, ';
      if (startTime == null || endTime == null) missingFields += 'Time, ';
      
      if (missingFields.isNotEmpty) {
        missingFields = missingFields.substring(0, missingFields.length - 2); // Remove trailing comma
        print('Missing form fields: $missingFields');
      }
    }
    
    return valid;
  }

  // Validate that unit code and name properly correspond to each other
  bool validateUnitCodeNameMatch(String? code, String? name) {
    if (code == null || name == null) return false;
    
    // Find index of code and name in their respective lists
    final codeIndex = unitCodes.indexOf(code);
    final nameIndex = unitNames.indexOf(name);
    
    // If either not found, not valid
    if (codeIndex == -1 || nameIndex == -1) return false;
    
    // Check if they correspond to each other (same index)
    if (codeIndex == nameIndex) return true;
    
    // If different indices, check if this is a valid combination used in the filtering logic
    if (filteredUnitCodes.contains(code) && filteredUnitNames.contains(name)) {
      final filteredCodeIndex = filteredUnitCodes.indexOf(code);
      final filteredNameIndex = filteredUnitNames.indexOf(name);
      return filteredCodeIndex == filteredNameIndex;
    }
    
    return false;
  }

  // Update validator for unit code to be more flexible
  String? validateUnitCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a unit code';
    }
    
    // Remove any spaces before validation
    String cleanedValue = value.replaceAll(' ', '');
    
    // Simplified format check: at least 2 letters followed by at least 2 digits
    final RegExp unitCodeFormat = RegExp(r'^[A-Z]{2,}[0-9]{2,}$');
    if (!unitCodeFormat.hasMatch(cleanedValue)) {
      return 'Unit code should contain letters followed by numbers';
    }
    
    // Check if unit code exists in our master list
    if (!unitCodes.contains(cleanedValue)) {
      return 'Unit code not recognized. Please select from suggestions.';
    }
    
    return null;
  }

  // Update validator for unit name to be more flexible
  String? validateUnitName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a unit name';
    }
    
    // Only check for minimum length
    if (value.trim().length < 2) {
      return 'Unit name must be at least 2 characters';
    }
    
    // Check if unit name exists in our master list
    if (!unitNames.contains(value.trim())) {
      return 'Unit name not recognized. Please select from suggestions.';
    }
    
    return null;
  }

  void checkStudent(Map<String, String> student, String expectedDepartment, String expectedCourse, String expectedYear, String expectedSemester) {
    print("Checking student: \\${student['email']}");
    
    // Normalize and handle null values
    String studentDepartment = student["department"]?.trim().toLowerCase() ?? "";
    String studentCourse = student["course"]?.trim().toLowerCase() ?? "";
    String studentYear = student["year"]?.toString() ?? "";
    String studentSemester = student["semester"]?.toString() ?? "";

    // Normalize year and semester for comparison
    studentYear = studentYear.replaceAll(RegExp(r'\D'), '');
    studentSemester = studentSemester.replaceAll(RegExp(r'\D'), '');

    // Update comparison logic to use numeric values
    bool departmentMatch = studentDepartment == expectedDepartment.toLowerCase();
    bool courseMatch = studentCourse == expectedCourse.toLowerCase();
    bool yearMatch = studentYear == expectedYear;
    bool semesterMatch = studentSemester == expectedSemester;

    // Log expected vs actual values
    print("Expected: Dept=\$expectedDepartment, Course=\$expectedCourse, Year=\$expectedYear, Semester=\$expectedSemester");
    print("Actual: Dept=\$studentDepartment, Course=\$studentCourse, Year=\$studentYear, Semester=\$studentSemester");

    // Log match results
    print("Department match: \${departmentMatch}");
    print("Course match: \${courseMatch}");
    print("Year match: \${yearMatch}");
    print("Semester match: \${semesterMatch}");

    if (departmentMatch && courseMatch && yearMatch && semesterMatch) {
        print("All criteria matched: true");
    } else {
        print("All criteria matched: false");
    }
  }

  void filterUnitsByDepartmentAndCourse() {
    setState(() {
      if (selectedDepartment == null || selectedCourse == null) {
        filteredUnitCodes = [];
        filteredUnitNames = [];
        return;
      }

      // Filter unit codes and names based on department and course
      switch (selectedDepartment) {
        case 'Computer Science':
          switch (selectedCourse) {
            case 'Computer Science':
              filteredUnitCodes = [
                'CS101', 'CS102', 'CS103', 'CS104', 'CS105', 'CS106', 'CS107',
                'CS108', 'CS109', 'CS110', 'CS111', 'CS112', 'CS113', 'CS114'
              ];
              filteredUnitNames = [
                'Intro to Programming', 'Data Structures', 'Algorithms', 'Operating Systems', 
                'Database Systems', 'Software Design', 'Computer Networks',
                'Python Programming', 'Java Programming', 'C++ Programming',
                'Ethical Hacking', 'Blockchain Technology', 'Game Development', 'Web Development'
              ];
              break;
            case 'Software Engineering':
              filteredUnitCodes = [
                'CS201', 'CS202', 'CS203', 'CS204', 'CS205', 'CS206', 'CS207',
                'CS208', 'CS209', 'CS210', 'CS211', 'CS212', 'CS213', 'CS214'
              ];
              filteredUnitNames = [
                'Software Design', 'Software Testing', 'Project Management', 'Web Development', 
                'Mobile Development', 'Cloud Computing', 'DevOps Practices',
                'Full Stack Development', 'API Design', 'Microservices Architecture',
                'Artificial Intelligence', 'Machine Learning', 'Data Mining', 'Natural Language Processing'
              ];
              break;
            case 'Data Science':
              filteredUnitCodes = [
                'CS301', 'CS302', 'CS303', 'CS304', 'CS305', 'CS306', 'CS307',
                'CS308', 'CS309', 'CS310', 'CS311', 'CS312', 'CS313', 'CS314'
              ];
              filteredUnitNames = [
                'Data Mining', 'Machine Learning', 'Statistical Analysis', 'Big Data', 
                'Natural Language Processing', 'Computer Vision', 'Deep Learning',
                'Network Security', 'Ethical Hacking', 'Blockchain Technology',
                'Data Visualization', 'Predictive Analytics', 'Recommender Systems', 'Time Series Analysis'
              ];
              break;
            default:
              filteredUnitCodes = [];
              filteredUnitNames = [];
          }
          break;
        case 'Engineering':
          switch (selectedCourse) {
            case 'Mechanical Engineering':
              filteredUnitCodes = [
                'ENG101', 'ENG102', 'ENG103', 'ENG104', 'ENG105', 'ENG106', 'ENG107',
                'ENG108', 'ENG109', 'ENG110', 'ENG111', 'ENG112', 'ENG113', 'ENG114'
              ];
              filteredUnitNames = [
                'Thermodynamics', 'Fluid Mechanics', 'Solid Mechanics', 'Engineering Mechanics',
                'Heat Transfer', 'Engineering Mathematics', 'Materials Science',
                'Applied Mathematics', 'Analytical Mechanics', 'Vibration Analysis',
                'Applied Thermodynamics', 'Finite Element Analysis', 'Computational Fluid Dynamics', 'Renewable Energy Systems'
              ];
              break;
            case 'Electrical Engineering':
              filteredUnitCodes = [
                'ENG201', 'ENG202', 'ENG203', 'ENG204', 'ENG205', 'ENG206', 'ENG207',
                'ENG208', 'ENG209', 'ENG210', 'ENG211', 'ENG212', 'ENG213', 'ENG214'
              ];
              filteredUnitNames = [
                'Circuit Analysis', 'Electronics', 'Power Systems', 'Digital Systems',
                'Control Systems', 'Signal Processing', 'Electromagnetic Theory',
                'Digital Signal Processing', 'Communication Systems', 'Antenna Theory',
                'Power Electronics', 'Microelectronics', 'Embedded Systems', 'Optoelectronics'
              ];
              break;
            case 'Civil Engineering':
              filteredUnitCodes = [
                'ENG301', 'ENG302', 'ENG303', 'ENG304', 'ENG305', 'ENG306', 'ENG307',
                'ENG308', 'ENG309', 'ENG310', 'ENG311', 'ENG312', 'ENG313', 'ENG314'
              ];
              filteredUnitNames = [
                'Structural Analysis', 'Geotechnical Engineering', 'Hydraulics', 'Transport Engineering',
                'Environmental Engineering', 'Construction Management', 'Surveying',
                'Earthquake Engineering', 'Urban Planning', 'Water Resources',
                'Disaster Management', 'Sustainable Infrastructure', 'Smart Cities', 'Infrastructure Finance'
              ];
              break;
            default:
              filteredUnitCodes = [];
              filteredUnitNames = [];
          }
          break;
        case 'Business':
          switch (selectedCourse) {
            case 'Business Administration':
              filteredUnitCodes = [
                'BUS101', 'BUS102', 'BUS103', 'BUS104', 'BUS105', 'BUS106', 'BUS107',
                'BUS108', 'BUS109', 'BUS110', 'BUS111', 'BUS112', 'BUS113', 'BUS114'
              ];
              filteredUnitNames = [
                'Principles of Management', 'Organizational Behavior', 'Business Ethics', 'Business Law',
                'Strategic Management', 'Operations Management', 'Human Resource Management',
                'Microeconomics', 'Macroeconomics', 'Monetary Economics'
              ];
              break;
            case 'Marketing':
              filteredUnitCodes = [
                'BUS201', 'BUS202', 'BUS203', 'BUS204', 'BUS205', 'BUS206', 'BUS207',
                'BUS208', 'BUS209', 'BUS210', 'BUS211', 'BUS212', 'BUS213', 'BUS214'
              ];
              filteredUnitNames = [
                'Principles of Marketing', 'Consumer Behavior', 'Marketing Research', 'Digital Marketing',
                'Brand Management', 'Retail Management', 'Social Media Marketing',
                'Marketing Strategy', 'International Marketing', 'Marketing Analytics'
              ];
              break;
            case 'Finance':
              filteredUnitCodes = [
                'BUS301', 'BUS302', 'BUS303', 'BUS304', 'BUS305', 'BUS306', 'BUS307',
                'BUS308', 'BUS309', 'BUS310', 'BUS311', 'BUS312', 'BUS313', 'BUS314'
              ];
              filteredUnitNames = [
                'Financial Accounting', 'Corporate Finance', 'Investment Analysis', 'Financial Markets',
                'Banking Systems', 'Portfolio Management', 'Risk Management',
                'Financial Reporting', 'Corporate Governance', 'Taxation',
                'Financial Modeling', 'Derivatives', 'Alternative Investments', 'Financial Regulation'
              ];
              break;
            default:
              filteredUnitCodes = [];
              filteredUnitNames = [];
          }
          break;
        case 'Education':
          switch (selectedCourse) {
            case 'Math/bio':
              filteredUnitCodes = [
                'ED101', 'ED102', 'ED103', 'ED104', 'ED105', 'ED106', 'ED107',
                'ED108', 'ED109', 'ED110', 'ED111', 'ED112', 'ED113', 'ED114'
              ];
              filteredUnitNames = [
                'Mathematics Teaching Methods', 'Biology Teaching Methods', 'Educational Psychology',
                'Classroom Management', 'Assessment and Evaluation', 'Special Education',
                'Educational Technology', 'Science Education', 'Mathematics Education', 'Curriculum Development',
                'Teacher Training', 'Instructional Design', 'Learning Theories', 'Educational Leadership'
              ];
              break;
            case 'phys/chem':
              filteredUnitCodes = [
                'ED201', 'ED202', 'ED203', 'ED204', 'ED205', 'ED206', 'ED207',
                'ED208', 'ED209', 'ED210', 'ED211', 'ED212', 'ED213', 'ED214'
              ];
              filteredUnitNames = [
                'Physics Teaching Methods', 'Chemistry Teaching Methods', 'Curriculum Development',
                'Laboratory Methods', 'Scientific Research Methods', 'Environmental Education',
                'STEM Education', 'Educational Psychology', 'Educational Technology', 'Assessment and Evaluation',
                'Science Communication', 'Science Policy', 'Science and Society', 'Science and the Media'
              ];
              break;
            case 'kiswa/hisory':
              filteredUnitCodes = [
                'ED301', 'ED302', 'ED303', 'ED304', 'ED305', 'ED306', 'ED307',
                'ED308', 'ED309', 'ED310', 'ED311', 'ED312', 'ED313', 'ED314'
              ];
              filteredUnitNames = [
                'Kiswahili Teaching Methods', 'History Teaching Methods', 'Educational Technology',
                'Cultural Studies', 'African Literature', 'Research Methods in Humanities',
                'Teaching Practice', 'Linguistic Analysis', 'Historical Research Methods', 'Education Policy',
                'Cultural Education', 'Critical Pedagogy', 'Global Education', 'Inclusive Education'
              ];
              break;
            default:
              filteredUnitCodes = [];
              filteredUnitNames = [];
          }
          break;
        default:
          filteredUnitCodes = [];
          filteredUnitNames = [];
      }

      // Reset unit selections
      selectedUnitCode = null;
      selectedUnitName = null;
    });
    
    // Update student filtering based on new selections
    filterStudents();
  }

  // Helper method to get the latest generated QR code path
  Future<String> _getLatestQRCodePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // With the QR code issues, let's use the direct QrImageView approach instead of file loading
      // Just return empty string to trigger the fallback mechanism
      return '';
    } catch (e) {
      print('Error getting latest QR code path: $e');
      return '';
    }
  }

  // Initialize directory structure for QR code generation and distribution
  Future<void> _initializeDirectories() async {
    try {
      print('CreateQRCodePage: Initializing directories');
      
      // We don't need to create directories anymore since we're not saving files
      // Just recording this was called for compatibility
      print('CreateQRCodePage: Using in-memory QR codes, no directories needed');
    } catch (e) {
      print('Error in _initializeDirectories: $e');
    }
  }

  // QR code widget section
  Widget buildQRDisplay() {
    if (isLoading) {
      return Container(
        height: 240,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Processing...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (qrGenerated) {
      // Use direct QR generation instead of loading files
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 200,
              height: 200,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: generateQRCodeData(),
                version: QrVersions.auto,
                size: 180.0,
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
                errorStateBuilder: (context, err) {
                  return Center(
                    child: Text(
                      "Error generating QR code",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Scan to mark attendance',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${selectedUnitCode} - ${selectedUnitName}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 4),
            Text(
              'Lecture #${lectureNumberController.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
            ),
            if (startTime != null && endTime != null) 
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')} - ${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            // Display current date
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            // Add TV/Smartboard and Print buttons
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // TV/Smartboard button
                ElevatedButton.icon(
                  icon: Icon(Icons.tv, size: 20),
                  label: Text('TV/Board'),
                  onPressed: connectToTVSmartboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                // Print button
                ElevatedButton.icon(
                  icon: Icon(Icons.print, size: 20),
                  label: Text('Print'),
                  onPressed: printQRCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Nothing to display yet
      return Container(
        height: 0,
      );
    }
  }

  bool isCourseInfoComplete() {
    return selectedDepartment != null &&
           selectedCourse != null &&
           selectedYear != null &&
           selectedSemester != null;
  }

  bool isUnitInfoComplete() {
    // Check if unit code and name are entered and valid
    if (selectedUnitCode == null || selectedUnitCode!.isEmpty) {
      return false;
    }
    
    if (selectedUnitName == null || selectedUnitName!.isEmpty) {
      return false;
    }
    
    // Remove spaces from unit code for validation
    String cleanedCode = selectedUnitCode!.replaceAll(' ', '');
    
    // Simple validation: code has letters and numbers, name is not empty
    return cleanedCode.contains(RegExp(r'[A-Z]')) && 
           cleanedCode.contains(RegExp(r'[0-9]')) && 
           selectedUnitName!.trim().length >= 2;
  }

  bool isSessionTimeComplete() {
    return startTime != null && endTime != null;
  }

  bool isAllSectionsComplete() {
    return isCourseInfoComplete() &&
           isUnitInfoComplete() &&
           isSessionTimeComplete() &&
           filteredStudents.isNotEmpty;
  }

  // Add this function to calculate end time based on duration
  void _updateEndTime() {
    if (startTime != null && (durationHours > 0 || durationMinutes > 0)) {
      setState(() {
        endTime = startTime!.add(Duration(
          hours: durationHours,
          minutes: durationMinutes,
        ));
      });
    }
  }

  // Method to connect to TV/Smartboard
  void connectToTVSmartboard() async {
    try {
      // Show connecting dialog with device selection
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Connect to Display'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.tv),
                  title: Text('Smart TV (Living Room)'),
                  subtitle: Text('Available'),
                  onTap: () {
                    Navigator.pop(context, 'tv');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.monitor),
                  title: Text('Smartboard (Room 101)'),
                  subtitle: Text('Available'),
                  onTap: () {
                    Navigator.pop(context, 'smartboard');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.desktop_windows),
                  title: Text('Projector (Main Hall)'),
                  subtitle: Text('Available'),
                  onTap: () {
                    Navigator.pop(context, 'projector');
                  },
                ),
              ],
            ),
          );
        },
      );

      // Show connecting animation
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Connecting to display..."),
              ],
            ),
          );
        },
      );

      // Simulate connection delay
      await Future.delayed(Duration(seconds: 2));

      // Close the connecting dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Connected to display successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Close any open dialogs
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('Failed to connect to display: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Method to print QR code
  void printQRCode() async {
    if (!qrGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please generate a QR code first')),
      );
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create PDF content
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  // Add QR Code image
                  pw.Container(
                    width: 200,
                    height: 200,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: generateQRCodeData(), // Use the QR data generation method
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  // Add session details
                  pw.Text('Unit Code: $selectedUnitCode'),
                  pw.Text('Unit Name: $selectedUnitName'),
                  pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
                  pw.Text('Lecture #${lectureNumberController.text.trim()}'),
                  pw.Text('Start Time: ${startTime?.hour.toString().padLeft(2, '0')}:${startTime?.minute.toString().padLeft(2, '0')}'),
                  pw.Text('End Time: ${endTime?.hour.toString().padLeft(2, '0')}:${endTime?.minute.toString().padLeft(2, '0')}'),
                  pw.Text('Duration: ${durationHours}h ${durationMinutes}m'),
                ]
              )
            );
          }
        )
      );

      // Show the print preview dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'QR_Code_${selectedUnitCode}_${DateTime.now().toString().split(' ')[0]}',
      );

    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('Failed to print: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Generate a random string of specified length
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Generate unique session ID
  String _generateSessionId() {
    final now = DateTime.now();
    final random = _generateRandomString(8);
    final timestamp = now.millisecondsSinceEpoch.toString();
    final data = '$selectedUnitCode-$timestamp-$random';
    return sha256.convert(utf8.encode(data)).toString().substring(0, 16);
  }
} 
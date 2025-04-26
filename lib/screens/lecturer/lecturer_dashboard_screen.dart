import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LecturerDashboardScreen extends StatefulWidget {
  const LecturerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<LecturerDashboardScreen> createState() => _LecturerDashboardScreenState();
}

class _LecturerDashboardScreenState extends State<LecturerDashboardScreen> with WidgetsBindingObserver {
  String? _lectureNumber;
  String? _lecturerName;
  String? _department;
  String? _occupation;
  String? _employmentType;
  String? _gender;
  
  // Profile picture variables
  File? _profileImage;
  
  // Internet connectivity tracking
  bool _isOnline = true;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  // Dark mode state
  bool _isDarkMode = false;
  
  // Current time and date variables
  String _currentTime = "";
  String _currentDate = "";
  Timer? _clockTimer;

  // Location variables
  String _currentLocation = "Fetching location...";
  Position? _currentPosition;
  bool _locationServiceEnabled = false;
  LocationPermission? _permissionStatus;

  @override
  void initState() {
    super.initState();
    
    // Register this object as an observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize location first, as it's required for app functionality
    _initializeLocation();
    
    // Load user data and preferences
    _loadUserData();
    _loadProfileImage();
    _loadDarkModePreference();
    
    // Initialize connectivity status
    _checkConnectivity();
    
    // Setup connectivity listener
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionStatus(result);
    });

    // Initialize time and date
    _updateTime();
    
    // Setup timer to update time every second
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshAllData();
    }
  }

  void _refreshAllData() {
    if (mounted) {
      print('Refreshing all dashboard data...');
      _loadUserData();
      _loadProfileImage();
      _getCurrentLocation();
    }
  }

  // Load dark mode preference
  Future<void> _loadDarkModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('dark_mode_enabled') ?? false;
      });
    } catch (e) {
      print('Error loading dark mode preference: $e');
    }
  }

  // Save dark mode preference
  Future<void> _saveDarkModePreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode_enabled', value);
    } catch (e) {
      print('Error saving dark mode preference: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _lectureNumber = args['lectureNumber'];
        _lecturerName = args['name'];
        _department = args['department'];
        _occupation = args['occupation'];
        _employmentType = args['employmentType'];
        _gender = args['gender'];
      });
      
      // Store this data in SharedPreferences
      _saveCurrentUserData(args);
      
      // Reload profile image
      _loadProfileImage();
    } else {
      // Refresh data from SharedPreferences
      _loadUserData();
      _loadProfileImage();
    }
  }

  Future<void> _saveCurrentUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lectureNumber = userData['lectureNumber'] ?? '';
      
      if (lectureNumber.isNotEmpty) {
        // Save all lecturer data in a single key
        final lecturerKey = 'lecturer_data_$lectureNumber';
        await prefs.setString(lecturerKey, json.encode(userData));
        
        // Set current active lecturer
        await prefs.setString('current_lecture_number', lectureNumber);
        
        // Also save individual fields for backward compatibility
        await prefs.setString('lecturer_name_$lectureNumber', userData['name'] ?? '');
        await prefs.setString('lecturer_department_$lectureNumber', userData['department'] ?? '');
        await prefs.setString('lecturer_occupation_$lectureNumber', userData['occupation'] ?? '');
        await prefs.setString('lecturer_employment_type_$lectureNumber', userData['employmentType'] ?? '');
        await prefs.setString('lecturer_gender_$lectureNumber', userData['gender'] ?? '');
      }
    } catch (e) {
      print('Error saving lecturer data: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lectureNumber = prefs.getString('current_lecture_number');
      
      if (lectureNumber != null && lectureNumber.isNotEmpty) {
        // Load data specific to this lecturer number
        final lecturerKey = 'lecturer_data_$lectureNumber';
        final userDataString = prefs.getString(lecturerKey);
        
        if (userDataString != null) {
          final userData = json.decode(userDataString) as Map<String, dynamic>;
          setState(() {
            _lectureNumber = lectureNumber;
            _lecturerName = userData['name'];
            _department = userData['department'];
            _occupation = userData['occupation'];
            _employmentType = userData['employmentType'];
            _gender = userData['gender'];
          });
        } else {
          // Fallback to individual keys if combined data doesn't exist
          setState(() {
            _lectureNumber = lectureNumber;
            _lecturerName = prefs.getString('lecturer_name_$lectureNumber');
            _department = prefs.getString('lecturer_department_$lectureNumber');
            _occupation = prefs.getString('lecturer_occupation_$lectureNumber');
            _employmentType = prefs.getString('lecturer_employment_type_$lectureNumber');
            _gender = prefs.getString('lecturer_gender_$lectureNumber');
          });
        }
      }
    } catch (e) {
      print('Error loading lecturer data: $e');
    }
  }

  // Show logout confirmation dialog
  void _showLogoutConfirmationDialog() {
    final dialogBackgroundColor = _isDarkMode ? Color(0xFF1F2937) : Colors.white;
    final dialogTextColor = _isDarkMode ? Colors.white : Colors.black87;
    final buttonTextColor = _isDarkMode ? Colors.lightBlue : Colors.blue;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: dialogBackgroundColor,
          title: Text(
            'Confirm Sign Out',
            style: TextStyle(color: dialogTextColor),
          ),
          content: Text(
            'Are you sure you want to sign out? This will clear all your session data.',
            style: TextStyle(color: dialogTextColor.withOpacity(0.9)),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: buttonTextColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Sign Out',
                style: TextStyle(color: _isDarkMode ? Colors.red[300] : Colors.red),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _clearUserData();
                Navigator.pushReplacementNamed(context, '/role-selection');
              },
            ),
          ],
        );
      },
    );
  }

  // Method to clear user data from SharedPreferences
  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userLectureNumber = _lectureNumber ?? prefs.getString('current_lecture_number');
      
      if (userLectureNumber != null) {
        // Remove profile image
        final imagePath = prefs.getString('profile_image_path_$userLectureNumber');
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) {
            await file.delete();
          }
          await prefs.remove('profile_image_path_$userLectureNumber');
        }
        
        // Remove all lecturer-specific data
        await prefs.remove('lecturer_data_$userLectureNumber');
        await prefs.remove('lecturer_name_$userLectureNumber');
        await prefs.remove('lecturer_department_$userLectureNumber');
        await prefs.remove('lecturer_occupation_$userLectureNumber');
        await prefs.remove('lecturer_employment_type_$userLectureNumber');
        await prefs.remove('lecturer_gender_$userLectureNumber');
      }
      
      // Clear current session data
      await prefs.remove('current_lecture_number');
      await prefs.remove('isLoggedIn');
      await prefs.remove('user_type');
      
      print('Lecturer data cleared for $userLectureNumber');
    } catch (e) {
      print('Error clearing lecturer data: $e');
    }
  }

  Future<bool> _onWillPop() async {
    final dialogBackgroundColor = _isDarkMode ? Color(0xFF1F2937) : Colors.white;
    final dialogTextColor = _isDarkMode ? Colors.white : Colors.black87;
    final accentColor = _isDarkMode ? Colors.pink[300] : Colors.pink[200];
    
    bool shouldPop = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBackgroundColor,
        title: Text(
          'Leaving so soon?',
          style: TextStyle(color: dialogTextColor),
        ),
        content: Text(
          'Have you finished exploring the app? You\'re welcome back any time.',
          style: TextStyle(color: dialogTextColor.withOpacity(0.8)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'I\'m still exploring',
              style: TextStyle(color: accentColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              Navigator.pushReplacementNamed(context, '/role-selection');
            },
            child: Text(
              'I\'d like to leave',
              style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
    
    return shouldPop;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue; // Always use blue for primary color
    final backgroundColor = _isDarkMode ? Color(0xFF111827) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lecturer Dashboard'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        drawer: _buildDrawer(),
        backgroundColor: backgroundColor,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.blue, // Always blue regardless of theme
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile picture with online indicator
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white,
                              backgroundImage: _profileImage != null 
                                ? FileImage(_profileImage!) 
                                : null,
                              child: _profileImage == null 
                                ? Icon(Icons.person, size: 30, color: Colors.blue) 
                                : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  height: 8,
                                  width: 8,
                                  decoration: BoxDecoration(
                                    color: _isOnline ? Colors.green : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 12),
                        
                        // Greeting and name section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${_getGreeting()},',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    ' 👋',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${_lecturerName ?? ''}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Lecturer details with more efficient space usage and layout
                    Padding(
                      padding: EdgeInsets.only(right: 0), // Remove right padding to allow full width
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Department with text wrapping support
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 15, // Slightly larger
                                color: Colors.white,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Department: ',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text: _department ?? 'Not set',
                                ),
                              ],
                            ),
                            overflow: TextOverflow.visible,
                          ),
                          SizedBox(height: 2), // Reduced spacing
                          
                          // Gender
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 15, // Slightly larger
                                color: Colors.white,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Gender: ',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text: _gender ?? 'Not set',
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 2), // Reduced spacing
                          
                          // Occupation
                          RichText(
                            text: TextSpan(
                      style: TextStyle(
                                fontSize: 15, // Slightly larger
                        color: Colors.white,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Occupation: ',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text: _occupation ?? 'Not set',
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 2), // Reduced spacing
                          
                          // Employment Type
                          RichText(
                            text: TextSpan(
                      style: TextStyle(
                                fontSize: 15, // Slightly larger
                        color: Colors.white,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Employment Type: ',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text: _employmentType ?? 'Not set',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Time and date with location side by side - fixed layout to prevent overflow
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          // Location display in a rectangle box
                          Expanded(
                            flex: 3,
                            child: Container(
                              margin: EdgeInsets.only(right: 8),
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withOpacity(0.1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _currentLocation,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _getCurrentLocation,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.refresh, color: Colors.white, size: 14),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                          
                          // Time and date box
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentTime,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _currentDate,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main Dashboard Content
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color: _isDarkMode ? Color(0xFF1E293B) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Management Section
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                      child: Text(
                        'Class Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.1,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildMenuItem(
                          icon: Icons.qr_code_2,
                          title: 'Create QR Code',
                          color: Colors.blue,
                          route: AppRoutes.createPage,
                        ),
                        _buildMenuItem(
                          icon: Icons.edit,
                          title: 'Manual Entry',
                          color: Colors.orange,
                          route: AppRoutes.manualEntryPage,
                        ),
                        _buildMenuItem(
                          icon: Icons.people,
                          title: 'Attendees Logs',
                          color: Colors.green,
                          route: AppRoutes.historyPage,
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Teaching Info Section
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                      child: Text(
                        'Teaching Info',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.1,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildMenuItem(
                          icon: Icons.book,
                          title: 'Get Assigned Units',
                          color: Colors.blue,
                          route: AppRoutes.getAssignedUnitsPage,
                        ),
                        _buildMenuItem(
                          icon: Icons.calendar_today,
                          title: 'Schedules',
                          color: Colors.red,
                          route: AppRoutes.lecturerSchedulesPage,
                        ),
                        _buildMenuItem(
                          icon: Icons.notifications,
                          title: 'Notifications & Alerts',
                          color: Colors.amber,
                          route: AppRoutes.lecturerNotificationsPage,
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Evaluation Section
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                      child: Text(
                        'Evaluation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.1,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildMenuItem(
                          icon: Icons.check_circle,
                          title: 'Enter CAT Marks',
                          color: Colors.green,
                          route: AppRoutes.catMarksEntryPage,
                        ),
                      ],
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

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.7,
      child: Container(
        color: Color(0xFF0A192F),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                color: Color(0xFF172A45),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: _profileImage != null 
                            ? FileImage(_profileImage!) 
                            : null,
                          child: _profileImage == null 
                            ? Icon(Icons.person, size: 30, color: Color(0xFF0A192F)) 
                            : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
        ),
        child: Container(
                              height: 14,
                              width: 14,
                              decoration: BoxDecoration(
                                color: _isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lecturerName ?? 'Lecturer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _lectureNumber ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
          decoration: BoxDecoration(
                                  color: _isOnline ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                _isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: _isOnline ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.2), height: 1, thickness: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.person,
                      title: 'Update Profile Picture',
                      onTap: () {
                        _pickProfileImage();
                        Navigator.pop(context);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.schedule,
                      title: 'Class Timetable',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.viewPage,
                          arguments: {
                            'email': _lectureNumber,
                            'name': _lecturerName,
                            'department': _department,
                            'course': _department,
                            'year': '',
                            'semester': '',
                            'lectureNumber': _lectureNumber,
                            'occupation': _occupation,
                            'employmentType': _employmentType,
                            'gender': _gender,
                          }
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.update,
                      title: 'Update Details',
                      onTap: () async {
                        Navigator.pop(context);
                        final result = await Navigator.pushNamed(
                          context,
                          AppRoutes.updateLecturerDetails,
                          arguments: {
                            'email': _lectureNumber, // For backward compatibility
                            'lectureNumber': _lectureNumber,
                            'name': _lecturerName,
                            'department': _department,
                            'occupation': _occupation,
                            'employmentType': _employmentType,
                            'gender': _gender,
                          }
                        );
                        
                        if (result != null && result is Map<String, dynamic> && result['updated'] == true) {
                          _refreshAllData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    _buildDarkModeToggle(),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.2), height: 1, thickness: 1),
              _buildDrawerItem(
                icon: Icons.exit_to_app,
                title: 'Sign out',
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutConfirmationDialog();
                },
                showDivider: false,
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Check location before navigating
          _checkLocationBeforeNavigating(() {
            // Use the original route constants and parameter format to ensure compatibility
            if (route == AppRoutes.createPage) {
              Navigator.pushNamed(context, route, arguments: {
                'email': _lectureNumber, // For backward compatibility
                'lectureNumber': _lectureNumber,
                'name': _lecturerName,
                'department': _department,
                'occupation': _occupation,
                'employmentType': _employmentType,
                'gender': _gender,
              });
            } else if (route == AppRoutes.historyPage) {
              Navigator.pushNamed(context, route, arguments: {
                'email': _lectureNumber, // For backward compatibility
                'lectureNumber': _lectureNumber,
                'name': _lecturerName,
                'department': _department,
                'occupation': _occupation,
                'employmentType': _employmentType,
                'gender': _gender,
              });
            } else {
              Navigator.pushNamed(
                context,
                route,
                arguments: {
                  'email': _lectureNumber, // For backward compatibility
                  'lectureNumber': _lectureNumber,
                  'name': _lecturerName,
                  'department': _department,
                  'occupation': _occupation,
                  'employmentType': _employmentType,
                  'gender': _gender,
                },
              );
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              title, 
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to check location before navigation
  void _checkLocationBeforeNavigating(VoidCallback onLocationAvailable) async {
    // Show loading dialog to indicate we're getting location
    bool showLoading = _currentPosition == null || _currentLocation == "Getting location..." || _currentLocation == "Waiting for network..." || _currentLocation == "Tap to retry" || _currentLocation == "Location unavailable";
    
    if (showLoading) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Please Wait'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Determining your location...\nThis is required to continue.'),
            ],
          ),
        ),
      );
    }
    
    // Check if location services are enabled
    bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationEnabled) {
      if (showLoading) Navigator.pop(context); // Dismiss loading dialog
      _showEnableLocationDialog();
      return;
    }
    
    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (showLoading) Navigator.pop(context); // Dismiss loading dialog
      _showLocationPermissionRequiredDialog();
      return;
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (showLoading) Navigator.pop(context); // Dismiss loading dialog
      _showPermanentlyDeniedLocationDialog();
      return;
    }
    
    // If not online, show dialog
    if (!_isOnline) {
      if (showLoading) Navigator.pop(context); // Dismiss loading dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Network Required'),
          content: Text('Internet connection is required to verify your location. Please connect to a network and try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    // If we don't have a current position yet, try to get one
    if (_currentPosition == null || _currentLocation == "Getting location..." || 
        _currentLocation == "Waiting for network..." || _currentLocation == "Tap to retry" || 
        _currentLocation == "Location unavailable") {
      
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        );
        
        setState(() {
          _currentPosition = position;
        });
        
        // Get address from coordinates - wait for this to complete
        await _getAddressFromCoordinates(position);
        
        // Now check if we have a valid location
        if (_currentLocation == "Getting location..." || 
            _currentLocation == "Waiting for network..." || 
            _currentLocation == "Tap to retry" || 
            _currentLocation == "Location unavailable") {
          if (showLoading) Navigator.pop(context); // Dismiss loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to determine your location. Please try again later.'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
        
        // We have a valid location, dismiss dialog and proceed
        if (showLoading) Navigator.pop(context); // Dismiss loading dialog
        onLocationAvailable();
        
      } catch (e) {
        print("Error getting location before navigation: $e");
        if (showLoading) Navigator.pop(context); // Dismiss loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location is required to continue. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // We already have a location, proceed
      if (showLoading) Navigator.pop(context); // Dismiss loading dialog in case it was showing
      onLocationAvailable();
    }
  }

  // Update drawer navigation too
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListTile(
            dense: false,
            horizontalTitleGap: 16,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(
              icon, 
              color: Colors.white, 
              size: 24
            ),
            title: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            onTap: () {
              if (title == 'Update Profile Picture' || title == 'Sign out' || title == 'Dark Mode') {
                // These don't need location check
                onTap();
              } else {
                // Check location before navigating for other items
                _checkLocationBeforeNavigating(onTap);
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            tileColor: Colors.white.withOpacity(0.05),
            hoverColor: Colors.blue.withOpacity(0.2),
            splashColor: Colors.blue.withOpacity(0.3),
          ),
        ),
        if (showDivider)
          SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDarkModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          color: Colors.white.withOpacity(0.05),
        ),
        child: SwitchListTile(
          dense: false,
          title: Text(
            'Dark Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          value: _isDarkMode,
          onChanged: (value) {
            setState(() {
              _isDarkMode = value;
            });
            _saveDarkModePreference(value);
          },
          activeColor: Colors.blue,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          secondary: Icon(
            _isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Unregister the observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel timers
    _clockTimer?.cancel();
    
    // Cancel connectivity subscription
    _connectivitySubscription.cancel();
    
    super.dispose();
  }

  // Load profile image
  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userLectureNumber = _lectureNumber ?? prefs.getString('current_lecture_number');
      
      if (userLectureNumber != null) {
        final imagePath = prefs.getString('profile_image_path_$userLectureNumber');
        
        if (imagePath != null && userLectureNumber == _lectureNumber) {
          final file = File(imagePath);
          if (await file.exists()) {
            setState(() {
              _profileImage = file;
            });
            print('Loaded profile image from: $imagePath for $userLectureNumber');
          } else {
            print('Profile image file does not exist: $imagePath');
            setState(() {
              _profileImage = null;
            });
          }
        } else {
          print('No profile image path found for lecturer: $userLectureNumber');
          setState(() {
            _profileImage = null;
          });
        }
      } else {
        print('Cannot load profile image: lecture number is null');
        setState(() {
          _profileImage = null;
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
      setState(() {
        _profileImage = null;
      });
    }
  }

  // Save profile image
  Future<void> _saveProfileImagePath(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userLectureNumber = _lectureNumber ?? prefs.getString('current_lecture_number');
      
      if (userLectureNumber != null) {
        await prefs.setString('profile_image_path_$userLectureNumber', path);
        print('Saved profile image path for $userLectureNumber: $path');
      } else {
        print('Cannot save profile image path: lecture number is null');
      }
    } catch (e) {
      print('Error saving profile image path: $e');
    }
  }

  // Pick and update profile image
  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80
      );
      
      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        final userLectureNumber = _lectureNumber ?? prefs.getString('current_lecture_number');
        
        if (userLectureNumber == null || userLectureNumber.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: User not logged in properly'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/profile_images';
        
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final sanitizedLectureNumber = userLectureNumber.replaceAll(RegExp(r'[^\w\s\.]'), '_');
        final profileImagePath = '$path/profile_${sanitizedLectureNumber}_$timestamp.jpg';
        
        try {
          final oldImagePath = prefs.getString('profile_image_path_$userLectureNumber');
          if (oldImagePath != null) {
            final oldFile = File(oldImagePath);
            if (await oldFile.exists()) {
              await oldFile.delete();
              print('Deleted old profile image: $oldImagePath');
            }
          }
        } catch (e) {
          print('Error deleting old profile image: $e');
        }
        
        await File(pickedFile.path).copy(profileImagePath);
        
        final savedFile = File(profileImagePath);
        setState(() {
          _profileImage = savedFile;
        });
        
        await _saveProfileImagePath(profileImagePath);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully for $userLectureNumber'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error picking profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Check internet connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('Error checking connectivity: $e');
    }
  }

  // Update connectivity status
  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOffline = !_isOnline;
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
    
    // If we were offline but now we're online, refresh the location
    if (wasOffline && _isOnline) {
      print('Connectivity restored, refreshing location...');
      _getCurrentLocation();
    }
  }

  // Get greeting based on time of day
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 4) {
      return 'Good night';
    } else if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else if (hour < 19) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  // Update current time and date
  void _updateTime() {
    final now = DateTime.now();
    // Format as HH:MM:SS
    final timeFormat = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    // Format as DD/MM/YYYY
    final dateFormat = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    
    setState(() {
      _currentTime = timeFormat;
      _currentDate = dateFormat;
    });
  }

  // Location methods
  Future<void> _initializeLocation() async {
    try {
      // First check if location services are enabled at system level
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        // Show dialog to force location enabling
        _showEnableLocationDialog();
        return;
      }
      
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Show dialog to force permission
          _showLocationPermissionRequiredDialog();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        // Show dialog that app cannot work without permission
        _showPermanentlyDeniedLocationDialog();
        return;
      }
      
      // If we're here, we have permission, so get location
      _getCurrentLocation();
    } catch (e) {
      print('Error initializing location: $e');
    }
  }
  
  void _showEnableLocationDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Required'),
          content: Text('This app requires location services to function. Please enable location services to continue.'),
          actions: <Widget>[
            TextButton(
              child: Text('Enable Location'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
                
                // Check again after settings are opened
                Future.delayed(Duration(seconds: 3), () {
                  _initializeLocation();
                });
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showLocationPermissionRequiredDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Required'),
          content: Text('This app needs location permission to function properly. Please grant location permission to continue.'),
          actions: <Widget>[
            TextButton(
              child: Text('Request Permission'),
              onPressed: () async {
                Navigator.of(context).pop();
                LocationPermission permission = await Geolocator.requestPermission();
                if (permission == LocationPermission.denied || 
                    permission == LocationPermission.deniedForever) {
                  _showLocationPermissionRequiredDialog();
                } else {
                  _getCurrentLocation();
                }
              },
            ),
          ],
        );
      },
    );
  }
  
  void _showPermanentlyDeniedLocationDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Denied'),
          content: Text('Location permission is permanently denied. Please enable it in app settings to use this app.'),
          actions: <Widget>[
            TextButton(
              child: Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
                
                // Check again after settings are opened
                Future.delayed(Duration(seconds: 3), () {
                  _initializeLocation();
                });
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _currentLocation = "Getting location...";
      });
      
      // If we're offline, update the UI accordingly
      if (!_isOnline) {
        setState(() {
          _currentLocation = "Waiting for network...";
        });
        return;
      }
      
      // Check location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showEnableLocationDialog();
        return;
      }
      
      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _showLocationPermissionRequiredDialog();
        return;
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showPermanentlyDeniedLocationDialog();
        return;
      }
      
      // Get the current position with retry mechanism
      Position? position;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (position == null && retryCount < maxRetries) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          );
        } catch (e) {
          retryCount++;
          print('Retry $retryCount: Error getting location: $e');
          
          if (retryCount >= maxRetries) {
            throw e; // Re-throw after max retries
          }
          
          // Wait before retrying
          await Future.delayed(Duration(seconds: 1));
        }
      }
      
      if (position == null) {
        throw Exception('Failed to get location after $maxRetries retries');
      }
      
      setState(() {
        _currentPosition = position;
      });
      
      // Get address from coordinates
      await _getAddressFromCoordinates(position);
      
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        if (!_isOnline) {
          _currentLocation = "Waiting for network...";
        } else {
          _currentLocation = "Tap to retry";
        }
      });
    }
  }
  
  Future<void> _getAddressFromCoordinates(Position position) async {
    try {
      if (!_isOnline) {
        setState(() {
          _currentLocation = "Waiting for network...";
        });
        return;
      }
      
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks.first;
      
      String locationName;
      if (place.locality != null && place.locality!.isNotEmpty) {
        locationName = place.locality!;
      } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
        locationName = place.subAdministrativeArea!;
      } else if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
        locationName = place.administrativeArea!;
      } else {
        locationName = "Unknown Location";
      }
      
      // Add more detailed region information if available
      if (place.administrativeArea != null && 
          place.administrativeArea!.isNotEmpty && 
          place.administrativeArea! != locationName) {
        locationName = "$locationName-${place.administrativeArea!}";
      }
      
      if (locationName.length > 20) {
        // Ensure it doesn't get too long and cause overflow
        locationName = locationName.substring(0, 18) + "..";
      }
      
      setState(() {
        _currentLocation = locationName;
      });
    } catch (e) {
      print('Error getting address from coordinates: $e');
      
      // Better fallback message based on connectivity
      setState(() {
        if (!_isOnline) {
          _currentLocation = "Waiting for network...";
        } else {
          _currentLocation = "Location unavailable";
        }
      });
    }
  }
} 
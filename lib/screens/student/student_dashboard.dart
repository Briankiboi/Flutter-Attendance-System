import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with WidgetsBindingObserver {
  String? _email;
  String? _studentName;
  String? _department;
  String? _course;
  String? _year;
  String? _semester;
  
  // Profile picture variables
  File? _profileImage;
  
  // Internet connectivity tracking
  bool _isOnline = true;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  // Dark mode state
  bool _isDarkMode = false;
  
  // New QR notification state
  bool _hasNewQR = false;
  Timer? _qrCheckTimer;
  
  // New notification state
  bool _hasNewNotifications = false; // Default to false - no notifications

  // Current time and date variables
  String _currentTime = "";
  String _currentDate = "";
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    
    // Register this object as an observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    // Always load user data from SharedPreferences on startup
    _loadUserData();
    _loadProfileImage();
    _loadDarkModePreference();
    _checkForNewQRCode();
    _checkForNewNotifications();
    
    // Initialize connectivity status
    _checkConnectivity();
    
    // Setup connectivity listener to update status in real-time
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionStatus(result);
    });
    
    // Periodically check for new QR codes
    _qrCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkForNewQRCode();
        _checkForNewNotifications();
      }
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
    // When app resumes from background, refresh all data
    if (state == AppLifecycleState.resumed) {
      _refreshAllData();
    }
  }

  void _refreshAllData() {
    if (mounted) {
      print('Refreshing all dashboard data...');
      _loadUserData();
      _loadProfileImage();
      _checkForNewQRCode();
      _checkForNewNotifications();
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
        _email = args['email'];
        _studentName = args['name'];
        _department = args['department'];
        _course = args['course'];
        _year = args['year']; 
        _semester = args['semester'];
      });
      
      // Store this data in SharedPreferences to make sure it's available
      _saveCurrentUserData(args);
      
      // Reload profile image in case it was updated
      _loadProfileImage();
    } else {
      // Even if no args were provided, refresh data from SharedPreferences
      // This ensures dashboard is updated after returning from update details
      _loadUserData();
      _loadProfileImage();
    }
  }

  Future<void> _saveCurrentUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = userData['email'] ?? '';
      
      // Save the data tied to the specific user
      await prefs.setString('current_user_email', email);
      await prefs.setString('user_name_$email', userData['name'] ?? '');
      await prefs.setString('user_department_$email', userData['department'] ?? '');
      await prefs.setString('user_course_$email', userData['course'] ?? '');
      await prefs.setString('user_year_$email', userData['year'] ?? '');
      await prefs.setString('user_semester_$email', userData['semester'] ?? '');
      
      // Also save as the current user
      await prefs.setString('current_user_email', email);
      await prefs.setString('current_user_name', userData['name'] ?? '');
      await prefs.setString('current_user_department', userData['department'] ?? '');
      await prefs.setString('current_user_course', userData['course'] ?? '');
      await prefs.setString('current_user_year', userData['year'] ?? '');
      await prefs.setString('current_user_semester', userData['semester'] ?? '');
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('current_user_email');
      
      if (email != null && email.isNotEmpty) {
        // Get the full user data from the main data store
        final userDataString = prefs.getString(email);
        
        if (userDataString != null) {
          // If we have the complete user data, use it
          final userData = json.decode(userDataString) as Map<String, dynamic>;
          setState(() {
            _email = email;
            _studentName = userData['name'];
            _department = userData['department'];
            _course = userData['course'];
            _year = userData['year'];
            _semester = userData['semester'];
          });
          print('Loaded complete user data for dashboard: Name=$_studentName, Year=$_year, Semester=$_semester');
        } else {
          // Fall back to the individual preference keys
          setState(() {
            _email = email;
            _studentName = prefs.getString('user_name_$email') ?? prefs.getString('current_user_name');
            _department = prefs.getString('user_department_$email') ?? prefs.getString('current_user_department');
            _course = prefs.getString('user_course_$email') ?? prefs.getString('current_user_course');
            _year = prefs.getString('user_year_$email') ?? prefs.getString('current_user_year');
            _semester = prefs.getString('user_semester_$email') ?? prefs.getString('current_user_semester');
          });
          print('Loaded backup user data for dashboard: Name=$_studentName, Year=$_year, Semester=$_semester');
        }
      } else {
        setState(() {
          _email = prefs.getString('current_user_email');
          _studentName = prefs.getString('current_user_name');
          _department = prefs.getString('current_user_department');
          _course = prefs.getString('current_user_course');
          _year = prefs.getString('current_user_year');
          _semester = prefs.getString('current_user_semester');
        });
        print('Loaded fallback user data for dashboard: Name=$_studentName');
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Load profile image
  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = _email ?? prefs.getString('current_user_email');
      
      if (userEmail != null) {
        final imagePath = prefs.getString('profile_image_path_$userEmail');
        
        // Ensure we're only loading the image for the current user email
        if (imagePath != null && userEmail == _email) {
          final file = File(imagePath);
          if (await file.exists()) {
            setState(() {
              _profileImage = file;
            });
            print('Loaded profile image from: $imagePath for $userEmail');
          } else {
            print('Profile image file does not exist: $imagePath');
            setState(() {
              _profileImage = null; // Clear any existing image
            });
          }
        } else {
          print('No profile image path found for user: $userEmail');
          setState(() {
            _profileImage = null; // Clear any existing image
          });
        }
      } else {
        print('Cannot load profile image: user email is null');
        setState(() {
          _profileImage = null; // Clear any existing image
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
      setState(() {
        _profileImage = null; // Clear any existing image on error
      });
    }
  }

  // Save profile image
  Future<void> _saveProfileImagePath(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = _email ?? prefs.getString('current_user_email');
      
      if (userEmail != null) {
        await prefs.setString('profile_image_path_$userEmail', path);
        print('Saved profile image path for $userEmail: $path');
      } else {
        print('Cannot save profile image path: user email is null');
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
        imageQuality: 80 // Compress for better performance
      );
      
      if (pickedFile != null) {
        // Get the current user email to ensure we're saving to the right profile
        final prefs = await SharedPreferences.getInstance();
        final userEmail = _email ?? prefs.getString('current_user_email');
        
        if (userEmail == null || userEmail.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: User not logged in properly'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        // Create a copy of the image in app's documents directory
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/profile_images';
        
        // Create directory if it doesn't exist
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        // Generate a unique filename with timestamp to avoid cache issues
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final sanitizedEmail = userEmail.replaceAll(RegExp(r'[^\w\s\.]'), '_');
        final profileImagePath = '$path/profile_${sanitizedEmail}_$timestamp.jpg';
        
        // First, remove any old profile images for this user to save space
        try {
          final oldImagePath = prefs.getString('profile_image_path_$userEmail');
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
        
        // Copy the file to our app's storage
        await File(pickedFile.path).copy(profileImagePath);
        
        // Update the UI
        final savedFile = File(profileImagePath);
        setState(() {
          _profileImage = savedFile;
        });
        
        // Save image path to SharedPreferences with user-specific key
        await _saveProfileImagePath(profileImagePath);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully for $userEmail'),
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
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
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
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text(
                'Sign Out',
                style: TextStyle(color: _isDarkMode ? Colors.red[300] : Colors.red),
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                
                // Clear user data from SharedPreferences
                await _clearUserData();
                
                // Navigate to role selection screen
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
      final userEmail = _email ?? prefs.getString('current_user_email');
      
      // Don't clear profile images of other users
      if (userEmail != null) {
        // Only remove profile data for the current user
        final imagePath = prefs.getString('profile_image_path_$userEmail');
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) {
            await file.delete();
          }
          await prefs.remove('profile_image_path_$userEmail');
        }
        
        // Clear user-specific preference data
        await prefs.remove('user_name_$userEmail');
        await prefs.remove('user_department_$userEmail');
        await prefs.remove('user_course_$userEmail');
        await prefs.remove('user_year_$userEmail');
        await prefs.remove('user_semester_$userEmail');
      }
      
      // Clear current user data
      await prefs.remove('current_user_email');
      await prefs.remove('current_user_name');
      await prefs.remove('current_user_department');
      await prefs.remove('current_user_course');
      await prefs.remove('current_user_year');
      await prefs.remove('current_user_semester');
      
      // Clear login state
      await prefs.remove('isLoggedIn');
      await prefs.remove('user_id');
      await prefs.remove('user_type');
      
      print('User data cleared for $userEmail');
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  Future<bool> _onWillPop() async {
    // Get theme colors based on dark mode setting
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
              // Navigate to role selection screen without deleting user data
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

  // Build dark mode toggle widget
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
  
  // Check for new QR codes
  Future<void> _checkForNewQRCode() async {
    try {
      if (_email == null) {
        setState(() {
          _hasNewQR = false;
        });
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // First check if the user recently marked attendance
      final lastAttendanceTimesStr = prefs.getString('last_attendance_times');
      if (lastAttendanceTimesStr != null) {
        final Map<String, dynamic> decodedTimes = json.decode(lastAttendanceTimesStr);
        if (decodedTimes.containsKey(_email)) {
          final lastAttendance = DateTime.parse(decodedTimes[_email]);
          // If marked attendance in last 5 minutes, don't show notification
          if (DateTime.now().difference(lastAttendance).inMinutes < 5) {
            setState(() {
              _hasNewQR = false;
            });
            return;
          }
        }
      }
      
      List<String> activeSessions = prefs.getStringList('active_sessions') ?? [];
      
      if (activeSessions.isEmpty) {
        setState(() {
          _hasNewQR = false;
        });
        return;
      }
      
      // Check if there are any unattended sessions for this student
      bool hasUnattendedSession = false;
      for (String sessionId in activeSessions) {
        // Check if this student has already marked attendance for this session
        bool alreadyAttended = prefs.getBool('attended_session_${_email}_$sessionId') ?? false;
        if (alreadyAttended) {
          continue; // Skip this session if already attended
        }
        
        // Check if session is relevant to student
        String? sessionDataString = prefs.getString('session_$sessionId');
        if (sessionDataString != null) {
          final sessionData = json.decode(sessionDataString);
          
          // Check session timestamp to see if it's still active
          dynamic timestampValue = sessionData['timestamp'];
          DateTime? timestamp;
          if (timestampValue != null) {
            if (timestampValue is int) {
              timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue);
            } else if (timestampValue is String) {
              timestamp = DateTime.tryParse(timestampValue);
            }
          }
          
          // Skip if session is older than 1 hour
          if (timestamp != null && DateTime.now().difference(timestamp).inHours > 1) {
            continue;
          }
          
          // Check if session is for this student's course/year/semester
          final String? sessionCourse = sessionData['course']?.toString();
          final String? sessionYear = sessionData['year']?.toString();
          final String? sessionSemester = sessionData['semester']?.toString();
          
          bool isRelevant = true;
          if (sessionCourse != null && sessionCourse.isNotEmpty && sessionCourse != _course) {
            isRelevant = false;
          }
          if (sessionYear != null && sessionYear.isNotEmpty && sessionYear != _year) {
            isRelevant = false;
          }
          if (sessionSemester != null && sessionSemester.isNotEmpty && sessionSemester != _semester) {
            isRelevant = false;
          }
          
          if (isRelevant) {
            print('Found relevant active QR session: $sessionId');
            hasUnattendedSession = true;
            break;
          }
        }
      }
      
      setState(() {
        _hasNewQR = hasUnattendedSession;
      });
      
      print('QR notification status: ${_hasNewQR ? 'SHOWING' : 'HIDDEN'}');
    } catch (e) {
      print('Error checking for new QR codes: $e');
      // On error, don't show notification
      setState(() {
        _hasNewQR = false;
      });
    }
  }

  // Check for new notifications
  Future<void> _checkForNewNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Logic to check for new notifications would go here
      // For now, we'll set it to false until actual notification checking is implemented
      
      // Example of how real notification checking would work:
      // final unreadNotifications = prefs.getStringList('unread_notifications') ?? [];
      // setState(() {
      //   _hasNewNotifications = unreadNotifications.isNotEmpty;
      // });
      
      setState(() {
        _hasNewNotifications = false; // Only set to true when actual notifications exist
      });
    } catch (e) {
      print('Error checking for new notifications: $e');
      setState(() {
        _hasNewNotifications = false; // Default to no notifications on error
      });
    }
  }

  // Update current time and date
  void _updateTime() {
    final now = DateTime.now();
    final timeFormat = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final dateFormat = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    
    setState(() {
      _currentTime = timeFormat;
      _currentDate = dateFormat;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Define colors based on dark mode state
    final primaryColor = _isDarkMode ? Color(0xFF1F2937) : Colors.blue;
    final backgroundColor = _isDarkMode ? Color(0xFF111827) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = _isDarkMode ? Colors.white70 : Colors.black54;
    final cardColor = _isDarkMode ? Color(0xFF374151) : Colors.white;
    final dividerColor = _isDarkMode ? Colors.white24 : Colors.grey.shade300;
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Dashboard'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          actions: [
            // Notification bell in AppBar
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, '/notifications', arguments: {
                      'email': _email,
                      'name': _studentName,
                      'department': _department,
                      'course': _course,
                      'year': _year,
                      'semester': _semester,
                    });
                  },
                ),
                if (_hasNewNotifications)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 8),
          ],
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
                color: primaryColor,
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
                  // User greeting and profile picture
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile Picture with online indicator
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            backgroundImage: _profileImage != null 
                              ? FileImage(_profileImage!) 
                              : null,
                            child: _profileImage == null 
                              ? Icon(Icons.person, size: 30, color: primaryColor) 
                              : null,
                          ),
                          // Online indicator dot
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
                      // Greeting and name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()},',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_studentName ?? 'Student'} 👋',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                // Time display
                                Text(
                                  _currentTime,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Move date directly under the name/time row, right-aligned
                  Container(
                    width: double.infinity,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 0, top: 2),
                    child: Text(
                      _currentDate,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 6),
                  
                  // User Information (moved up)
                  Text(
                    '${_department ?? 'Department'} - ${_course ?? 'Course'}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Year ${_year ?? '?'}, Semester ${_semester ?? '?'}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
              // Academic Tools Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color: _isDarkMode ? Color(0xFF1E293B) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                      child: Text(
                        'Academic Tools',
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
                      children: [
                        _buildMenuItem(
                          icon: Icons.qr_code_scanner,
                          title: 'Scan QR',
                          color: Colors.blue,
                          route: '/scan-qr',
                          showNotification: _hasNewQR,
                        ),
                        _buildMenuItem(
                          icon: Icons.library_add_check,
                          title: 'Register Units',
                          color: Colors.red,
                          route: '/register-units',
                        ),
                        _buildMenuItem(
                          icon: Icons.analytics,
                          title: 'Results for CAT',
                          color: Colors.purple,
                          route: '/results-cat',
                        ),
                        _buildMenuItem(
                          icon: Icons.description,
                          title: 'Past Papers',
                          color: Colors.green,
                          route: '/past-papers',
                        ),
                        _buildMenuItem(
                          icon: Icons.rate_review,
                          title: 'Evaluate Lecture',
                          color: Colors.amber,
                          route: '/evaluate-lecture',
                        ),
                        _buildMenuItem(
                          icon: Icons.card_membership,
                          title: 'Exam Card Download',
                          color: Colors.teal,
                          route: '/exam-card',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Timetables & Alerts Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color: _isDarkMode ? Color(0xFF1E293B) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                      child: Text(
                        'Timetables & Alerts',
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
                      children: [
                        _buildMenuItem(
                          icon: Icons.calendar_today,
                          title: 'Schedules',
                          color: Colors.blue,
                          route: '/schedules',
                        ),
                        _buildMenuItem(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          color: Colors.red,
                          route: '/notifications',
                          showNotification: _hasNewNotifications,
                        ),
                        _buildMenuItem(
                          icon: Icons.trending_up,
                          title: 'Trends',
                          color: Colors.orange,
                          route: '/trends',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Communication Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color: _isDarkMode ? Color(0xFF1E293B) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                      child: Text(
                        'Communication',
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
                      children: [
                        _buildMenuItem(
                          icon: Icons.chat,
                          title: 'Get in Touch',
                          color: Colors.green,
                          route: '/get-in-touch',
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required String route,
    bool showNotification = false,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, route, arguments: {
            'email': _email,
            'name': _studentName,
            'department': _department,
            'course': _course,
            'year': _year,
            'semester': _semester,
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                if (showNotification)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
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

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.7, // 70% of screen width
      child: Container(
        color: Color(0xFF0A192F), // Deeper blue for a more professional look
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                color: Color(0xFF172A45), // Professional header color
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
                            _studentName ?? 'Student',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _email ?? '',
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
                        Navigator.pushNamed(context, '/student-timetable');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.update,
                      title: 'Update Details',
                      onTap: () async {
                        Navigator.pop(context);
                        final result = await Navigator.pushNamed(context, '/update-details');
                        
                        // Check if we received data back from the update screen
                        if (result != null && result is Map<String, dynamic> && result['updated'] == true) {
                          // Force complete refresh of all user data
                          _refreshAllData();
                          
                          // Show a confirmation toast
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Profile updated successfully'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    // Add Dark Mode toggle
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
              SizedBox(height: 20), // Add bottom padding to avoid overflow
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build consistent drawer items
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
            dense: false, // Give more space for better visibility
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
            onTap: onTap,
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

  @override
  void dispose() {
    // Unsubscribe from connectivity changes
    _connectivitySubscription.cancel();
    
    // Cancel the QR check timer
    _qrCheckTimer?.cancel();
    
    // Cancel the clock timer
    _clockTimer?.cancel();
    
    // Remove this object as an observer for app lifecycle events
    WidgetsBinding.instance.removeObserver(this);
    
    super.dispose();
  }
} 
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:qr_attendance/screens/student/scan_qr_page.dart';
import 'package:qr_attendance/screens/student/student_timetable_page.dart';
import 'package:qr_attendance/screens/student/update_details_page.dart';
import 'package:qr_attendance/screens/student/view_page.dart';
import 'package:qr_attendance/services/supabase_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

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
  
  // Add loading state
  bool _isLoading = true;
  
  // Profile picture variables
  File? _profileImage;
  String? _profileImagePath;
  bool _isAvatarLoading = false;
  
  // Internet connectivity tracking
  bool _isOnline = true;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  
  // Dark mode state
  bool _isDarkMode = false;
  
  // New QR notification state
  bool _hasNewQR = false;
  Timer? _qrCheckTimer;
  
  // New notification state
  bool _hasNewNotifications = false;

  // Location variables
  String _currentLocation = "Fetching location...";
  Position? _currentPosition;
  bool _locationServiceEnabled = false;
  LocationPermission? _permissionStatus;

  // Service for Supabase
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _setupConnectivityListener();
    _loadDarkModePreference();
    _checkLocationPermission();
    _startQRCheckTimer();
    _loadProfileImage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    _qrCheckTimer?.cancel();
    super.dispose();
  }

  void _refreshAllData() {
    if (mounted) {
      print('Refreshing all dashboard data...');
      
      setState(() {
        _isLoading = true;  // Set loading state while refreshing
      });
      
      // First get the latest data directly from database
      _supabaseService.refreshUserData().then((freshData) {
        if (freshData != null) {
          // Format year and semester consistently
          final formattedYear = _formatYear(freshData['year']?.toString());
          final formattedSemester = _formatSemester(freshData['semester']?.toString());
          
          // Update state with fresh data
          if (mounted) {
          setState(() {
              _isLoading = false;  // Clear loading state
              _email = freshData['email'];
              _studentName = freshData['name'];
              _department = freshData['department'];
              _course = freshData['course'];
              _year = formattedYear;
              _semester = formattedSemester;
          });
            print('Updated UI from refreshed database data: Department=$_department, Course=$_course, Year=$_year, Semester=$_semester');
          }
        } else {
          // If no fresh data, load from cache
        _loadUserData();
        }
        
        // Load related data
        _loadProfileImage();
        _checkForNewQRCode();
        _checkForNewNotifications();
      }).catchError((error) {
        print('Error refreshing user data: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;  // Clear loading state on error
          });
        // Still try to reload from memory cache
        _loadUserData();
        _loadProfileImage();
        }
      });
    }
  }

  // Load dark mode preference
  Future<void> _loadDarkModePreference() async {
    try {
      final isDarkMode = await _supabaseService.getDarkModeEnabled();
      setState(() {
        _isDarkMode = isDarkMode;
      });
    } catch (e) {
      print('Error loading dark mode preference: $e');
    }
  }

  // Save dark mode preference
  Future<void> _saveDarkModePreference(bool value) async {
    try {
      await _supabaseService.setDarkModeEnabled(value);
      setState(() {
        _isDarkMode = value;
      });
    } catch (e) {
      print('Error saving dark mode preference: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get data from navigation arguments if available
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _isLoading = true; // Set loading state while processing args
      });
      
      // Store values received from login or other screens
      if (args.containsKey('userData') && args['userData'] != null) {
        final userData = args['userData'] as Map<String, dynamic>;
        
        // Update Supabase service cache first
        _supabaseService.updateCurrentUserCache(userData);
        
        // Format year and semester consistently
        final formattedYear = _formatYear(userData['year']?.toString());
        final formattedSemester = _formatSemester(userData['semester']?.toString());
        
        setState(() {
          _email = userData['email'];
          _studentName = userData['name'];
          _department = userData['department'];
          _course = userData['course'];
          _year = formattedYear;
          _semester = formattedSemester;
          _isLoading = false;
        });
        
        print('Applied data from navigation: Department=$_department, Course=$_course, Year=$_year, Semester=$_semester');
        
        // Immediately try to get location
        _initializeLocationImmediate();
        
        // Make sure data is saved to Supabase service
        if (args.containsKey('refreshData') && args['refreshData'] == true) {
          _refreshAllData(); // This will handle loading state
        }
      } else {
        // If just email and name provided
        setState(() {
          _email = args['email'];
          _studentName = args['name'];
          if (args.containsKey('department')) _department = args['department'];
          if (args.containsKey('course')) _course = args['course'];
          if (args.containsKey('year')) _year = _formatYear(args['year']);
          if (args.containsKey('semester')) _semester = _formatSemester(args['semester']);
          _isLoading = false;
        });
        
        // Try to get location
        _initializeLocationImmediate();
      }
      
      // If returning from update profile with confirmation
      if (args.containsKey('updated') && args['updated'] == true) {
        setState(() {
          _isLoading = true; // Set loading state for update
        });
        
        // If updated data is directly provided, use it immediately for faster UI update
        if (args.containsKey('userData') && args['userData'] != null) {
          final updatedData = args['userData'] as Map<String, dynamic>;
          
          // Update Supabase service cache first
          _supabaseService.updateCurrentUserCache(updatedData);
          
          // Format year and semester consistently
          final formattedYear = _formatYear(updatedData['year']?.toString());
          final formattedSemester = _formatSemester(updatedData['semester']?.toString());
          
          setState(() {
            _email = updatedData['email'];
            _studentName = updatedData['name'];
            _department = updatedData['department'];
            _course = updatedData['course'];
            _year = formattedYear;
            _semester = formattedSemester;
          });
          print('Applied immediate UI update with returned data: Name=$_studentName, Department=$_department, Course=$_course, Year=$_year, Semester=$_semester');
        }
        
        // Force full data refresh from server
        _supabaseService.refreshUserData().then((_) {
          // After server refresh, update the UI again with the latest data
          _loadUserData();
          _loadProfileImage();
          
          // Try to get location again
          _initializeLocationImmediate();
          
          print('Completed server refresh after profile update');
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }).catchError((error) {
          print('Error during server refresh: $error');
          // Still load cached data
          _loadUserData();
          
          // Try to get location
          _initializeLocationImmediate();
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
        
        // Show a confirmation toast
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        });
      } else {
        // Always reload profile image after navigation
        _loadProfileImage();
      }
    } else {
      // Even if no args were provided, refresh all data
      // This ensures dashboard is updated after returning from other screens
      _refreshAllData(); // This will handle loading state
      
      // Try to get location
      _initializeLocationImmediate();
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Get current user data from Supabase service
      final userData = _supabaseService.getCurrentUser();
      
      if (userData != null && mounted) {
        // Format year and semester consistently
        final formattedYear = _formatYear(userData['year']?.toString());
        final formattedSemester = _formatSemester(userData['semester']?.toString());
        
        setState(() {
          _email = userData['email'];
          _studentName = userData['name'];
          _department = userData['department'];
          _course = userData['course'];
          _year = formattedYear;
          _semester = formattedSemester;
          _isLoading = false;  // Ensure loading state is cleared
        });
        
        print('Loaded user data for dashboard: Name=$_studentName, Department=$_department, Course=$_course, Year=$_year, Semester=$_semester');
        
        // Check if we need to sync profile image with database
        if (userData.containsKey('email') && userData['email'] != null) {
          String? studentId = userData['student_id'];
          String email = userData['email'];
          
          // Trigger profile image sync in the background
          _supabaseService.syncProfileImageWithDatabase(email, studentId).then((imageUrl) {
            if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
              print('Synced profile image URL from storage: $imageUrl');
                setState(() {
                  if (imageUrl.startsWith('http')) {
                    _profileImagePath = imageUrl;
                    _profileImage = null;
                  }
                });
              
              // Update in-memory cache
              _supabaseService.updateCurrentUserCache({
                'profile_image_path': imageUrl
              });
            }
          });
        }
        
        // Always check for profile image when loading user data
        if (userData.containsKey('profile_image_path') && 
            userData['profile_image_path'] != null && 
            userData['profile_image_path'].toString().isNotEmpty) {
          setState(() {
            if (userData['profile_image_path'].toString().startsWith('http')) {
              _profileImagePath = userData['profile_image_path'];
              _profileImage = null;
            }
          });
        } else {
          // If no profile image in cached data, try to fetch from Supabase
          _loadProfileImage();
        }
      } else {
        print('No user data available - user not logged in');
        if (mounted) {
          setState(() {
            _isLoading = false;  // Ensure loading state is cleared even when no data
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;  // Ensure loading state is cleared on error
        });
      }
    }
  }

  // Load profile image with proper URL handling
  Future<void> _loadProfileImage() async {
    setState(() {
      _isAvatarLoading = true;
    });
    
    try {
      final userData = _supabaseService.getCurrentUser();
      if (userData == null) {
        setState(() {
          _profileImage = null;
          _profileImagePath = null;
          _isAvatarLoading = false;
        });
        return;
      }

      String? imagePath = userData['profile_image_path'];
      
      if (imagePath != null && imagePath.isNotEmpty) {
        print('Loading profile image from path: $imagePath');
        
        // Clear existing image cache to ensure we load the latest version
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        
        setState(() {
          _profileImage = null;
          _profileImagePath = imagePath;
          _isAvatarLoading = false;
        });
        
        // Also refresh the image URL in the database to ensure it's current
        _supabaseService.syncProfileImageWithDatabase(
          userData['email'],
          userData['student_id']
        ).then((updatedUrl) {
          if (updatedUrl != null && updatedUrl != imagePath) {
            setState(() {
              _profileImagePath = updatedUrl;
            });
          }
        });
      } else {
        print('No profile image path found');
        setState(() {
          _profileImage = null;
          _profileImagePath = null;
          _isAvatarLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
      setState(() {
        _profileImage = null;
        _profileImagePath = null;
        _isAvatarLoading = false;
      });
    }
  }

  // Schedule refresh of signed URL before expiry
  Timer? _imageRefreshTimer;
  
  void _scheduleImageUrlRefresh() {
    _imageRefreshTimer?.cancel();
    // Refresh URL 5 minutes before expiry (3600 - 300 = 3300 seconds)
    _imageRefreshTimer = Timer(Duration(seconds: 3300), () {
      if (mounted) {
        _loadProfileImage();
      }
    });
  }

  // Save profile image
  Future<void> _saveProfileImage(File imageFile) async {
    try {
      final result = await _supabaseService.uploadProfileImage(imageFile);
      
      if (result['success']) {
        print('Saved profile image: ${result['imagePath']}');
        _loadProfileImage(); // Reload to display the new image
      } else {
        print('Failed to save profile image: ${result['message']}');
      }
    } catch (e) {
      print('Error saving profile image: $e');
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
                
                // Clear user data from Supabase
                await _logout();
              },
            ),
          ],
        );
      },
    );
  }

  // Method to clear user data from Supabase
  Future<void> _logout() async {
    try {
      await _supabaseService.logout();
      // Navigate to the role selection screen
      Navigator.pushReplacementNamed(context, '/role-selection');
    } catch (e) {
      print('Error during logout: $e');
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
      
      final userData = await _supabaseService.getUserData();
      
      if (userData != null) {
        // First check if the user recently marked attendance
        final lastAttendanceTimesStr = userData['last_attendance_times'];
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
        
        List<String> activeSessions = userData['active_sessions'] ?? [];
        
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
          bool alreadyAttended = userData['attended_session_${_email}_$sessionId'] ?? false;
          if (alreadyAttended) {
            continue; // Skip this session if already attended
          }
          
          // Check if session is relevant to student
          String? sessionDataString = userData['session_$sessionId'];
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
      } else {
        print('No user data available - user not logged in');
        setState(() {
          _hasNewQR = false;
        });
      }
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
      final userData = await _supabaseService.getUserData();
      
      if (userData != null) {
        // Logic to check for new notifications would go here
        // For now, we'll set it to false until actual notification checking is implemented
        
        // Example of how real notification checking would work:
        // final unreadNotifications = userData['unread_notifications'] ?? [];
        // setState(() {
        //   _hasNewNotifications = unreadNotifications.isNotEmpty;
        // });
        
        setState(() {
          _hasNewNotifications = false; // Only set to true when actual notifications exist
        });
      } else {
        print('No user data available - user not logged in');
        setState(() {
          _hasNewNotifications = false; // Default to no notifications on error
        });
      }
    } catch (e) {
      print('Error checking for new notifications: $e');
      setState(() {
        _hasNewNotifications = false; // Default to no notifications on error
      });
    }
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
    
    Widget buildLoadingPlaceholder() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Only show loading for profile picture
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()}, 👋',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        ),
                      Text(
                        'Student',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Email: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
              ),
                    ),
                  ],
            ),
                SizedBox(height: 4),
                Text(
                  'Department: Loading...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Course: Loading...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
              ),
            ),
                SizedBox(height: 4),
                Text(
                  'Year: Loading...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Semester: Loading...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildLocationPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Dashboard'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.notifications, color: Colors.white),
                  onPressed: _isLoading ? null : () {
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
                if (_hasNewNotifications && !_isLoading)
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
              // Show loading placeholder or actual content
              _isLoading ? buildLoadingPlaceholder() : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                  color: Colors.blue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProfileAvatar(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}, 👋',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_studentName ?? 'Loading...'}',
                                    style: const TextStyle(
                                fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                                Text(
                            'Email: ',
                                  style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                          Expanded(
                            child: Text(
                              _email ?? 'Loading email...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                            ),
                        ),
                      ),
                    ],
                  ),
                      SizedBox(height: 4),
                      Text(
                        'Department: ${_department ?? 'Loading department...'}',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Course: ${_course ?? 'Loading course...'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                    ),
                  ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                  Text(
                            'Year: ',
                    style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                    ),
                  ),
                  Text(
                            'Year ${_year?.replaceAll('Year ', '')}',
                    style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                    ),
                          ),
                        ],
                  ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                  Text(
                            'Semester: ',
                    style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Semester ${_semester?.replaceAll('Semester ', '')}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                    ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildLocationPanel(),
                        ),
                      ],
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
                      childAspectRatio: 1.0,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildMenuItem(
                          title: 'Scan QR',
                          color: Colors.blue,
                          route: '/scan-qr',
                          assetPath: 'assets/images/student icons/scan qr code.png',
                          showNotification: _hasNewQR && !_isLoading,
                        ),
                        _buildMenuItem(
                          title: 'Register Units',
                          color: Colors.red,
                          route: '/results-cat',
                          assetPath: 'assets/images/student icons/cat results.png',
                        ),
                        _buildMenuItem(
                          title: 'Results for CAT',
                          color: Colors.purple,
                          route: '/register-units',
                          assetPath: 'assets/images/student icons/register units.png',
                        ),
                        _buildMenuItem(
                          title: 'Past Papers',
                          color: Colors.green,
                          route: '/past-papers',
                          assetPath: 'assets/images/student icons/past papers.png',
                        ),
                        _buildMenuItem(
                          title: 'Evaluate Lecture',
                          color: Colors.amber,
                          route: '/evaluate-lecture',
                          assetPath: 'assets/images/student icons/evaluate lecture.png',
                        ),
                        _buildMenuItem(
                          title: 'Exam Card',
                          color: Colors.teal,
                          route: '/exam-card',
                          assetPath: 'assets/images/student icons/exam card.png',
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
                      childAspectRatio: 1.0,  // Adjusted for larger icons
                      mainAxisSpacing: 16,    // Increased spacing
                      crossAxisSpacing: 16,   // Increased spacing
                      children: [
                        _buildMenuItem(
                          title: 'Schedules',
                          color: Colors.blue,
                          route: '/schedules',
                          assetPath: 'assets/images/student icons/schedules.png',
                        ),
                        _buildMenuItem(
                          title: 'Notifications',
                          color: Colors.red,
                          route: '/notifications',
                          assetPath: 'assets/images/student icons/notifications.png',
                          showNotification: _hasNewNotifications && !_isLoading,
                        ),
                        _buildMenuItem(
                          title: 'Trends',
                          color: Colors.orange,
                          route: '/trends',
                          assetPath: 'assets/images/student icons/trends.png',
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
                      childAspectRatio: 1.0,  // Adjusted for larger icons
                      mainAxisSpacing: 16,    // Increased spacing
                      crossAxisSpacing: 16,   // Increased spacing
                      children: [
                        _buildMenuItem(
                          title: 'Get in Touch',
                          color: Colors.green,
                          route: '/get-in-touch',
                          assetPath: 'assets/images/student icons/get in  touch.png',
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
    required String title,
    required Color color,
    required String route,
    required String assetPath,
    bool showNotification = false,
  }) {
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    
    return InkWell(
        onTap: () {
          _checkLocationBeforeNavigating(() {
            Navigator.pushNamed(context, route, arguments: {
              'email': _email,
              'name': _studentName,
              'department': _department,
              'course': _course,
              'year': _year,
              'semester': _semester,
            });
          });
        },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              flex: 4,  // Increased flex for larger icons
              child: Container(
                padding: EdgeInsets.all(4),  // Reduced padding to allow larger icon
                child: Stack(
              clipBehavior: Clip.none,
              children: [
                    Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                ),
                if (showNotification)
                  Positioned(
                        top: -8,
                        right: -8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
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
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
              title,
              style: TextStyle(
                    fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                    _buildProfileAvatar(),
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
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToUpdateDetailsPage();
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
  
  // Profile image picking
  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uploading profile image...'),
              ],
            ),
          );
        },
      );
      
      // Upload image to Supabase
      final File imageFile = File(image.path);
      final result = await _supabaseService.uploadProfileImage(imageFile);
      
      if (!mounted) return;
      
      // Dismiss loading dialog
      Navigator.of(context).pop();
      
      if (result['success']) {
        print('Successfully uploaded image, refreshing UI with new image: ${result['imagePath']}');
        
        // Clear existing image cache
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        
        // Force profile image reload from Supabase with a small delay
        // This ensures the UI refreshes with the new image
        setState(() {
          // First set loading state
          _isAvatarLoading = true;
          
          // Clear current image so it doesn't stick around
          _profileImage = null;
          _profileImagePath = null;
        });
        
        // Delay slightly to ensure state updates fully propagate
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            _loadProfileImage();
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile image: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error picking profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile image'),
          backgroundColor: Colors.red,
        ),
      );
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
            rethrow; // Re-throw after max retries
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
      
      // Comprehensive location extraction function
      String extractFullLocationDetails(Placemark place) {
        List<String> locationParts = [];
        
        // Always start with country
        if (place.country != null && place.country!.isNotEmpty) {
          locationParts.add(place.country!);
        }
        
        // Add university or institution name if possible
        if (place.name != null && place.name!.isNotEmpty && 
            (place.name!.contains('University') || place.name!.contains('College'))) {
          locationParts.add(place.name!);
        }
        
        // Add specific location details
        if (place.street != null && place.street!.isNotEmpty && 
            !place.street!.contains('Unnamed')) {
          locationParts.add(place.street!);
        }
        
        // Add sublocality or neighborhood
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          locationParts.add(place.subLocality!);
        }
        
        // Add locality (town/city)
        if (place.locality != null && place.locality!.isNotEmpty) {
          locationParts.add(place.locality!);
        }
        
        // Add sub-administrative area (district/region)
        if (place.subAdministrativeArea != null && 
            place.subAdministrativeArea!.isNotEmpty) {
          locationParts.add(place.subAdministrativeArea!);
        }
        
        // Add administrative area (county/state)
        if (place.administrativeArea != null && 
            place.administrativeArea!.isNotEmpty) {
          locationParts.add(place.administrativeArea!);
        }
        
        // Remove duplicates and empty/generic strings
        locationParts = locationParts.where((part) => 
            part.isNotEmpty && 
            part.toLowerCase() != 'unnamed' && 
            part.toLowerCase() != 'unknown'
        ).toSet().toList();
        
        return locationParts.join(', ');
      }
      
      // Try to get the most detailed location from available placemarks
      String locationName = '';
      for (var place in placemarks) {
        locationName = extractFullLocationDetails(place);
        if (locationName.isNotEmpty) break;
      }
      
      // Fallback to a comprehensive location if no details found
      if (locationName.isEmpty) {
        locationName = "Kenya, Tharaka University College, Tharaka-Nithi County";
      }
      
      // Ensure the location is not too long
      if (locationName.length > 100) {
        locationName = "${locationName.substring(0, 97)}...";
      }
      
      setState(() {
        _currentLocation = locationName;
      });

      // Get current user data
      final userData = _supabaseService.getCurrentUser();
      String? studentId;
      
      if (userData != null && userData.containsKey('student_id')) {
        studentId = userData['student_id'];
      }
      
      // If no student ID, try to get it from Supabase
      if (studentId == null && userData != null && userData.containsKey('email') && userData.containsKey('id')) {
        studentId = await _supabaseService.ensureStudentRecordExists(
          userData['id'],
          userData['email']
        );
      }

          if (studentId != null) {
        // Try both update methods to ensure the location is stored
        bool success = await _supabaseService.updateStudentLocation(
              studentId, 
              locationName,
              position.latitude,
              position.longitude
            );
            
        if (!success) {
          // Try direct update as fallback
            success = await _supabaseService.updateLocationDirect(
              studentId,
              locationName,
              position.latitude,
              position.longitude
            );
        }
            
        if (!success) {
          print('Failed to update location in database after multiple attempts');
              }
            }
          } catch (e) {
      print('Error getting and updating address: $e');
      setState(() {
        if (!_isOnline) {
          _currentLocation = "Waiting for network...";
        } else {
          _currentLocation = "Kenya, Tharaka University College, Tharaka-Nithi County";
        }
      });
    }
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

  // Initialize connectivity
  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('Error initializing connectivity: $e');
    }
  }

  // Check location services
  Future<void> _checkLocationServices() async {
    try {
      _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (_locationServiceEnabled) {
        _permissionStatus = await Geolocator.checkPermission();
        if (_permissionStatus == LocationPermission.whileInUse ||
            _permissionStatus == LocationPermission.always) {
          _getCurrentLocation();
        } else {
          _initializeLocation();
        }
      } else {
        _initializeLocation();
      }
    } catch (e) {
      print('Error checking location services: $e');
    }
  }

  // Start QR check timer
  void _startQRCheckTimer() {
    // Cancel existing timer if it exists
    _qrCheckTimer?.cancel();
    
    // Check immediately
    _checkForNewQRCode();
    _checkForNewNotifications();
    
    // Then set up timer for periodic checks
    _qrCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkForNewQRCode();
        _checkForNewNotifications();
      }
    });
  }

  // Start a timer to update location periodically
  void _startLocationUpdateTimer() {
    // Update location every 5 minutes (300 seconds)
    Timer.periodic(Duration(seconds: 300), (timer) {
      if (mounted && _isOnline) {
        print('Periodic location update triggered');
        _getCurrentLocation();
      }
    });
  }

  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: _isAvatarLoading
              ? CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[200],
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
              : GestureDetector(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage as File)
                        : (_profileImagePath != null && 
                           _profileImagePath!.isNotEmpty)
                            ? NetworkImage(_profileImagePath!) as ImageProvider<Object>
                            : null,
                    child: (_profileImage == null &&
                            (_profileImagePath == null || 
                             _profileImagePath!.isEmpty))
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
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
    );
  }

  // Navigate to the update details page
  void _navigateToUpdateDetailsPage() async {
    if (_isOnline) {
      // Make sure we have fresh user data before showing update form
      await _supabaseService.refreshUserData();
      
      if (mounted) {
        // Create map with current dashboard values to pass to update page
        Map<String, dynamic> currentUserData = {
          'email': _email,
          'name': _studentName,
          'department': _department,
          'course': _course,
          'year': _year,
          'semester': _semester,
          'id': _supabaseService.getCurrentUser()?['id'],
          'student_id': _supabaseService.getCurrentUser()?['student_id'],
          'password': _supabaseService.getCurrentUser()?['password'],
        };
        
        // Navigate to update page with current data
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UpdateDetailsPage(),
            settings: RouteSettings(arguments: {'userData': currentUserData}),
          ),
        );
        
        // Handle result when returning from update page
        if (result != null && result is Map<String, dynamic>) {
          if (result.containsKey('updated') && result['updated'] == true) {
            print('Profile updated, refreshing dashboard with new data');
            
            if (result.containsKey('userData') && result['userData'] != null) {
              // Update UI immediately with returned data for instant feedback
              setState(() {
                final userData = result['userData'] as Map<String, dynamic>;
                _studentName = userData['name'];
                _department = userData['department'];
                _course = userData['course'];
                _year = userData['year'];
                _semester = userData['semester'];
              });
              
              // Important: Update the current user in Supabase service BEFORE refreshing
              _supabaseService.updateCurrentUserCache(result['userData']);
              
              // Force a full refresh from database
              final refreshResult = await _supabaseService.refreshUserData();
              if (refreshResult != null) {
                setState(() {
                  _studentName = refreshResult['name'];
                  _department = refreshResult['department'];
                  _course = refreshResult['course'];
                  _year = refreshResult['year'];
                  _semester = refreshResult['semester'];
                  print('Dashboard fully refreshed with latest data: $_studentName');
                });
              }
              
              // Don't call _loadUserData() as it might override with cached data
              // Instead explicitly set all UI fields from the refreshed data
            }
            
            // Show a success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Profile updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } else {
      // Show offline message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are offline. Please connect to the internet to update your profile.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Force update location and ensure it's saved to the database
  Future<void> _forceUpdateLocation() async {
    try {
      setState(() {
        _currentLocation = "Getting location...";
      });
      
      if (!_isOnline) {
        setState(() {
          _currentLocation = "Waiting for network...";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please connect to the internet to update your location'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check if location services are enabled
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
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('Updating your location...'),
            ],
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.blue,
        ),
      );
      
      // Get location with high accuracy
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      );
      
      // Process and save location with comprehensive details
      await _getAndUpdateAddress(position);
      
      // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      print('Error during force location update: $e');
      
      // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update location. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
      
      setState(() {
        _currentLocation = "Kenya, Tharaka University College, Tharaka-Nithi County";
      });
    }
  }

  Widget _buildLocationPanel() {
    return Container(
      width: double.infinity,  // Make it full width
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(Icons.location_on, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
              _currentLocation,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
              ),
                  maxLines: 3,  // Increase max lines to show more details
              overflow: TextOverflow.ellipsis,
                ),
                if (_currentLocation == "Waiting for network..." || 
                    _currentLocation == "Getting location..." ||
                    _currentLocation == "Tharaka-Nithi County")
                  Text(
                    "Tap to update precise location",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _forceUpdateLocation,
            child: Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.refresh, color: Colors.white, size: 14),
            ),
          )
        ],
      ),
    );
  }

  // Initialize location with immediate update
  Future<void> _initializeLocationImmediate() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        _showEnableLocationDialog();
        return;
      }
      
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationPermissionRequiredDialog();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showPermanentlyDeniedLocationDialog();
        return;
      }
      
      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      );

      setState(() {
        _currentPosition = position;
      });

      // Get and update address immediately with comprehensive details
      await _getAndUpdateAddress(position);
      
    } catch (e) {
      print('Error initializing immediate location: $e');
      setState(() {
        _currentLocation = _isOnline ? "Tap to retry" : "Waiting for network...";
      });
    }
  }

  // Get and update address with immediate database update
  Future<void> _getAndUpdateAddress(Position position) async {
    try {
      print('🌍 LOCATION UPDATE DETECTION 🌍');
      print('🕒 Timestamp: ${DateTime.now()}');
      print('🌐 New Coordinates: Lat ${position.latitude}, Lon ${position.longitude}');
      
      // Compare with previous known location
      if (_currentPosition != null) {
        double distanceDifference = Geolocator.distanceBetween(
          _currentPosition!.latitude, 
          _currentPosition!.longitude, 
          position.latitude, 
          position.longitude
        );
        
        print('📏 Distance from Previous Location: ${distanceDifference.toStringAsFixed(2)} meters');
        
        // Significant location change threshold (e.g., 500 meters)
        if (distanceDifference > 500) {
          print('🚨 SIGNIFICANT LOCATION CHANGE DETECTED! 🚨');
        }
      }

      if (!_isOnline) {
        print('🚫 Offline: Cannot update location');
        setState(() {
          _currentLocation = "Waiting for network...";
        });
        return;
      }

      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      // Comprehensive location extraction function
      String extractFullLocationDetails(Placemark place) {
        List<String> locationParts = [];
        
        print('🏠 Placemark Details:');
        print('   Country: ${place.country}');
        print('   Name: ${place.name}');
        print('   Street: ${place.street}');
        print('   Locality: ${place.locality}');
        print('   Sub-Locality: ${place.subLocality}');
        print('   Administrative Area: ${place.administrativeArea}');
        print('   Sub-Administrative Area: ${place.subAdministrativeArea}');
        
        // Always start with country
        if (place.country != null && place.country!.isNotEmpty) {
          locationParts.add(place.country!);
        }
        
        // Add university or institution name if possible
        if (place.name != null && place.name!.isNotEmpty && 
            (place.name!.contains('University') || place.name!.contains('College'))) {
          locationParts.add(place.name!);
        }
        
        // Add specific location details
        if (place.street != null && place.street!.isNotEmpty && 
            !place.street!.contains('Unnamed')) {
          locationParts.add(place.street!);
        }
        
        // Add sublocality or neighborhood
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          locationParts.add(place.subLocality!);
        }
        
        // Add locality (town/city)
      if (place.locality != null && place.locality!.isNotEmpty) {
          locationParts.add(place.locality!);
        }
        
        // Add sub-administrative area (district/region)
        if (place.subAdministrativeArea != null && 
            place.subAdministrativeArea!.isNotEmpty) {
          locationParts.add(place.subAdministrativeArea!);
        }
        
        // Add administrative area (county/state)
      if (place.administrativeArea != null && 
            place.administrativeArea!.isNotEmpty) {
          locationParts.add(place.administrativeArea!);
        }
        
        // Remove duplicates and empty/generic strings
        locationParts = locationParts.where((part) => 
            part.isNotEmpty && 
            part.toLowerCase() != 'unnamed' && 
            part.toLowerCase() != 'unknown'
        ).toSet().toList();
        
        return locationParts.join(', ');
      }
      
      // Try to get the most detailed location from available placemarks
      String locationName = '';
      for (var place in placemarks) {
        locationName = extractFullLocationDetails(place);
        if (locationName.isNotEmpty) break;
      }
      
      // Fallback to a comprehensive location if no details found
      if (locationName.isEmpty) {
        locationName = "Kenya, Tharaka University College, Tharaka-Nithi County";
      }
      
      // Ensure the location is not too long
      if (locationName.length > 100) {
        locationName = "${locationName.substring(0, 97)}...";
      }

      print('📍 Extracted Location: $locationName');
      
      setState(() {
        _currentLocation = locationName;
      });

      // Get current user data
      final userData = _supabaseService.getCurrentUser();
      String? studentId;
      
      if (userData != null && userData.containsKey('student_id')) {
        studentId = userData['student_id'];
      }

      // If no student ID, try to get it from Supabase
      if (studentId == null && userData != null && userData.containsKey('email') && userData.containsKey('id')) {
        studentId = await _supabaseService.ensureStudentRecordExists(
          userData['id'],
          userData['email']
        );
      }

      if (studentId != null) {
        print('🆔 Student ID for location update: $studentId');
        
        // Try both update methods to ensure the location is stored
        bool success = await _supabaseService.updateStudentLocation(
          studentId,
          locationName,
          position.latitude,
          position.longitude
        );

        if (!success) {
          // Try direct update as fallback
          success = await _supabaseService.updateLocationDirect(
            studentId,
            locationName,
            position.latitude,
            position.longitude
          );
        }

        if (!success) {
          print('❌ Failed to update location in database after multiple attempts');
        } else {
          print('✅ Location successfully updated in database');
        }
      } else {
        print('❌ No student ID found for location update');
      }
    } catch (e) {
      print('🚨 Error getting and updating address: $e');
      setState(() {
        if (!_isOnline) {
          _currentLocation = "Waiting for network...";
        } else {
          _currentLocation = "Kenya, Tharaka University College, Tharaka-Nithi County";
        }
      });
    }
  }

  // Helper methods to format year and semester
  String _formatYear(String? year) {
    if (year == null || year.isEmpty) return 'Year ?';
    // Remove any existing "Year" prefix and trim
    year = year.replaceAll(RegExp(r'^Year\s*'), '').trim();
    return 'Year $year';
  }

  String _formatSemester(String? semester) {
    if (semester == null || semester.isEmpty) return 'Semester ?';
    // Remove any existing "Semester" prefix and trim
    semester = semester.replaceAll(RegExp(r'^Semester\s*'), '').trim();
    return 'Semester $semester';
  }

  // Setup connectivity listener
  void _setupConnectivityListener() {
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  // Check location permission
  void _checkLocationPermission() {
    _initializeLocationImmediate();
    _startLocationUpdateTimer();
  }
} 
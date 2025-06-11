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
import 'package:qr_attendance/services/supabase_service.dart';

class LecturerDashboardScreen extends StatefulWidget {
  const LecturerDashboardScreen({super.key});

  @override
  State<LecturerDashboardScreen> createState() => _LecturerDashboardScreenState();
}

class _LecturerDashboardScreenState extends State<LecturerDashboardScreen> with WidgetsBindingObserver {
  final SupabaseService _supabaseService = SupabaseService();
  
  String? _email;
  String? _lecturerName;
  String? _department;
  String? _occupation;
  String? _employmentType;
  String? _gender;
  String? _profileImageUrl;
  
  // Add loading state for avatar
  bool _isAvatarLoading = false;
  
  // Add image refresh timer
  Timer? _imageRefreshTimer;
  
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
  final bool _locationServiceEnabled = false;
  LocationPermission? _permissionStatus;

  // Loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    setState(() {
      _isLoading = true;
      _isAvatarLoading = true;
    });
    
    // Initialize internet connectivity checking
    _checkConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    
    // Start clock timer
    _updateTime();
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) => _updateTime());
    
    // Initialize location immediately
    _initializeLocationImmediate();
    
    // Load dark mode preference
    _loadDarkModePreference();
    
    // Load user data including profile image
    _loadUserData().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    // Set up periodic profile image refresh
    _scheduleImageUrlRefresh();
    
    // Set up periodic location updates for better tracking
    _startLocationUpdateTimer();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // First get the latest data directly from database
      await _supabaseService.refreshUserData();
      
      // Load user data
    await _loadUserData();
      
      // Start other services
    _startClock();
    _checkConnectivity();
    _setupConnectivityStream();
      _getCurrentLocation();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _email = args['email'];
        _lecturerName = args['name'];
        _department = args['department'];
        _occupation = args['occupation'];
        _employmentType = args['employmentType'];
        _gender = args['gender'];
        
        // Only update profile image if it's provided and different
        if (args['profile_image_path'] != null && 
            args['profile_image_path'].toString().isNotEmpty &&
            args['profile_image_path'] != _profileImageUrl) {
          _profileImageUrl = args['profile_image_path'];
          // Pre-cache the image
          if (_profileImageUrl != null && _profileImageUrl!.startsWith('http')) {
            precacheImage(
              NetworkImage(_profileImageUrl!),
              context,
              onError: (exception, stackTrace) {
                print('Error pre-caching image in didChangeDependencies: $exception');
              },
            );
          }
        }
      });
    }
    
    // Ensure we have the latest data, including profile image
    if (_profileImageUrl == null || _profileImageUrl!.isEmpty) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isAvatarLoading = true;
      });

      // Get current user data from Supabase service
      final userData = _supabaseService.getCurrentUser();
      
      if (userData != null && mounted) {
        // First set basic user data
        setState(() {
          _email = userData['email'];
          _lecturerName = userData['name'];
          _department = userData['department'];
          _occupation = userData['occupation'];
          _employmentType = userData['employmentType'];
          _gender = userData['gender'];
        });
        
        print('Loaded user data for dashboard: Name=$_lecturerName, Department=$_department');
        
        // Handle profile image with proper caching
        if (userData.containsKey('profile_image_path') && 
            userData['profile_image_path'] != null && 
            userData['profile_image_path'].toString().isNotEmpty) {
          
          String imageUrl = userData['profile_image_path'];
          
          // Ensure URL is valid
          if (imageUrl.startsWith('http')) {
            print('Setting profile image from cached data: $imageUrl');
            setState(() {
              _profileImageUrl = imageUrl;
            });
            
            // Pre-cache the image
            precacheImage(
              NetworkImage(imageUrl),
              context,
              onError: (exception, stackTrace) {
                print('Error pre-caching image: $exception');
                if (mounted) {
                  setState(() {
                    _profileImageUrl = null;
                    _isAvatarLoading = false;
                  });
                }
              },
            );
          }
        }
        
        // Always sync with database to ensure we have latest image
        if (userData.containsKey('email') && userData['email'] != null) {
          String? lecturerId = userData['lecturer_id'];
          String email = userData['email'];
          
          print('Syncing profile image for lecturer: $email');
          final imageUrl = await _supabaseService.syncLecturerProfileImage(email, lecturerId);
          
          if (imageUrl != null && imageUrl.isNotEmpty && mounted) {
            print('Synced profile image URL from storage: $imageUrl');
            if (imageUrl.startsWith('http')) {
              // Clear image cache before setting new URL
              imageCache.clear();
              imageCache.clearLiveImages();
              
              setState(() {
                _profileImageUrl = imageUrl;
              });
              
              // Pre-cache the new image
              precacheImage(
                NetworkImage(imageUrl),
                context,
                onError: (exception, stackTrace) {
                  print('Error pre-caching synced image: $exception');
                },
              );
              
              // Update in-memory cache
              _supabaseService.updateCurrentUserCache({
                'profile_image_path': imageUrl
              });
            }
          }
        }
      } else {
        print('No user data available - user not logged in');
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAvatarLoading = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Cancel image refresh timer
    _imageRefreshTimer?.cancel();
    
    // Existing dispose code...
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _connectivitySubscription.cancel();
    
    _locationUpdateTimer?.cancel();
    
    super.dispose();
  }

  void _scheduleImageUrlRefresh() {
    // Cancel any existing timer
    _imageRefreshTimer?.cancel();
    
    // Schedule refresh every 30 minutes
    _imageRefreshTimer = Timer.periodic(Duration(minutes: 30), (timer) {
      if (mounted) {
        _refreshProfileImage();
      }
    });
  }

  Future<void> _refreshProfileImage() async {
    setState(() {
      _isAvatarLoading = true;
    });
    
    try {
      final userData = _supabaseService.getCurrentUser();
      if (userData == null) {
      setState(() {
          _profileImageUrl = null;
          _isAvatarLoading = false;
        });
        return;
      }

      String? imagePath = userData['profile_image_path'];
      
      if (imagePath != null && imagePath.isNotEmpty && imagePath.startsWith('http')) {
        print('Loading profile image from path: $imagePath');
        
        // Clear existing image cache to ensure we load the latest version
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          
          setState(() {
          _profileImageUrl = imagePath;
          _isAvatarLoading = false;
        });
        
        // Also refresh the image URL in the database to ensure it's current
        _supabaseService.syncLecturerProfileImage(
          userData['email'],
          userData['lecturer_id']
        ).then((updatedUrl) {
          if (updatedUrl != null && updatedUrl != imagePath && updatedUrl.startsWith('http')) {
            setState(() {
              _profileImageUrl = updatedUrl;
            });
            }
          });
        } else {
        print('No profile image path found');
        setState(() {
          _profileImageUrl = null;
          _isAvatarLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
      setState(() {
        _profileImageUrl = null;
        _isAvatarLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue;
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileImage(),
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
                                _lecturerName ?? '',
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
                          // Email
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Email: ',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text: _email ?? 'Not set',
                                ),
                              ],
                            ),
                            overflow: TextOverflow.visible,
                          ),
                          SizedBox(height: 2),
                          
                          // Department with text wrapping support
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 15,
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
                          SizedBox(height: 2),
                          
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
                      childAspectRatio: 0.95,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/create qr.png',
                          title: 'Create QR Code',
                          color: Colors.blue,
                          route: AppRoutes.createPage,
                        ),
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/manual entry.png',
                          title: 'Manual Entry',
                          color: Colors.orange,
                          route: AppRoutes.manualEntryPage,
                        ),
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/pin location.png',
                          title: 'Pin Location',
                          color: Colors.purple,
                          route: AppRoutes.pinLocationPage,
                        ),
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/reports.png',
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
                      childAspectRatio: 0.95,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/assign unit.png',
                          title: 'Get Assigned Units',
                          color: Colors.blue,
                          route: AppRoutes.getAssignedUnitsPage,
                        ),
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/schedules.png',
                          title: 'Schedules',
                          color: Colors.red,
                          route: AppRoutes.lecturerSchedulesPage,
                        ),
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/notifications.png',
                          title: 'Notifications & Alerts',
                          color: Colors.amber,
                          route: AppRoutes.lecturerNotificationsPage,
                        ),
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/evaluate lecture.png',
                          title: 'Analysis',
                          color: Colors.teal,
                          route: AppRoutes.analysisPage,
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
                      childAspectRatio: 0.95,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [
                        _buildMenuItem(
                          assetPath: 'assets/images/lecture icons/enter cat marks.png',
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
                    _buildProfileImage(radius: 35),
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
                        Navigator.pushNamed(
                          context,
                          AppRoutes.viewPage,
                          arguments: {
                            'email': _email,
                            'name': _lecturerName,
                            'department': _department,
                            'course': _department,
                            'year': '',
                            'semester': '',
                            'lectureNumber': _email,
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
                            'email': _email, // For backward compatibility
                            'lectureNumber': _email,
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
    IconData? icon,
    String? assetPath,
    required String title,
    required Color color,
    required String route,
  }) {
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    
    return InkWell(
      onTap: () {
        _checkLocationBeforeNavigating(() {
          if (route == AppRoutes.createPage) {
            Navigator.pushNamed(context, route, arguments: {
              'email': _email,
              'lectureNumber': _email,
              'name': _lecturerName,
              'department': _department,
              'occupation': _occupation,
              'employmentType': _employmentType,
              'gender': _gender,
            });
          } else if (route == AppRoutes.historyPage) {
            Navigator.pushNamed(context, route, arguments: {
              'email': _email,
              'lectureNumber': _email,
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
                'email': _email,
                'lectureNumber': _email,
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: EdgeInsets.all(8),
                child: assetPath != null
                  ? Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      icon ?? Icons.error,
                      size: 45,
                      color: color,
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
      final userLectureNumber = _email ?? prefs.getString('current_lecture_number');
        
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
        locationName = "${locationName.substring(0, 18)}..";
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

  // Add missing methods
  void _startClock() {
    _updateTime();
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('Error checking connectivity: $e');
    }
  }

  void _setupConnectivityStream() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionStatus(result);
    });
  }

  Future<void> _refreshAllData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final userData = _supabaseService.getCurrentUser();
      if (userData != null) {
        setState(() {
          _email = userData['email'];
          _lecturerName = userData['name'];
          _department = userData['department'];
          _occupation = userData['occupation'];
          _employmentType = userData['employmentType'];
          _gender = userData['gender'];
          _profileImageUrl = userData['profile_image_path'];
        });
      }

      // Also refresh location
      _getCurrentLocation();
    } catch (e) {
      print('Error refreshing data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing data: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  Widget _buildProfileImage({double radius = 30}) {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Base CircleAvatar with placeholder
            CircleAvatar(
              radius: radius,
              backgroundColor: Colors.grey[200],
              child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: radius * 0.67,
                          color: Colors.grey[600],
                        ),
                        if (radius >= 30) ...[
                          SizedBox(height: 2),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: radius * 0.33,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    )
                  : null,
            ),
            
            // Profile image with error handling
            if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
              CircleAvatar(
                radius: radius,
                backgroundColor: Colors.transparent,
                backgroundImage: NetworkImage(_profileImageUrl!),
                onBackgroundImageError: (exception, stackTrace) {
                  print('Error loading profile image: $exception');
                  setState(() {
                    _profileImageUrl = null;
                  });
                },
              ),
              
            // Loading indicator
            if (_isAvatarLoading)
              Container(
                width: radius * 2,
                height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Center(
                  child: SizedBox(
                    width: radius,
                    height: radius,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

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
      final result = await _supabaseService.uploadLecturerProfileImage(imageFile);
      
      if (!mounted) return;
      
      // Dismiss loading dialog
      Navigator.of(context).pop();
      
      if (result['success']) {
        print('Successfully uploaded image, refreshing UI with new image: ${result['imagePath']}');
        
        // Clear existing image cache
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        
        // Force profile image reload from Supabase with a small delay
        setState(() {
          // First set loading state
          _isAvatarLoading = true;
          
          // Clear current image
          _profileImageUrl = null;
        });
        
        // Delay slightly to ensure state updates fully propagate
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            _refreshProfileImage();
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

  // Initialize location immediately on startup
  Future<void> _initializeLocationImmediate() async {
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

  // Set up periodic location updates
  Timer? _locationUpdateTimer;
  
  void _startLocationUpdateTimer() {
    _locationUpdateTimer?.cancel();
    // Update location every 5 minutes
    _locationUpdateTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (mounted) {
        _getCurrentLocation();
      }
    });
  }
} 
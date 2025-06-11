import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/attendance_service.dart';
import 'package:qr_attendance/services/device_security_service.dart';
import 'package:qr_attendance/widgets/custom_text_field.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:qr_attendance/screens/student/qr_scanner_screen.dart';
import 'package:qr_attendance/screens/student/backup_key_screen.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({Key? key}) : super(key: key);

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final AttendanceService _attendanceService = AttendanceService();
  final DeviceSecurityService _deviceSecurity = DeviceSecurityService();
  
  bool _isLoadingUnits = true;
  String? _errorMessage;
  bool _isWithinRadius = false;
  bool _hasLocationPermission = false;
  bool _isLocationEnabled = false;
  String _locationStatus = "Checking location...";
  Position? _currentPosition;
  List<Map<String, dynamic>> _registeredUnits = [];
  String? _selectedUnitId;
  Map<String, dynamic>? _activeSession;
  bool isProcessing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadRegisteredUnits();
    _checkLocationServices();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Unit Selection Card with feedback
            Card(
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    Text(
                      'Select Unit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                        ),
                        SizedBox(width: 8),
                        if (_selectedUnitId != null)
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                      ],
                    ),
                    SizedBox(height: 12),
                    _isLoadingUnits
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ))
                        : DropdownButtonFormField<String>(
                            value: _selectedUnitId,
                              isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Select a unit to proceed',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.blue, width: 2),
                              ),
                            ),
                            items: _registeredUnits.map((unit) {
                              return DropdownMenuItem<String>(
                                value: unit['id'].toString(),
                                  child: Text(
                                    '${unit['code']} - ${unit['name']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              );
                            }).toList(),
                              onChanged: _onUnitSelected,
                          ),
                  ],
                ),
              ),
            ),

            // Validation Status Card
            if (_selectedUnitId != null)
              Card(
                margin: EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                    children: [
                      Text(
                        'Status Check',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                          ),
                          SizedBox(width: 8),
                          if (_isWithinRadius && _activeSession != null)
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ],
                      ),
                      SizedBox(height: 16),
                      if (isProcessing)
                        Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                              SizedBox(height: 8),
                              Text('Checking unit status...',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _buildStatusItem(
                          icon: _isLocationEnabled ? Icons.check_circle : Icons.location_off,
                          color: _isLocationEnabled ? Colors.green : Colors.orange,
                          title: 'Location Services',
                          message: _isLocationEnabled 
                              ? 'Location services are enabled'
                              : 'Please enable location services',
                        ),
                        Divider(height: 24),
                        _buildStatusItem(
                          icon: _hasLocationPermission ? Icons.check_circle : Icons.location_disabled,
                          color: _hasLocationPermission ? Colors.green : Colors.orange,
                          title: 'Location Permission',
                          message: _hasLocationPermission
                              ? 'Location permission granted'
                              : 'Please grant location permission',
                        ),
                        if (_isLocationEnabled && _hasLocationPermission) ...[
                          Divider(height: 24),
                          _buildStatusItem(
                            icon: _activeSession != null ? Icons.check_circle : Icons.schedule,
                            color: _activeSession != null ? Colors.green : Colors.red,
                            title: 'Class Session',
                            message: _activeSession != null
                                ? 'Active session found'
                                : 'No active session found',
                          ),
                          if (_activeSession != null) ...[
                            Divider(height: 24),
                            _buildStatusItem(
                              icon: _isWithinRadius ? Icons.check_circle : Icons.wrong_location,
                              color: _isWithinRadius ? Colors.green : Colors.red,
                              title: 'Location Check',
                              message: _isWithinRadius
                                  ? 'You are within the class area'
                                  : 'You are too far from class location',
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ),

            if (_errorMessage != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Attendance Methods
            Container(
                                padding: EdgeInsets.all(16),
                                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                            Text(
                    'Choose Attendance Method',
                            style: TextStyle(
                      fontSize: 18,
                              fontWeight: FontWeight.bold,
                      color: Colors.black87,
                            ),
                          ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMethodButton(
                          imagePath: 'assets/images/qrbutton.png',
                          title: 'QR Scan',
                          onTap: _selectedUnitId != null && _activeSession != null && _isWithinRadius
                              ? () => _navigateToQRScanner()
                              : null,
                          isEnabled: _selectedUnitId != null && _activeSession != null && _isWithinRadius,
                          status: _getMethodStatus(),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildMethodButton(
                          imagePath: 'assets/images/backupbtn.png',
                          title: 'Backup Key',
                          onTap: _selectedUnitId != null && _activeSession != null && _isWithinRadius
                              ? () => _navigateToBackupKey()
                                            : null,
                          isEnabled: _selectedUnitId != null && _activeSession != null && _isWithinRadius,
                          status: _getMethodStatus(),
                                                ),
                                              ),
                                            ],
                                    ),
                  // User guide text
                  if (_selectedUnitId == null)  // Only show if no unit is selected
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Please select a unit before proceeding with attendance',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                                  ],
                            ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRegisteredUnits() async {
    try {
      setState(() => _isLoadingUnits = true);

      final user = _supabaseService.getCurrentUser();
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoadingUnits = false;
        });
        return;
      }

      final studentId = user['student_id'];
      if (studentId == null) {
        setState(() {
          _errorMessage = 'Student ID not found';
          _isLoadingUnits = false;
        });
        return;
      }

      // Query both tables for registered units
      final registeredUnitsQuery = await _supabaseService.client
          .from('student_registered_units')
          .select('''
            unit_id,
            units:unit_id (
              id,
              code,
              name
            )
          ''')
          .eq('student_id', studentId);

      final studentUnitsQuery = await _supabaseService.client
          .from('student_units')
          .select('''
            unit_id,
            units:unit_id (
              id,
              code,
              name
            )
          ''')
          .eq('student_id', studentId);

      // Combine and deduplicate units
      final Set<String> addedUnitIds = {};
      final List<Map<String, dynamic>> allUnits = [];

      for (final unit in [...registeredUnitsQuery, ...studentUnitsQuery]) {
        final unitData = unit['units'] as Map<String, dynamic>;
        if (!addedUnitIds.contains(unitData['id'])) {
          addedUnitIds.add(unitData['id']);
          allUnits.add(unitData);
        }
      }

      setState(() {
        _registeredUnits = allUnits;
        _isLoadingUnits = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load registered units';
        _isLoadingUnits = false;
      });
    }
  }

  Future<void> _checkLocationServices() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      setState(() => _isLocationEnabled = serviceEnabled);
      
      if (!serviceEnabled) {
        setState(() => _locationStatus = "Location services are disabled");
      return;
    }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      setState(() {
        _hasLocationPermission = permission == LocationPermission.always || 
                                permission == LocationPermission.whileInUse;
        _locationStatus = _hasLocationPermission ? "Location ready" : "Location permission denied";
      });

      if (_hasLocationPermission) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      setState(() => _locationStatus = "Error: ${e.toString()}");
    }
  }

  Future<void> _refreshStatus() async {
    if (_selectedUnitId == null) return;

    try {
      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() => _isLocationEnabled = serviceEnabled);
      }
      
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Location services are disabled';
          });
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (mounted) {
        setState(() => _hasLocationPermission = permission == LocationPermission.always || 
                                              permission == LocationPermission.whileInUse);
      }

      if (!_hasLocationPermission) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Location permission is required';
          });
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      if (mounted) {
        setState(() => _currentPosition = position);
      }

      // Get active session
      final session = await _attendanceService.getActiveSession(_selectedUnitId!);
      
      if (session == null) {
        if (mounted) {
          setState(() {
            _activeSession = null;
            _errorMessage = 'No active session found for this unit';
          });
        }
        return;
      }

      // Check if within radius
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        session['class_latitude'],
        session['class_longitude'],
      );

      if (mounted) {
        setState(() {
          _activeSession = session;
          _isWithinRadius = distance <= (session['radius_meters'] ?? 50);
          
          if (!_isWithinRadius) {
            _errorMessage = 'You are too far from the class location';
          } else {
            _errorMessage = null;
          }
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _onUnitSelected(String? value) async {
    if (value == null) return;

    try {
      setState(() {
        _selectedUnitId = value;  // Set the selected unit ID
        isProcessing = true;
        _errorMessage = null;
      });

      // Start auto-refresh timer when unit is selected
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        _refreshStatus();
      });

      // Initial check
      await _refreshStatus();

      setState(() {
        isProcessing = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        isProcessing = false;
      });
    }
  }

  Widget _buildStatusItem({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getMethodStatus() {
    if (_selectedUnitId == null) {
      return 'Select a unit';
    }
    if (_activeSession == null) {
      return 'No active session';
    }
    if (!_isLocationEnabled) {
      return 'Enable location';
    }
    if (!_hasLocationPermission) {
      return 'Grant location access';
    }
    if (!_isWithinRadius) {
      return 'Too far from class';
    }
    return 'Ready';
      }

  Future<void> _navigateToQRScanner() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          onQRCodeScanned: (qrData) => _markAttendance(qrData, 'QR_CODE'),
          isWithinRadius: _isWithinRadius,
          activeSession: _activeSession!,
          currentPosition: _currentPosition!,
        ),
      ),
    );
  }

  Future<void> _navigateToBackupKey() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BackupKeyScreen(
          onBackupKeySubmitted: (key) => _markAttendance(key, 'BACKUP_KEY'),
          isWithinRadius: _isWithinRadius,
          activeSession: _activeSession!,
          currentPosition: _currentPosition!,
        ),
      ),
    );
  }

  Widget _buildMethodButton({
    required String imagePath,
    required String title,
    required VoidCallback? onTap,
    required bool isEnabled,
    required String status,
  }) {
    final statusColor = _getStatusColor(status);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main button content
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
              children: [
                  // Icon/Image
                Container(
                    height: 80,
                    width: 80,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                      color: isEnabled ? null : Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isEnabled ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
                ),
            ),
            // Status text at bottom
            if (!isEnabled)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                      ),
                      child: Text(
                  'Select a unit',
                  textAlign: TextAlign.center,
                        style: TextStyle(
                    color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Select a unit':
        return Colors.blue;
      case 'No active session':
        return Colors.red;
      case 'Enable location':
      case 'Grant location access':
        return Colors.orange;
      case 'Too far from class':
        return Colors.red;
      case 'Ready':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _markAttendance(String value, String method) async {
    try {
      if (_currentPosition == null || _activeSession == null) {
        throw Exception('Location or session data not available');
      }

      // Get complete device info including app version and model
      final deviceSecurityInfo = await _deviceSecurity.getDeviceSecurityInfo();
      final deviceInfo = await _deviceSecurity.getDeviceInfo();
      
      print('DEBUG: Device Info from getDeviceInfo: $deviceInfo'); // Debug log
      print('DEBUG: Device Security Info: $deviceSecurityInfo'); // Debug log
      
      // Merge both device info maps and ensure device model is included
      final completeDeviceInfo = {
        ...deviceSecurityInfo,
        'app_version': deviceInfo['app_version'],
        'device_model': deviceInfo['device_model'] ?? 'unknown',
        'model': deviceInfo['device_model'] ?? 'unknown', // Add this line to ensure model is set
        'device_id': deviceInfo['device_id'] ?? deviceSecurityInfo['device_id'] ?? 'unknown',
        'platform': deviceInfo['platform'] ?? Platform.operatingSystem,
        'os_version': deviceInfo['os_version'] ?? Platform.operatingSystemVersion,
      };
      
      print('DEBUG: Complete Device Info: $completeDeviceInfo'); // Debug log
      
      final result = await _attendanceService.markAttendance(
        sessionId: _activeSession!['id'],
        studentId: _supabaseService.getCurrentUser()!['student_id'],
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        markMethod: method,
        markValue: value,
        deviceInfo: completeDeviceInfo,
      );

      if (result['success']) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Success'),
            content: Text(result['message']),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Return to previous screen
                },
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['message'];
          isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error marking attendance: ${e.toString()}';
        isProcessing = false;
      });
    }
  }
} 
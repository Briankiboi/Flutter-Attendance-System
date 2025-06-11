import 'package:flutter/material.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/attendance_service.dart';
import 'package:qr_attendance/services/device_security_service.dart';
import 'dart:io';
import 'dart:async'; // Add timer import
import 'package:geolocator/geolocator.dart';

class BackupKeyScreen extends StatefulWidget {
  final Function(String) onBackupKeySubmitted;
  final bool isWithinRadius;
  final Map<String, dynamic> activeSession;
  final Position currentPosition;

  const BackupKeyScreen({
    Key? key,
    required this.onBackupKeySubmitted,
    required this.isWithinRadius,
    required this.activeSession,
    required this.currentPosition,
  }) : super(key: key);

  @override
  State<BackupKeyScreen> createState() => _BackupKeyScreenState();
}

class _BackupKeyScreenState extends State<BackupKeyScreen> {
  final List<TextEditingController> _controllers = List.generate(11, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(11, (index) => FocusNode());
  final SupabaseService _supabaseService = SupabaseService();
  final AttendanceService _attendanceService = AttendanceService();
  final DeviceSecurityService _deviceSecurity = DeviceSecurityService();
  
  bool _isValidating = false;
  String? _errorMessage;
  bool _hasError = false;
  Timer? _refreshTimer;
  bool _isWithinRadius = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _isWithinRadius = widget.isWithinRadius;
    _currentPosition = widget.currentPosition;
    
    // Start auto-refresh timer
    _refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _refreshLocationAndSession();
    });

    // Add listeners to move focus between boxes
    for (int i = 0; i < 11; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.isNotEmpty) {
          if (i < 10) {
            _focusNodes[i + 1].requestFocus();
          } else {
            _focusNodes[i].unfocus();
            _submitBackupKey();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshLocationAndSession() async {
    try {
      // Get current location
      Position position = await Geolocator.getCurrentPosition();
      
      // Get active session
      final sessionResponse = await _attendanceService.refreshSessionStatus(widget.activeSession['id']);
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isWithinRadius = widget.isWithinRadius; // This will be recalculated based on new position
          
          // If session is no longer active, show error and pop
          if (!sessionResponse['is_active']) {
            _showErrorDialog('This session has ended. Please return to the main screen.');
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      print('Error refreshing status: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance marked successfully!'),
            SizedBox(height: 8),
            Text(
              'Your attendance has been recorded.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to previous screen
            },
          ),
        ],
      ),
    );
  }

  Future<void> _processBackupKey(String key) async {
    try {
      // First verify if the backup key exists
      final verificationResult = await _attendanceService.verifyBackupKey(
        key,
        _supabaseService.getCurrentUser()!['student_id'],
        location: {
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
        },
      );

      if (!verificationResult['success']) {
        setState(() {
          _isValidating = false;
        });
        _showErrorDialog(verificationResult['message']);
        return;
      }

      final deviceSecurityInfo = await _deviceSecurity.getDeviceSecurityInfo();
      final deviceInfo = await _deviceSecurity.getDeviceInfo();
      
      final completeDeviceInfo = {
        ...deviceSecurityInfo,
        'app_version': deviceInfo['app_version'],
        'device_model': deviceInfo['device_model'] ?? 'unknown',
        'model': deviceInfo['device_model'] ?? 'unknown',
        'device_id': deviceInfo['device_id'] ?? deviceSecurityInfo['device_id'] ?? 'unknown',
        'platform': deviceInfo['platform'] ?? Platform.operatingSystem,
        'os_version': deviceInfo['os_version'] ?? Platform.operatingSystemVersion,
      };

      final result = await _attendanceService.markAttendance(
        sessionId: widget.activeSession['id'],
        studentId: _supabaseService.getCurrentUser()!['student_id'],
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        markMethod: 'BACKUP_KEY',
        markValue: key,
        deviceInfo: completeDeviceInfo,
      );

      setState(() {
        _isValidating = false;
      });

      if (result['success']) {
        widget.onBackupKeySubmitted(key);
        _showSuccessDialog();
      } else {
        _showErrorDialog(_getUserFriendlyErrorMessage(result['message']));
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
      });
      _showErrorDialog(_getUserFriendlyErrorMessage(e));
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    if (error.toString().contains('network') || 
        error.toString().contains('connection') ||
        error.toString().contains('socket') ||
        error.toString().contains('timeout')) {
      return 'Unable to connect to server. Please check your internet connection and try again.';
    }
    
    if (error.toString().contains('invalid') || 
        error.toString().contains('expired') ||
        error.toString().contains('not found')) {
      return 'The backup key you entered is incorrect or has expired. Please check and try again.';
    }

    if (error.toString().contains('already marked')) {
      return 'You have already marked attendance for this session.';
    }

    if (error.toString().contains('session ended') || 
        error.toString().contains('session closed')) {
      return 'This session has ended. You can no longer mark attendance.';
    }

    return 'Something went wrong. Please try again later.';
  }

  void _submitBackupKey() async {
    final key = _controllers.map((c) => c.text).join();
    if (key.length != 11) {
      _showErrorDialog('Please enter all digits of the backup key.');
      return;
    }

    if (!_isWithinRadius) {
      _showErrorDialog('You are too far from the class location. Please move closer and try again.');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _hasError = false;
    });

    await _processBackupKey(key);
  }

  Widget _buildKeyBox(int index) {
    return Container(
      width: 40,
      height: 40,
      margin: EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue.shade200, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue.shade200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        maxLength: 1,
        onChanged: (value) {
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Backup Key'),
          backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        ),
        body: Container(
        color: Colors.grey[50],
        padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
            if (!_isWithinRadius)
              Container(
                margin: EdgeInsets.symmetric(vertical: 16),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_off, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You are not within the class area',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 24),
                    padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Enter Backup Key',
                  style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please enter the 11-digit backup key',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 24),
                        // First row of 6 boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) => _buildKeyBox(index)),
                        ),
                        SizedBox(height: 8),
                        // Second row of 5 boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) => _buildKeyBox(index + 6)),
                        ),
                        if (_errorMessage != null)
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        SizedBox(height: 24),
                        // Submit Button
              SizedBox(
                width: double.infinity,
                          height: 48,
                child: ElevatedButton(
                            onPressed: _isValidating ? null : _submitBackupKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                    ),
                              elevation: 2,
                  ),
                            child: _isValidating
                                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                                      SizedBox(width: 12),
                      Text(
                                        'Submitting...',
                        style: TextStyle(
                                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                                  )
                                : Text(
                                    'Submit Key',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }
} 
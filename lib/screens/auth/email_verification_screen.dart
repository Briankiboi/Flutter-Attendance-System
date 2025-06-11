import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:qr_attendance/services/email_service.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Development mode flag
const bool DEV_MODE = true;

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  
  bool _isResendEnabled = false;
  int _resendTimer = 30;
  Timer? _timer;
  bool _isLoading = false;
  
  // User data that will be passed to dashboard
  late Map<String, dynamic> _userData = {};
  bool _isFromLogin = false;
  
  // Create an instance of SupabaseService
  final _supabaseService = SupabaseService();
  
  // Add a subscription to monitor connectivity changes
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _hasConnectivity = true;
  
  final String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _setupConnectivityMonitor();
  }
  
  void _setupConnectivityMonitor() {
    _checkConnectivity();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      setState(() {
        _hasConnectivity = result != ConnectivityResult.none;
      });
      
      if (_hasConnectivity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Internet connection restored'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No internet connection. Email verification may not work.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }
  
  Future<void> _checkConnectivity() async {
    var result = await Connectivity().checkConnectivity();
    setState(() {
      _hasConnectivity = result != ConnectivityResult.none;
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get arguments passed from previous screen
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _userData = args;
      _isFromLogin = args['isFromLogin'] ?? false;
      
      // Send verification email when screen loads
      _sendVerificationEmail();
    }
  }
  
  // Send verification email using our email service
  Future<void> _sendVerificationEmail() async {
    if (_userData.containsKey('email') && _userData.containsKey('name')) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Check connectivity first
        await _checkConnectivity();
        if (!_hasConnectivity) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No internet connection. Please connect to the internet and try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        final success = await EmailService.sendVerificationEmail(
          _userData['email'],
          _userData['name']
        );
        
        if (!mounted) return;
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification code sent to your email'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showErrorDialog(
            'Failed to send verification code',
            'We could not send the verification email. Please check your email address or network connection and try again.'
          );
        }
      } catch (e) {
        print('Error sending verification email: $e');
        if (!mounted) return;
        _showErrorDialog(
          'Error', 
          'An error occurred while sending the verification email: $e'
        );
      } finally {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  void _startResendTimer() {
    if (!mounted) return;
    setState(() {
      _isResendEnabled = false;
      _resendTimer = 30;
    });
    
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _isResendEnabled = true;
          _timer?.cancel();
        }
      });
    });
  }
  
  void _verifyCode() async {
    // Get the entered code
    String enteredCode = '';
    for (var controller in _controllers) {
      enteredCode += controller.text;
    }
    
    if (enteredCode.length == 4) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        String email = _userData['email'].toString();
        bool isLecturer = email.endsWith('@tharaka.ac.ke');
        bool isFromLogin = _userData['isFromLogin'] ?? false;
        
        print('Verifying code for ${isLecturer ? "lecturer" : "student"} ${isFromLogin ? "login" : "signup"}');
        
        if (DEV_MODE) {
          print('DEV MODE: Accepting any 4 digits for verification');
          
          // For lecturers in dev mode, just navigate to dashboard
          if (isLecturer) {
            if (!mounted) return;
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Verification successful'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Navigate to lecturer dashboard with user data
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.lecturerDashboard,
              (route) => false,
              arguments: {
                'email': email,
                'name': _userData['name'],
                'department': _userData['department'],
                'occupation': _userData['occupation'],
                'employmentType': _userData['employmentType'],
                'gender': _userData['gender'],
              },
            );
            return;
          }
          
          // For students, use existing logic
          bool success = await _supabaseService.setCurrentUser(
            email,
            _userData['name'],
            isLecturer: false,
          );
          
          if (!success) {
            throw Exception('Failed to set current user');
          }
          
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.studentDashboard,
            (route) => false,
          );
          return;
        }
        
        // Production mode verification logic here
        // ... existing code for production verification ...
      } catch (e) {
        print('Verification error: $e');
        setState(() {
          _isLoading = false;
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _resendCode() async {
    if (_isResendEnabled) {
      setState(() {
        _isLoading = true;
      });
      
      // Check connectivity first
      await _checkConnectivity();
      if (!_hasConnectivity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No internet connection. Please connect to the internet and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      try {
        // Resend verification email using our email service
        final success = await EmailService.resendVerificationEmail(
          _userData['email'],
          _userData['name']
        );
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification code resent to your email'),
              backgroundColor: Colors.green,
            ),
          );
          _startResendTimer();
        } else {
          _showErrorDialog(
            'Failed to Resend Code',
            'We could not resend the verification code. Please check your email address and try again.'
          );
        }
      } catch (e) {
        print('Error resending verification code: $e');
        _showErrorDialog(
          'Error',
          'An error occurred while resending the verification code: $e'
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Email Verification'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 80,
                          color: Colors.blue,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Verify Your Email',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          _isFromLogin 
                              ? 'Please enter the verification code sent to your email to continue to your dashboard.'
                              : 'We\'ve sent a 4-digit code to your email. Please enter it below to verify your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (DEV_MODE)
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 10),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'DEVELOPMENT MODE: Enter any 4 digits to continue. Email verification is skipped.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!_hasConnectivity)
                          Container(
                            margin: EdgeInsets.only(top: 10),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.signal_wifi_off, color: Colors.red),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No internet connection. Please connect to receive the verification email.',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) {
                            return SizedBox(
                              width: 60,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                decoration: InputDecoration(
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    // Move to next field
                                    if (index < 3) {
                                      _focusNodes[index + 1].requestFocus();
                                    } else {
                                      // Last digit entered, verify code
                                      _focusNodes[index].unfocus();
                                      _verifyCode();
                                    }
                                  } else if (value.isEmpty && index > 0) {
                                    // Move to previous field on backspace
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'Verify',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        SizedBox(height: 20),
                        TextButton(
                          onPressed: _isResendEnabled ? _resendCode : null,
                          child: Text(
                            _isResendEnabled
                                ? 'Resend Code'
                                : 'Resend Code in $_resendTimer seconds',
                            style: TextStyle(
                              color: _isResendEnabled ? Colors.blue : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Email: ${_userData['email'] ?? ""}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 
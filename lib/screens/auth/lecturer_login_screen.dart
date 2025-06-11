import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/connectivity_service.dart';
import 'package:qr_attendance/widgets/connectivity_message.dart';
import 'dart:async';

class LecturerLoginScreen extends StatefulWidget {
  const LecturerLoginScreen({super.key});

  @override
  _LecturerLoginScreenState createState() => _LecturerLoginScreenState();
}

class _LecturerLoginScreenState extends State<LecturerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _hasInternet = true;
  String _errorMessage = '';
  
  final _supabaseService = SupabaseService();
  
  late final ConnectivityService _connectivityService;
  NetworkStatus _networkStatus = NetworkStatus.online;
  StreamSubscription? _connectivitySubscription;
  
  @override
  void initState() {
    super.initState();
    _connectivityService = ConnectivityService();
    _setupConnectivity();
    
    // Force lowercase for email input
    _emailController.addListener(() {
      final text = _emailController.text;
      final lowercase = text.toLowerCase();
      if (text != lowercase) {
        _emailController.value = TextEditingValue(
          text: lowercase,
          selection: TextSelection.collapsed(offset: lowercase.length),
        );
      }
    });
  }

  Future<void> _setupConnectivity() async {
    await _connectivityService.initialize();
    _connectivitySubscription = _connectivityService.statusStream.listen((status) {
      setState(() {
        _networkStatus = status;
        _hasInternet = status == NetworkStatus.online;
      });
    });
  }
  
  bool _isSchoolEmail(String email) {
    return email.endsWith('@tharaka.ac.ke');
  }

  Future<void> _login() async {
    if (!_hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No internet connection. Please check your WiFi or mobile data.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        
        final result = await _supabaseService.lecturerLogin(email, password);
        
        if (!mounted) return;
        
        if (!result['success']) {
          setState(() {
            // More user-friendly error messages
            if (result['message'].contains('Invalid credentials')) {
              _errorMessage = 'The email or password you entered is incorrect. Please try again.';
            } else if (result['message'].contains('Lecturer profile not found')) {
              _errorMessage = 'We couldn\'t find your lecturer account. Please make sure you\'re using the correct email.';
            } else {
              _errorMessage = 'Something went wrong. Please try again in a few minutes.';
            }
            _isLoading = false;
          });
          return;
        }
        
        final userData = result['userData'];
        print('Login successful for user: ${userData['name']}');
        
        setState(() {
          _isLoading = false;
        });
        
        Navigator.pushNamed(
          context,
          AppRoutes.emailVerification,
          arguments: {
            'email': email,
            'name': userData['name'],
            'password': password,
            'department': userData['department'],
            'occupation': userData['occupation'],
            'employmentType': userData['employmentType'],
            'gender': userData['gender'],
            'isFromLogin': true,
          },
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lecturer Login'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 20),
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Network Status Indicator
                            if (_networkStatus != NetworkStatus.online)
                              Container(
                                margin: EdgeInsets.only(bottom: 16),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _networkStatus == NetworkStatus.offline 
                                    ? Colors.red.shade50 
                                    : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _networkStatus == NetworkStatus.offline 
                                        ? Icons.wifi_off 
                                        : Icons.signal_wifi_bad,
                                      color: _networkStatus == NetworkStatus.offline 
                                        ? Colors.red 
                                        : Colors.orange,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _networkStatus == NetworkStatus.offline
                                          ? 'No internet connection'
                                          : 'Weak internet connection',
                                        style: TextStyle(
                                          color: _networkStatus == NetworkStatus.offline 
                                            ? Colors.red 
                                            : Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.email),
                                hintText: 'username@tharaka.ac.ke',
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!_isSchoolEmail(value)) {
                                  return 'Please use your @tharaka.ac.ke email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            
                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.lecturerResetPassword);
                              },
                              child: Text('Forgot Password?'),
                            ),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Don't have an account? "),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.lecturerSignup,
                                    );
                                  },
                                  child: Text('Sign Up'),
                                ),
                              ],
                            ),
                          ],
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
    _emailController.dispose();
    _passwordController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
} 
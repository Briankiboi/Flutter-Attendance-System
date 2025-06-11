
import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/connectivity_service.dart';
import 'package:qr_attendance/widgets/connectivity_message.dart';
import 'dart:async';

// Define expected year and semester for demonstration
const String expectedYear = '4';
const String expectedSemester = '2';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      if (mounted) {
        setState(() {
          _networkStatus = status;
          _hasInternet = status == NetworkStatus.online;
        });
        
        // Show appropriate message when connectivity changes
        if (status != NetworkStatus.online) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getConnectivityMessage()),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Internet connection restored'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  bool _isSchoolEmail(String email) {
    // This is a simple check. In a real app, you'd validate against your school's domain
    return email.endsWith('.edu') || email.endsWith('.ac.ke');
  }

  String _getConnectivityMessage() {
    switch (_networkStatus) {
      case NetworkStatus.offline:
        return 'No internet connection. Please check your Wi-Fi or mobile data.';
      case NetworkStatus.slow:
        return 'Your internet connection is slow or unstable. Some features may not work properly.';
      case NetworkStatus.noData:
        return 'You\'re connected, but there\'s no data. Please check your data plan or network settings.';
      default:
        return 'Connection error. Please try again.';
    }
  }

  void _login() async {
    if (_networkStatus != NetworkStatus.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getConnectivityMessage()),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              if (_networkStatus == NetworkStatus.online) {
                _login();
              }
            },
          ),
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
        final String email = _emailController.text.trim();
        final String password = _passwordController.text.trim();
        
        final result = await _supabaseService.studentDirectLogin(email, password);
        
        if (!mounted) return;
        
        if (!result['success']) {
          setState(() {
            _errorMessage = result['message'];
            _isLoading = false;
          });
          
          // Show error in snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login failed. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _login();
                },
              ),
            ),
          );
          return;
        }
        
        final userData = result['userData'];
        print('Login successful for user: ${userData['name']}');
        setState(() {
          _isLoading = false;
        });

        // Ensure year and semester are handled as numeric values
        String studentYear = userData['year']?.toString() ?? "";
        String studentSemester = userData['semester']?.toString() ?? "";

        studentYear = studentYear.replaceAll(RegExp(r'\D'), '');
        studentSemester = studentSemester.replaceAll(RegExp(r'\D'), '');

        // Use numeric values for comparison
        bool yearMatch = studentYear == expectedYear;
        bool semesterMatch = studentSemester == expectedSemester;

        // Navigate to verification page with user data
        Navigator.pushNamed(
          context,
          AppRoutes.emailVerification,
          arguments: {
            'email': email,
            'name': userData['name'],
            'password': userData['password'],
            'department': userData['department'],
            'course': userData['course'],
            'year': userData['year'],
            'semester': userData['semester'],
            'isFromLogin': true,
          },
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
          _isLoading = false;
        });
        
        // Show error in snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error. Please check your connection and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _login();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Login'),
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
                    'Student Login',
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
                            if (_networkStatus != NetworkStatus.online)
                              Container(
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.symmetric(vertical: 16),
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
                                    Icon(Icons.wifi_off, color: Colors.red),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getConnectivityMessage(),
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'School Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                            prefixIcon: Icon(Icons.email),
                                hintText: 'username@student.thara.ac.ke',
                                filled: true,
                                fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!_isSchoolEmail(value)) {
                                  return 'Please use your @student.thara.ac.ke email';
                            }
                            return null;
                          },
                        ),
                            SizedBox(height: 16),
                            
                        TextFormField(
                          controller: _passwordController,
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
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                            
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, AppRoutes.studentResetPassword);
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                            
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
                            
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Don\'t have an account?'),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.studentSignup);
                              },
                              child: Text(
                                'Signup here',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
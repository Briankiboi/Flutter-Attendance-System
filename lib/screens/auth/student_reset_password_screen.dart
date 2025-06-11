import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:qr_attendance/services/connectivity_service.dart';
import 'package:qr_attendance/widgets/connectivity_message.dart';
import 'dart:async';

class StudentResetPasswordScreen extends StatefulWidget {
  const StudentResetPasswordScreen({super.key});

  @override
  _StudentResetPasswordScreenState createState() => _StudentResetPasswordScreenState();
}

class _StudentResetPasswordScreenState extends State<StudentResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    return email.endsWith('@student.tharaka.ac.ke');
  }

  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasNumbers = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUppercase && hasLowercase && hasNumbers && hasSpecialCharacters;
  }

  String _getPasswordStrength(String password) {
    if (password.isEmpty) return '';
    if (password.length < 8) return 'Weak';
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasNumbers = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    int strength = 0;
    if (hasUppercase) strength++;
    if (hasLowercase) strength++;
    if (hasNumbers) strength++;
    if (hasSpecialCharacters) strength++;
    
    if (strength == 4) return 'Strong';
    if (strength >= 2) return 'Medium';
    return 'Weak';
  }

  Color _getPasswordStrengthColor(String strength) {
    switch (strength) {
      case 'Strong':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'Weak':
        return Colors.red;
      default:
        return Colors.transparent;
    }
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

  Future<void> _resetPassword() async {
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
                _resetPassword();
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
        final String newPassword = _passwordController.text.trim();

        // Reset the password directly
        final result = await _supabaseService.resetStudentPassword(
          email,
          newPassword,
        );

        if (!mounted) return;

        if (result['success']) {
          setState(() {
            _isLoading = false;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password reset successful'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate back to login
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to reset password';
            _isLoading = false;
          });
          
          // Show error in snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to reset password'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  _resetPassword();
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Network error. Please check your connection and try again.';
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
                _resetPassword();
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
        title: Text('Reset Password'),
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
                    'Reset Password',
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
                              ConnectivityMessage(
                                type: _networkStatus == NetworkStatus.offline 
                                  ? 'no_connection' 
                                  : _networkStatus == NetworkStatus.slow 
                                    ? 'slow' 
                                    : 'no_data',
                                isConnected: false,
                              ),
                            
                            Text(
                              'Enter your school email and new password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 20),
                            
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'School Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.email),
                                hintText: 'username@student.tharaka.ac.ke',
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!_isSchoolEmail(value)) {
                                  return 'Please use your @student.tharaka.ac.ke email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'New Password',
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
                                  return 'Please enter a new password';
                                }
                                if (!_isPasswordStrong(value)) {
                                  return 'Password must have uppercase, lowercase, number, and special character';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setState(() {}); // Trigger rebuild for strength indicator
                              },
                            ),
                            if (_passwordController.text.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      'Password Strength: ',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      _getPasswordStrength(_passwordController.text),
                                      style: TextStyle(
                                        color: _getPasswordStrengthColor(
                                          _getPasswordStrength(_passwordController.text),
                                        ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your new password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
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
                                onPressed: _isLoading ? null : _resetPassword,
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
                                      'Reset Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Remember your password? ',
                                  style: TextStyle(fontSize: 14),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                                  },
                                  child: Text(
                                    'Back to Login',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
    _confirmPasswordController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
} 
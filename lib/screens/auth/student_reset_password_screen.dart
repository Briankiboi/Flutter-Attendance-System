import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StudentResetPasswordScreen extends StatefulWidget {
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
  
  bool _isSchoolEmail(String email) {
    return email.endsWith('.edu') || email.endsWith('.ac.ke');
  }

  void _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_emailController.text);
      if (userDataString == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No account found with this email'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final userData = json.decode(userDataString) as Map<String, dynamic>;
      userData['password'] = _passwordController.text;
      await prefs.setString(_emailController.text, json.encode(userData));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset successful!'),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      });
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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: 10),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 10),
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
                            hintText: 'e.g., admission_no@student.tharaka.ac.ke',
                            prefixIcon: Icon(Icons.email),
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!_isSchoolEmail(value)) {
                              return 'Please use a valid school email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(Icons.lock),
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a new password';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_outline),
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
                          ),
                          obscureText: _obscureConfirmPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: Text('Reset Password'),
                          ),
                        ),
                        SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Remember your password?'),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, AppRoutes.login);
                              },
                              child: Text(
                                'Back to Login',
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
    super.dispose();
  }
} 
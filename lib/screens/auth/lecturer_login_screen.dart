import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const String lectureNumberFormat = 'LCxxxx';

class LecturerLoginScreen extends StatefulWidget {
  @override
  _LecturerLoginScreenState createState() => _LecturerLoginScreenState();
}

class _LecturerLoginScreenState extends State<LecturerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lectureNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  void _login() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      Future.delayed(Duration(seconds: 1), () async {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString(_lectureNumberController.text);
        
        if (userDataString == null) {
          setState(() {
            _errorMessage = 'No account found with this lecture number';
            _isLoading = false;
          });
          return;
        }
        
        final userData = json.decode(userDataString) as Map<String, dynamic>;
        
        if (userData['password'] != _passwordController.text) {
          setState(() {
            _errorMessage = 'Incorrect password';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _isLoading = false;
        });

        Navigator.pushNamed(context, AppRoutes.lecturerDashboard, arguments: {
          'lectureNumber': _lectureNumberController.text,
          'name': userData['name'],
          'department': userData['department'],
          'course': userData['course'],
          'occupation': userData['occupation'],
          'employmentType': userData['employmentType'],
          'gender': userData['gender'],
        });
      });
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
              child: Card(
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
                        Text(
                          'Lecturer Login',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 20),
                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(10),
                            margin: EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextFormField(
                          controller: _lectureNumberController,
                          decoration: InputDecoration(
                            labelText: 'Lecture Number ($lectureNumberFormat)',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your lecture number';
                            }
                            if (!RegExp(r'^LC\d{4}').hasMatch(value)) {
                              return 'Lecture number must be in the format $lectureNumberFormat';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 15),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
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
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 15),
                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Login'),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.lecturerResetPassword);
                              },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(' | '),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.lecturerSignup);
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lectureNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 
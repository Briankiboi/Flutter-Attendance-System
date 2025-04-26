import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Define expected year and semester for demonstration
const String expectedYear = '4';
const String expectedSemester = '2';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  bool _isSchoolEmail(String email) {
    // This is a simple check. In a real app, you'd validate against your school's domain
    return email.endsWith('.edu') || email.endsWith('.ac.ke');
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      // Simulate credential check (in a real app, this would check against a database)
      Future.delayed(Duration(seconds: 1), () async {
        try {
          // Get SharedPreferences instance
          final prefs = await SharedPreferences.getInstance();
          
          // Clean up the email to ensure consistent lookup
          final String email = _emailController.text.trim();
          
          // Check if the user is trying to log in to a different account
          final currentUserEmail = prefs.getString('current_user_email') ?? prefs.getString('currentUser');
          if (currentUserEmail != null && currentUserEmail != email) {
            print('Detected login attempt to different account: $email (current: $currentUserEmail)');
            
            // Clear any stored dashboard state for the previous user
            await prefs.remove('current_profile_loaded');
            await prefs.remove('current_timetable_loaded');
          }
          
          // Retrieve stored user data
          final userDataString = prefs.getString(email);
          
          // Debugging: Print retrieved data
          print('Retrieved user data for email $email: ${userDataString ?? 'No data found'}');
          
          if (userDataString == null) {
            // Email not found
            setState(() {
              _errorMessage = 'No account found with this email';
              _isLoading = false;
            });
            return;
          }
          
          // Parse user data
          final userData = json.decode(userDataString) as Map<String, dynamic>;
          
          // Handle potential null or missing password
          final storedPassword = userData['password'];
          final enteredPassword = _passwordController.text.trim();
          
          // Debug password comparison
          print('Stored password: ${storedPassword ?? 'MISSING'}');
          print('Entered password: $enteredPassword');
          
          // Check if password matches - handle null case
          if (storedPassword == null) {
            print('WARNING: Stored password is null - will need to reset password');
            setState(() {
              _errorMessage = 'Account recovery needed. Please use password reset.';
              _isLoading = false;
            });
            return;
          }
          
          if (storedPassword.toString().trim() != enteredPassword) {
            setState(() {
              _errorMessage = 'Incorrect password';
              _isLoading = false;
            });
            return;
          }

          // Login successful
          print('Login successful for user: ${userData['name']}');
          setState(() {
            _isLoading = false;
          });

          // Pre-store login status before verification
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('currentUser', email);
          await prefs.setString('current_user_email', email);

          // Ensure year and semester are handled as numeric values
          String studentYear = userData['year']?.toString() ?? "";
          String studentSemester = userData['semester']?.toString() ?? "";

          studentYear = studentYear.replaceAll(RegExp(r'\D'), '');
          studentSemester = studentSemester.replaceAll(RegExp(r'\D'), '');

          // Use numeric values for comparison
          bool yearMatch = studentYear == expectedYear;
          bool semesterMatch = studentSemester == expectedSemester;
          
          // Update any missing fields in the user data
          final updatedUserData = {
            'name': userData['name'] ?? '',
            'email': email,
            'password': storedPassword,
            'department': userData['department'] ?? '',
            'course': userData['course'] ?? '',
            'year': userData['year'] ?? '',
            'semester': userData['semester'] ?? '',
            'lastLogin': DateTime.now().toIso8601String(),
          };
          
          // Save updated user data
          await prefs.setString(email, json.encode(updatedUserData));
          
          // Also update current user data
          await prefs.setString('current_user_name', updatedUserData['name']);
          await prefs.setString('current_user_department', updatedUserData['department']);
          await prefs.setString('current_user_course', updatedUserData['course']);
          await prefs.setString('current_user_year', updatedUserData['year']);
          await prefs.setString('current_user_semester', updatedUserData['semester']);

          // Navigate to verification page with user data
          Navigator.pushNamed(context, AppRoutes.emailVerification, arguments: {
            'email': email,
            'name': userData['name'],
            'password': storedPassword, // Include password to ensure it's preserved
            'department': userData['department'],
            'course': userData['course'],
            'year': userData['year'],
            'semester': userData['semester'],
            'isFromLogin': true,
          });
        } catch (e) {
          print('Error during login: $e');
          setState(() {
            _errorMessage = 'An error occurred. Please try again.';
            _isLoading = false;
          });
        }
      });
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
                          'Welcome Back!',
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
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'School Email',
                            hintText: 'e.g., admission_no@student.tharaka.ac.ke',
                            prefixIcon: Icon(Icons.email),
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
                        SizedBox(height: 20),
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
    super.dispose();
  }
} 
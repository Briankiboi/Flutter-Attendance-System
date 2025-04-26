import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';

class RoleSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get screen width to make circles responsive
    double screenWidth = MediaQuery.of(context).size.width;
    double circleSize = screenWidth * 0.6; // 60% of screen width
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 40),
              // App Title
              Text(
                'QR Attendance ',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 10),
              Text(
                ' Tharaka university App',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue.shade600,
                ),
              ),
              // Main content with role buttons
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRoleButton(
                        context, 
                        'Login as Student', 
                        AppRoutes.login, 
                        circleSize,
                        Colors.blue.shade900,
                        Colors.blue.shade700,
                      ),
                      SizedBox(height: 40),
                      _buildRoleButton(
                        context, 
                        'Login as Lecturer', 
                        AppRoutes.lecturerLogin, 
                        circleSize,
                        Colors.indigo.shade900,
                        Colors.indigo.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  '© 2025  Ict dept (Brian_Kiboi solutions)',
                  style: TextStyle(
                    color: Colors.blue.shade800.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context, 
    String text, 
    String route, 
    double size,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [secondaryColor, primaryColor],
            center: Alignment(0.1, 0.1),
            focal: Alignment(0.1, 0.1),
            radius: 0.8,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 2,
              offset: Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.8),
            width: 4,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black38,
                blurRadius: 3,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
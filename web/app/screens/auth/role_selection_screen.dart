import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate responsive sizes
    double circleSize = screenWidth > 800 
        ? 300  // Desktop size
        : screenWidth > 600 
            ? screenWidth * 0.35  // Tablet size
            : screenWidth * 0.45;  // Mobile size
    
    // Calculate spacing based on screen height
    double topSpacing = screenHeight * 0.08;
    double buttonSpacing = screenHeight * 0.05;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: topSpacing),
                  // App Title
                  Text(
                    'Attendance App',
                    style: TextStyle(
                      fontSize: screenWidth > 600 ? 40 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hello user 👋❤️',
                    style: TextStyle(
                      fontSize: screenWidth > 600 ? 20 : 16,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  SizedBox(height: buttonSpacing * 2),
                  // Role selection buttons in a responsive layout
                  screenWidth > 800 
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildRoleButton(
                              context, 
                              'Login as Student', 
                              '/student-login', 
                              circleSize,
                              Colors.blue.shade900,
                              Colors.blue.shade700,
                            ),
                            SizedBox(width: screenWidth * 0.05),
                            _buildRoleButton(
                              context, 
                              'Login as Lecturer', 
                              '/lecturer-login', 
                              circleSize,
                              Colors.indigo.shade900,
                              Colors.indigo.shade700,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildRoleButton(
                              context, 
                              'Login as Student', 
                              '/student-login', 
                              circleSize,
                              Colors.blue.shade900,
                              Colors.blue.shade700,
                            ),
                            SizedBox(height: buttonSpacing),
                            _buildRoleButton(
                              context, 
                              'Login as Lecturer', 
                              '/lecturer-login', 
                              circleSize,
                              Colors.indigo.shade900,
                              Colors.indigo.shade700,
                            ),
                          ],
                        ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      '© 2025 All rights reserved',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
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

  Widget _buildRoleButton(
    BuildContext context, 
    String text, 
    String route, 
    double size,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [secondaryColor, primaryColor],
              center: const Alignment(0.1, 0.1),
              focal: const Alignment(0.1, 0.1),
              radius: 0.8,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 4,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 3,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 
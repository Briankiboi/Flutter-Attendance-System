import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    print('SplashScreen - initState called');
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    _controller.forward();
    _navigateToNext();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 10));
    print('SplashScreen - navigation delay completed');
    if (mounted) {
      print('SplashScreen - navigating to role selection');
      Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('SplashScreen - build method called');
    return Scaffold(
      backgroundColor: Colors.blue,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 5,
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading logo: $error');
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code,
                            size: 70,
                            color: Colors.blue,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'QR Code Attendance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3.0,
                          color: Color.fromARGB(150, 0, 0, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tharaka University App',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 45,
                    height: 45,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 4,
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 
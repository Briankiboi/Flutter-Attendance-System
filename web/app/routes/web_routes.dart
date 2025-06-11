import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/lecturer/lecturer_dashboard.dart';

final GoRouter webRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/student-login',
      builder: (context, state) => const LoginScreen(isStudent: true),
    ),
    GoRoute(
      path: '/lecturer-login',
      builder: (context, state) => const LoginScreen(isStudent: false),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/student-dashboard',
      builder: (context, state) => const StudentDashboard(),
    ),
    GoRoute(
      path: '/lecturer-dashboard',
      builder: (context, state) => const LecturerDashboard(),
    ),
  ],
); 
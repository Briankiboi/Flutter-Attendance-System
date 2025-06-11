import 'package:flutter/material.dart';
import 'package:qr_attendance/screens/auth/login_screen.dart';
import 'package:qr_attendance/screens/auth/lecturer_login_screen.dart';
import 'package:qr_attendance/screens/auth/lecturer_signup_screen.dart';
import 'package:qr_attendance/screens/auth/lecturer_reset_password_screen.dart';
import 'package:qr_attendance/screens/lecturer/lecturer_dashboard_screen.dart';
import 'package:qr_attendance/screens/splash/splash_screen.dart';
import 'package:qr_attendance/screens/auth/role_selection_screen.dart';
import 'package:qr_attendance/screens/auth/student_signup_screen.dart';
import 'package:qr_attendance/screens/auth/email_verification_screen.dart';
import 'package:qr_attendance/screens/student/student_dashboard_screen.dart';
import 'package:qr_attendance/screens/lecturer/create_page.dart';
import 'package:qr_attendance/screens/lecturer/register_unit_page.dart';
import 'package:qr_attendance/screens/lecturer/history_page.dart';
import 'package:qr_attendance/screens/lecturer/timeline_page.dart';
import 'package:qr_attendance/screens/student/view_page.dart';
import 'package:qr_attendance/screens/auth/student_reset_password_screen.dart';
import 'package:qr_attendance/screens/student/student_timetable_page.dart';
import 'package:qr_attendance/screens/lecturer/update_lecturer_details_screen.dart';
import 'package:qr_attendance/screens/lecturer/pin_location_page.dart';
import 'package:qr_attendance/screens/lecturer/analysis_page.dart';

// New imports for student dashboard pages
import 'package:qr_attendance/screens/student/scan_qr_page.dart';
import 'package:qr_attendance/screens/student/evaluate_lecture_page.dart';
import 'package:qr_attendance/screens/student/past_papers_page.dart';
import 'package:qr_attendance/screens/student/register_units_page.dart';
import 'package:qr_attendance/screens/student/results_cat_page.dart';
import 'package:qr_attendance/screens/student/exam_card_page.dart';
import 'package:qr_attendance/screens/student/schedules_page.dart';
import 'package:qr_attendance/screens/student/notifications_page.dart';
import 'package:qr_attendance/screens/student/trends_page.dart';
import 'package:qr_attendance/screens/student/get_in_touch_page.dart';
import 'package:qr_attendance/screens/student/update_details_page.dart';

// New imports for lecturer dashboard pages
import 'package:qr_attendance/screens/lecturer/manual_entry_page.dart';
import 'package:qr_attendance/screens/lecturer/get_assigned_units_page.dart';
import 'package:qr_attendance/screens/lecturer/lecturer_schedules_page.dart';
import 'package:qr_attendance/screens/lecturer/lecturer_notifications_page.dart';
import 'package:qr_attendance/screens/lecturer/cat_marks_entry_page.dart';

class AppRoutes {
  static const String loading = '/';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String lecturerLogin = '/lecturer-login';
  static const String lecturerSignup = '/lecturer-signup';
  static const String lecturerResetPassword = '/lecturer-reset-password';
  static const String lecturerDashboard = '/lecturer-dashboard';
  static const String studentSignup = '/student-signup';
  static const String emailVerification = '/email-verification';
  static const String studentDashboard = '/student-dashboard';
  static const String createPage = '/create';
  static const String registerUnitPage = '/registerUnit';
  static const String historyPage = '/history';
  static const String timelinePage = '/timeline';
  static const String viewPage = '/view';
  static const String studentResetPassword = '/student-reset-password';
  static const String studentTimetablePage = '/student-timetable';
  static const String updateLecturerDetails = '/update-lecturer-details';
  
  // New routes for student dashboard pages
  static const String scanQRPage = '/scan-qr';
  static const String evaluateLecturePage = '/evaluate-lecture';
  static const String pastPapersPage = '/past-papers';
  static const String registerUnitsPage = '/register-units';
  static const String resultsCATPage = '/results-cat';
  static const String examCardPage = '/exam-card';
  static const String schedulesPage = '/schedules';
  static const String notificationsPage = '/notifications';
  static const String trendsPage = '/trends';
  static const String getInTouchPage = '/get-in-touch';
  static const String updateDetailsPage = '/update-details';
  
  // New routes for lecturer dashboard pages
  static const String manualEntryPage = '/manual-entry';
  static const String getAssignedUnitsPage = '/get-assigned-units';
  static const String lecturerSchedulesPage = '/lecturer-schedules';
  static const String lecturerNotificationsPage = '/lecturer-notifications';
  static const String catMarksEntryPage = '/cat-marks-entry';
  static const String pinLocationPage = '/pin-location';
  static const String analysisPage = '/analysis';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      loading: (context) => SplashScreen(),
      roleSelection: (context) => RoleSelectionScreen(),
      login: (context) => LoginScreen(),
      lecturerLogin: (context) => LecturerLoginScreen(),
      lecturerSignup: (context) => LecturerSignupScreen(),
      lecturerResetPassword: (context) => LecturerResetPasswordScreen(),
      lecturerDashboard: (context) => const LecturerDashboardScreen(),
      studentSignup: (context) => StudentSignupScreen(),
      emailVerification: (context) => EmailVerificationScreen(),
      studentDashboard: (context) => StudentDashboardScreen(),
      createPage: (context) => CreateQRCodePage(),
      registerUnitPage: (context) => RegisterUnitPage(),
      historyPage: (context) => HistoryPage(),
      timelinePage: (context) => TimelinePage(),
      viewPage: (context) => ViewPage(),
      studentResetPassword: (context) => StudentResetPasswordScreen(),
      studentTimetablePage: (context) => StudentTimetablePage(),
      updateLecturerDetails: (context) => const UpdateLecturerDetailsScreen(),
      
      // New route handlers for student dashboard pages
      scanQRPage: (context) => ScanQRPage(),
      evaluateLecturePage: (context) => EvaluateLecturePage(),
      pastPapersPage: (context) => PastPapersPage(),
      registerUnitsPage: (context) => RegisterUnitsPage(),
      resultsCATPage: (context) => ResultsCATPage(),
      examCardPage: (context) => ExamCardPage(),
      schedulesPage: (context) => SchedulesPage(),
      notificationsPage: (context) => NotificationsPage(),
      trendsPage: (context) => TrendsPage(),
      getInTouchPage: (context) => GetInTouchPage(),
      updateDetailsPage: (context) => UpdateDetailsPage(),
      
      // New route handlers for lecturer dashboard pages
      manualEntryPage: (context) => ManualEntryPage(),
      getAssignedUnitsPage: (context) => GetAssignedUnitsPage(),
      lecturerSchedulesPage: (context) => LecturerSchedulesPage(),
      lecturerNotificationsPage: (context) => LecturerNotificationsPage(),
      catMarksEntryPage: (context) => CatMarksEntryPage(),
      pinLocationPage: (context) => PinLocationPage(),
      analysisPage: (context) => AnalysisPage(),
    };
  }
} 
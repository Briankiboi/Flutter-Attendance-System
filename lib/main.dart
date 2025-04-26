import 'package:flutter/material.dart';
import 'package:qr_attendance/routes/app_routes.dart';
// import 'package:firebase_core/firebase_core.dart';  // Comment out for now

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Skip Firebase initialization for now to allow testing
  // TODO: Uncomment this when implementing Firebase
  // await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      initialRoute: AppRoutes.loading,
      routes: AppRoutes.getRoutes(),
    );
  }
}

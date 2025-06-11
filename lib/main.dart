import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'routes/app_routes.dart';
import 'services/supabase_init.dart';
import 'config/env_config.dart';
import 'config/env_test.dart'; // Import the test screen
// import 'package:firebase_core/firebase_core.dart';  // Comment out for now

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await EnvConfig.load();
  
  // Initialize Supabase
  await initializeSupabase();
  
  // Skip Firebase initialization for now to allow testing
  // TODO: Uncomment this when implementing Firebase
  // await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      // Add this route for testing env variables
      routes: {
        ...AppRoutes.getRoutes(),
        '/env-test': (context) => const EnvTestScreen(),
      },
      initialRoute: AppRoutes.loading, // Change to use the splash screen
      // Once tested, change back to: initialRoute: AppRoutes.loading,
    );
  }
}

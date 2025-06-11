import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: ".env");
      print('Environment variables loaded successfully');
    } catch (e) {
      print('Error loading environment variables: $e');
      // Using default values in getters below
    }
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? 'https://vaaqnexxyzzmjwquhpry.supabase.co';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhYXFuZXh4eXp6bWp3cXVocHJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY0MjYyMjgsImV4cCI6MjA2MjAwMjIyOH0.SVPotafYY4VtdxQvIrDITp4VkInn1TmbP22CY39G2dA';
} 
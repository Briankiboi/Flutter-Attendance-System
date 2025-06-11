import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_attendance/config/env_config.dart';

/// Initialize Supabase before running the app
Future<void> initializeSupabase() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Try to get values from EnvConfig
    final url = EnvConfig.supabaseUrl;
    final anonKey = EnvConfig.supabaseAnonKey;
    
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: false,
    );
  } catch (e) {
    // If there's an error, use hardcoded values directly
    print('Error using EnvConfig, using hardcoded values: $e');
    
    await Supabase.initialize(
      url: 'https://vaaqnexxyzzmjwquhpry.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhYXFuZXh4eXp6bWp3cXVocHJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY0MjYyMjgsImV4cCI6MjA2MjAwMjIyOH0.SVPotafYY4VtdxQvIrDITp4VkInn1TmbP22CY39G2dA',
      debug: false,
    );
  }
}

/// Get Supabase client
SupabaseClient get supabase => Supabase.instance.client; 
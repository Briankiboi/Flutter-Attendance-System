import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTestApp extends StatelessWidget {
  const SupabaseTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SupabaseConnectionTest(),
    );
  }
}

class SupabaseConnectionTest extends StatefulWidget {
  const SupabaseConnectionTest({super.key});

  @override
  State<SupabaseConnectionTest> createState() => _SupabaseConnectionTestState();
}

class _SupabaseConnectionTestState extends State<SupabaseConnectionTest> {
  String _connectionStatus = 'Testing connection...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      // Initialize Supabase directly with hardcoded credentials for testing
      await Supabase.initialize(
        url: 'https://vaaqnexxyzzmjwquhpry.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhYXFuZXh4eXp6bWp3cXVocHJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTczMjM5MzQsImV4cCI6MjAzMjg5OTkzNH0.o26TcBwjCrwRFfjc4U9RzwJJp7iJxsxkkQvTrRLj1hw',
      );
      
      // Try a simple query to test the connection
      final response = await Supabase.instance.client
          .from('users')
          .select('count')
          .limit(1)
          .execute();

      if (response.status == 200) {
        setState(() {
          _connectionStatus = 'Connected successfully! ✅\n\nResponse: ${response.data}';
          _isLoading = false;
        });
      } else {
        setState(() {
          _connectionStatus = 'Error: Got status code ${response.status}\n\nError: ${response.error}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Connection Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _connectionStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _connectionStatus.contains('successfully')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Run this file directly to test:
// void main() {
//   runApp(const SupabaseTestApp());
// } 
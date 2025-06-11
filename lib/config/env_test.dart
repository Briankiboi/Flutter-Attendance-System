import 'package:flutter/material.dart';
import 'env_config.dart';

class EnvTestScreen extends StatelessWidget {
  const EnvTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Supabase URL: ${EnvConfig.supabaseUrl}'),
            const SizedBox(height: 20),
            Text('Supabase Anon Key: ${EnvConfig.supabaseAnonKey.isNotEmpty ? "Loaded ✅" : "Not loaded ❌"}'),
          ],
        ),
      ),
    );
  }
} 
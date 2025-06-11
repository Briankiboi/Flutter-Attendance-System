import 'package:flutter/material.dart';

class RegisterUnitPage extends StatelessWidget {
  const RegisterUnitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Print attendance '),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/university_logo.png', height: 150),
            Spacer(),
            Text('TUN is ISO 9001:2015 Certified.', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
} 
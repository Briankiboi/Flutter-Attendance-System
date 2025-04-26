import 'package:flutter/material.dart';

class LecturerSchedulesPage extends StatefulWidget {
  const LecturerSchedulesPage({Key? key}) : super(key: key);

  @override
  State<LecturerSchedulesPage> createState() => _LecturerSchedulesPageState();
}

class _LecturerSchedulesPageState extends State<LecturerSchedulesPage> {
  // User data fields
  String? _lectureNumber;
  String? _lecturerName;
  String? _department;
  String? _occupation;
  String? _employmentType;
  String? _gender;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _lectureNumber = args['lectureNumber'];
        _lecturerName = args['name'];
        _department = args['department'];
        _occupation = args['occupation'];
        _employmentType = args['employmentType'];
        _gender = args['gender'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedules'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Teaching Schedule',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'View your teaching schedule for this semester.',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 30),
            // Placeholder for schedule calendar
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Teaching schedule calendar will be displayed here',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
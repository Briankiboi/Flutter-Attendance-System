import 'package:flutter/material.dart';

class GetAssignedUnitsPage extends StatefulWidget {
  const GetAssignedUnitsPage({Key? key}) : super(key: key);

  @override
  State<GetAssignedUnitsPage> createState() => _GetAssignedUnitsPageState();
}

class _GetAssignedUnitsPageState extends State<GetAssignedUnitsPage> {
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
        title: const Text('Assigned Units'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Assigned Units',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'View all the units that have been assigned to you for this semester.',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 30),
            // Placeholder for assigned units list
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'List of assigned units will be displayed here',
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
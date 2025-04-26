import 'package:flutter/material.dart';

class CatMarksEntryPage extends StatefulWidget {
  const CatMarksEntryPage({Key? key}) : super(key: key);

  @override
  State<CatMarksEntryPage> createState() => _CatMarksEntryPageState();
}

class _CatMarksEntryPageState extends State<CatMarksEntryPage> {
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
        title: const Text('Enter CAT Marks'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CAT Marks Entry',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Record and manage Continuous Assessment Test (CAT) marks for your students.',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 30),
            // Placeholder for CAT marks entry form
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'CAT marks entry form will be displayed here',
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
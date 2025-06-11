import 'package:flutter/material.dart';

class ExcelUploadWidget extends StatelessWidget {
  final String lecturerId;
  final String unitId;
  final Function(String) onImportStarted;
  final Function(String, String) onError;

  const ExcelUploadWidget({
    super.key,
    required this.lecturerId,
    required this.unitId,
    required this.onImportStarted,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.upload_file,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Excel Upload Temporarily Unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Excel import functionality will be available in a future update. Please use manual entry for now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
} 
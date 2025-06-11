import 'dart:async';
import 'package:flutter/material.dart';
import '../models/excel_import.dart';
import '../services/supabase_cat_service.dart';

class ImportProgressWidget extends StatefulWidget {
  final String importId;
  final Function() onComplete;

  const ImportProgressWidget({
    super.key,
    required this.importId,
    required this.onComplete,
  });

  @override
  State<ImportProgressWidget> createState() => _ImportProgressWidgetState();
}

class _ImportProgressWidgetState extends State<ImportProgressWidget> {
  final SupabaseCatService _supabaseService = SupabaseCatService();
  Timer? _timer;
  ExcelImport? _import;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      final import = await _supabaseService.getExcelImportStatus(widget.importId);
      
      if (import == null) {
        setState(() => _error = 'Import not found');
        _timer?.cancel();
        return;
      }

      setState(() => _import = import);

      // Check if import is complete or failed
      if (['completed', 'completed_with_errors', 'failed'].contains(import.status)) {
        _timer?.cancel();
        widget.onComplete();
      }
    } catch (e) {
      setState(() => _error = e.toString());
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Import Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    if (_import == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final progress = _import!.totalCount > 0
        ? _import!.processedCount / _import!.totalCount
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Importing Excel File',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              '${_import!.processedCount} of ${_import!.totalCount} rows processed',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${_import!.status}',
              style: TextStyle(
                color: _getStatusColor(_import!.status),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_import!.errorLog != null && _import!.errorLog!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Errors:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _import!.errorLog!.entries.map((entry) {
                      return Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'completed_with_errors':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
} 
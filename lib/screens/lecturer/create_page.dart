import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:qr_attendance/services/supabase_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:qr_attendance/utils/key_generator.dart';
import 'package:flutter/services.dart';

class CreateQRCodePage extends StatefulWidget {
  const CreateQRCodePage({super.key});

  @override
  _CreateQRCodePageState createState() => _CreateQRCodePageState();
}

class _CreateQRCodePageState extends State<CreateQRCodePage> {
  final supabase = Supabase.instance.client;
  final supabaseService = SupabaseService();
  
  // State variables
  bool isLoading = false;
  bool qrGenerated = false;
  String? errorMessage;
  
  // Selected values
  Map<String, dynamic>? selectedUnit;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  TextEditingController durationHoursController = TextEditingController();
  TextEditingController durationMinutesController = TextEditingController();
  
  // QR code data
  String? qrCodeData;
  String? qrImageUrl;
  String? sessionId;
  Uint8List? qrImageBytes;
  
  // Assigned units
  List<Map<String, dynamic>> assignedUnits = [];

  // New state variables
  String? backupKeyGenerated;
  String? lecturerName;
  String? lecturerEmail;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _loadLecturerDetails();
    
    // Add listeners for duration controllers
    durationHoursController.addListener(_updateEndTime);
    durationMinutesController.addListener(_updateEndTime);
  }

  @override
  void dispose() {
    durationHoursController.dispose();
    durationMinutesController.dispose();
    super.dispose();
  }

  bool _isValidStartTime(TimeOfDay time) {
    final now = TimeOfDay.now();
    final currentDateTime = DateTime.now();
    final selectedDateTime = DateTime(
      currentDateTime.year,
      currentDateTime.month,
      currentDateTime.day,
      time.hour,
      time.minute,
    );
    
    // Allow selection only if time is at most 1 minute in the past
    final difference = selectedDateTime.difference(currentDateTime);
    return difference.inMinutes >= -1;
  }

  bool _isValidEndTime(TimeOfDay start, TimeOfDay end) {
    if (start.hour > end.hour) return false;
    if (start.hour == end.hour && start.minute >= end.minute) return false;
    return true;
  }

  void _updateEndTime() {
    if (startTime == null) return;
    
    final hours = int.tryParse(durationHoursController.text) ?? 0;
    final minutes = int.tryParse(durationMinutesController.text) ?? 0;
    
    if (hours == 0 && minutes == 0) {
      setState(() {
        endTime = null;
      });
      return;
    }
    
    final startDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      startTime!.hour,
      startTime!.minute,
    );
    
    final endDateTime = startDateTime.add(Duration(
      hours: hours,
      minutes: minutes,
    ));
    
    setState(() {
      endTime = TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute);
    });
  }

  Future<void> _loadUnits() async {
      setState(() {
        isLoading = true;
      errorMessage = null;
    });

    try {
      // Get current lecturer ID
      final lecturerId = await supabaseService.getCurrentLecturerId();
      if (lecturerId == null) {
        throw Exception('No lecturer ID found');
      }

      // Get assigned units
      final result = await supabaseService.getAssignedUnits(lecturerId);
      setState(() {
        assignedUnits = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load assigned units: $e';
        isLoading = false;
      });
    }
  }
  
  Future<void> _generateQRCode() async {
    try {
    if (selectedUnit == null || startTime == null || endTime == null) {
      setState(() {
          errorMessage = 'Please fill in all required fields';
      });
      return;
    }

      // Create the start and end DateTimes
      final now = DateTime.now();
      final startDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        startTime!.hour,
        startTime!.minute,
      );
      final endDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        endTime!.hour,
        endTime!.minute,
      );

      // Check if the selected end time is before start time
      if (endDateTime.isBefore(startDateTime)) {
        setState(() {
          errorMessage = 'End time cannot be before start time';
        });
        return;
      }

      // Check if the session duration is reasonable
      final duration = endDateTime.difference(startDateTime);
      if (duration.inHours > 8) {
        setState(() {
          errorMessage = 'Session duration cannot exceed 8 hours';
        });
        return;
      }

      // Check for active sessions for this unit
      final activeSession = await supabaseService.getActiveSessionForUnit(selectedUnit!['unit_code']);
      if (activeSession != null) {
        final sessionEndTime = DateTime.parse(activeSession['end_time']);
        if (DateTime.now().isBefore(sessionEndTime)) {
          final formattedEndTime = DateFormat('dd/MM/yyyy HH:mm').format(sessionEndTime.toLocal());
          setState(() {
            errorMessage = 'Cannot create new QR code. An active session exists for ${selectedUnit!['unit_code']} - ${selectedUnit!['unit_name']} until $formattedEndTime';
          });
          return;
        }
      }

      // Check for overlapping sessions with other units
      final overlappingSession = await supabaseService.checkOverlappingSessions(
        selectedUnit!['unit_code'],
        startDateTime,
        endDateTime
      );

      if (overlappingSession != null) {
        setState(() {
          errorMessage = 'Cannot create new QR code.\nStudents have an ongoing session for:\n'
              '${overlappingSession['conflictingUnit']}\n'
              'Date: ${overlappingSession['date']}\n'
              'Time: ${overlappingSession['startTime']} to ${overlappingSession['endTime']}';
        });
        return;
      }

      // Generate session ID and backup key
      sessionId = const Uuid().v4();
      backupKeyGenerated = KeyGenerator.generateBackupKey();
      
      final qrData = {
        'session_id': sessionId,
        'unit_code': selectedUnit!['unit_code'],
        'unit_name': selectedUnit!['unit_name'],
        'start_time': startDateTime.toUtc().toIso8601String(),
        'end_time': endDateTime.toUtc().toIso8601String(),
        'duration': {
          'hours': int.tryParse(durationHoursController.text) ?? 0,
          'minutes': int.tryParse(durationMinutesController.text) ?? 0,
        },
        'backup_key': backupKeyGenerated,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      qrCodeData = jsonEncode(qrData);

      // Generate QR code
      final qrPainter = QrPainter(
        data: qrCodeData!,
        version: QrVersions.auto,
        gapless: false,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      final qrSize = 1200.0;
      final qrImage = await qrPainter.toImage(qrSize);
      final byteData = await qrImage.toByteData(format: ui.ImageByteFormat.png);

      setState(() {
        qrImageBytes = byteData!.buffer.asUint8List();
        qrGenerated = true;
        errorMessage = null;
      });

    } catch (e) {
      setState(() {
        errorMessage = 'Error generating QR code: $e';
      });
    }
  }
  
  Future<void> _printQRCode() async {
    if (!qrGenerated || qrImageBytes == null) {
      setState(() {
        errorMessage = 'Please generate QR code first';
      });
      return;
    }
      
    final doc = pw.Document();
    
    // Format time strings
    final startTimeStr = '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
    final endTimeStr = '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
    
    // Convert QR image bytes to PDF image
    final pdfImage = pw.MemoryImage(qrImageBytes!);
    
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 40, vertical: 50),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Title at the top
                pw.Text(
                  'Scan QR Code / Enter Key',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 30),
                // QR Code with subtle shadow
                pw.Container(
                  width: 380,
                  height: 380,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(15),
                    border: pw.Border.all(color: PdfColors.grey200),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 15,
                    verticalRadius: 15,
                    child: pw.Image(pdfImage),
                  ),
                ),
                pw.SizedBox(height: 25),
                // Unit Information
                pw.Text(
                  '${selectedUnit!['unit_code']} - ${selectedUnit!['unit_name']}',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 15),
                // Date and Time in one line
                pw.Text(
                  '${DateFormat('dd/MM/yyyy').format(DateTime.now())} | $startTimeStr - $endTimeStr | ${durationHoursController.text}h ${durationMinutesController.text}m',
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.grey800,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Spacer(),
                // Backup Key at the bottom
                pw.Container(
                  width: 300,
                  padding: pw.EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Backup Key',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        backupKeyGenerated ?? 'N/A',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          font: pw.Font.courier(),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
  
  Future<void> _saveQRCode() async {
    if (!qrGenerated || qrCodeData == null) {
      setState(() {
        errorMessage = 'Please generate QR code first';
      });
      return;
    }

    // Validate duration fields
    final hours = durationHoursController.text.isEmpty ? 0 : int.tryParse(durationHoursController.text);
    final minutes = durationMinutesController.text.isEmpty ? 0 : int.tryParse(durationMinutesController.text);
    
    if (hours == null || minutes == null) {
      setState(() {
        errorMessage = 'Please enter valid duration values';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final lecturerId = await supabaseService.getCurrentLecturerId();
      if (lecturerId == null) {
        throw Exception('No lecturer ID found');
      }

      // Check for active sessions for this unit
      final activeSession = await supabaseService.getActiveSessionForUnit(selectedUnit!['unit_code']);
      if (activeSession != null) {
        final endTime = DateTime.parse(activeSession['end_time']);
        if (DateTime.now().isBefore(endTime)) {
          setState(() {
            errorMessage = 'An active session exists for this unit until ${DateFormat('HH:mm').format(endTime)}';
          });
          return;
        }
      }

      // Format the data for saving
      final now = DateTime.now();
      final startDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        startTime!.hour,
        startTime!.minute,
      );
      final endDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        endTime!.hour,
        endTime!.minute,
      );

      final formattedData = {
        'year': selectedUnit!['year'] ?? 3,
        'course': selectedUnit!['course'] ?? 'Civil Engineering',
        'duration': {
          'hours': hours,
          'minutes': minutes,
        },
        'end_time': endDateTime.toUtc().toIso8601String(),
        'semester': selectedUnit!['semester'] ?? '2',
        'is_active': true,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'unit_code': selectedUnit!['unit_code'],
        'unit_name': selectedUnit!['unit_name'],
        'department': selectedUnit!['department'] ?? 'Engineering',
        'session_id': sessionId,
        'start_time': startDateTime.toUtc().toIso8601String(),
        'lecturer_name': lecturerName,
        'lecturer_email': lecturerEmail,
        'backup_key': backupKeyGenerated,
      };

      // First upload the QR code image
      String? qrCodeUrl;
      if (qrImageBytes != null) {
        final fileName = 'qr_${sessionId}_${DateTime.now().millisecondsSinceEpoch}.png';
        qrCodeUrl = await supabaseService.uploadQRCode(qrImageBytes!, fileName);
      }

      // Create attendance session with QR code URL
      await supabaseService.createAttendanceSession(
        lecturerId: lecturerId,
        unitCode: selectedUnit!['unit_code'],
        qrCodeUrl: qrCodeUrl ?? '',
        qrCodeData: jsonEncode(formattedData),
        startTime: startDateTime,
        endTime: endDateTime,
        sessionData: formattedData,
        backupKey: backupKeyGenerated ?? '',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session created successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset state after successful save
        setState(() {
          qrGenerated = false;
          qrCodeData = null;
          qrImageBytes = null;
          sessionId = null;
          selectedUnit = null;
          startTime = null;
          endTime = null;
          durationHoursController.clear();
          durationMinutesController.clear();
          backupKeyGenerated = null;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to save session: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  void _discardQRCode() {
      setState(() {
      qrGenerated = false;
      qrCodeData = null;
      qrImageBytes = null;
      qrImageUrl = null;
      sessionId = null;
      errorMessage = null;
    });
  }

  Widget _buildQRCodeDisplay() {
    if (!qrGenerated || qrImageBytes == null) {
      return Container();
    }

    return Column(
              children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // QR Code with padding
              Container(
                width: 320,
                height: 320,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    qrImageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Unit and Time Info
              Text(
                '${selectedUnit!['unit_code']} - ${selectedUnit!['unit_name']}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Time: ${startTime!.format(context)} - ${endTime!.format(context)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Duration: ${durationHoursController.text}h ${durationMinutesController.text}m',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                ),
              SizedBox(height: 16),
              // Backup Key
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'Backup Key',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      backupKeyGenerated ?? "N/A",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                        letterSpacing: 1,
                      ),
                ),
              ],
            ),
              ),
            ],
      ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _saveQRCode,
              icon: Icon(Icons.save),
              label: Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _printQRCode,
              icon: Icon(Icons.print),
              label: Text('Print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Get device ID for security
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown';
    }
    return 'unknown';
  }

  // Generate security checksum
  String _generateChecksum(String? sessionId, String? backupKey) {
    final id = sessionId ?? '';
    final key = backupKey ?? '';
    final data = utf8.encode('$id:$key:${DateTime.now().toIso8601String()}');
    return sha256.convert(data).toString().substring(0, 16);
  }

  // Get logo for QR code
  Future<ui.Image?> _getLogoImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetHeight: 40,
        targetWidth: 40,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      print('Error loading logo: $e');
      return null;
    }
  }

  Future<void> _loadLecturerDetails() async {
    try {
      final user = supabaseService.client.auth.currentUser;
      if (user != null) {
        final lecturerData = await supabaseService.client
            .from('lecturers')
            .select('name, email')
            .eq('id', user.id)
            .single();
        
        setState(() {
          lecturerName = lecturerData['name'];
          lecturerEmail = lecturerData['email'];
        });
      }
    } catch (e) {
      print('Error loading lecturer details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final horizontalPadding = screenSize.width * 0.04; // 4% of screen width
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Create QR Code'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.blue.shade50],
            stops: [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16.0,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600, // Maximum width for larger screens
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Session Time Card
                Card(
                  elevation: 4,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: Colors.blue[800],
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Session Time',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Time',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.now(),
                                        );
                                        if (time != null) {
                                          if (!_isValidStartTime(time)) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Cannot select a time more than 1 minute in the past'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                          setState(() {
                                            startTime = time;
                                            endTime = null;
                                            _updateEndTime();
                                          });
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.blue.shade200),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              startTime?.format(context) ?? 'Select Time',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: startTime != null ? Colors.black87 : Colors.grey[600],
                                              ),
                                            ),
                                            Icon(Icons.schedule, color: Colors.blue, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'End Time',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue.shade200),
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.grey[100],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            endTime?.format(context) ?? 'Auto-calculated',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: endTime != null ? Colors.black87 : Colors.grey[600],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(Icons.schedule, color: Colors.blue, size: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: durationHoursController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'Hours',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.blue.shade200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.blue.shade200),
                                  ),
                                  suffixIcon: Icon(Icons.hourglass_empty, color: Colors.blue, size: 20),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: durationMinutesController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: 'Minutes',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.blue.shade200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.blue.shade200),
                                  ),
                                  suffixIcon: Icon(Icons.timer, color: Colors.blue, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Unit Selection Card
                Card(
                  elevation: 4,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.school_rounded,
                              color: Colors.blue[800],
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Unit Selection',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: InputDecoration(
                            labelText: 'Select Unit',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.blue.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.blue.shade200),
                            ),
                            prefixIcon: Icon(Icons.book, color: Colors.blue, size: 20),
                          ),
                          value: selectedUnit,
                          items: assignedUnits.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(
                                '${unit['unit_code']} - ${unit['unit_name']}',
                                style: TextStyle(fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedUnit = value;
                            });
                          },
                          isExpanded: true,
                        ),
                        SizedBox(height: 20),
                        if (!qrGenerated)
                          Center(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.qr_code_2_rounded),
                              label: Text(
                                'Generate QR Code',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              onPressed: isLoading ? null : _generateQRCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: Size(200, 45),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (qrGenerated && qrCodeData != null) ...[
                  SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.blue.shade50],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: _buildQRCodeDisplay(),
                      ),
                    ),
                  ),
                ],
                if (errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.red[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
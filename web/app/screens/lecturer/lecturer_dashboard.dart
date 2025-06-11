import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_web_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({Key? key}) : super(key: key);

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  final _supabaseService = SupabaseWebService();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCreatingSession = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        context.go('/');
        return;
      }

      final response = await _supabaseService.getLecturerSessions(user['id']);
      if (response['success']) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(response['data']);
        });
      } else {
        setState(() {
          _errorMessage = response['message'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sessions: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() {
    _supabaseService.logout();
    context.go('/');
  }

  Future<void> _createSession() async {
    setState(() {
      _isCreatingSession = true;
    });

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        context.go('/');
        return;
      }

      // Generate QR code data
      final qrData = {
        'lecturer_id': user['id'],
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'attendance',
      };

      // Convert QR data to image
      final qrImage = await QrPainter(
        data: qrData.toString(),
        version: QrVersions.auto,
        gapless: false,
      ).toImage(200);

      // Convert image to bytes
      final byteData = await qrImage.toByteData(format: ImageByteFormat.png);
      final imageBytes = byteData!.buffer.asUint8List();

      // Upload QR code
      final fileName = 'qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final qrCodeUrl = await _supabaseService.uploadQRCode(imageBytes, fileName);

      // Create session
      final response = await _supabaseService.createAttendanceSession(
        lecturerId: user['id'],
        unitId: 'UNIT_ID', // This should be selected by the lecturer
        qrCodeUrl: qrCodeUrl,
        qrCodeData: qrData,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 2)),
      );

      if (response['success']) {
        _loadSessions();
      } else {
        setState(() {
          _errorMessage = response['message'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create session: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isCreatingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabaseService.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            extended: MediaQuery.of(context).size.width >= 800,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.qr_code),
                label: Text('Generate QR'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person),
                label: Text('Profile'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
            selectedIndex: 0,
            onDestinationSelected: (index) {
              // Handle navigation
            },
          ),
          // Main content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user['name']}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user['email'],
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isCreatingSession ? null : _createSession,
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Create New Session'),
                      ),
                      if (_isCreatingSession)
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Sessions list
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Sessions',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (_errorMessage != null)
                              Center(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            else if (_sessions.isEmpty)
                              const Center(
                                child: Text('No sessions found'),
                              )
                            else
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _sessions.length,
                                  itemBuilder: (context, index) {
                                    final session = _sessions[index];
                                    final unit = session['unit'];
                                    final attendanceCount = session['attendance']?.length ?? 0;
                                    return ListTile(
                                      title: Text(
                                        '${unit['code']} - ${unit['name']}',
                                      ),
                                      subtitle: Text(
                                        'Date: ${DateTime.parse(session['created_at']).toString()}\n'
                                        'Attendance: $attendanceCount students',
                                      ),
                                      leading: const Icon(Icons.class_),
                                      trailing: session['is_active']
                                          ? const Chip(
                                              label: Text('Active'),
                                              backgroundColor: Colors.green,
                                              labelStyle: TextStyle(color: Colors.white),
                                            )
                                          : null,
                                    );
                                  },
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
        ],
      ),
    );
  }
} 
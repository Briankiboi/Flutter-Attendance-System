import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/schedule_service.dart';
import '../../widgets/custom_calendar.dart';

class SchedulesPage extends StatefulWidget {
  const SchedulesPage({super.key});

  @override
  State<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage> {
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  final _scheduleService = ScheduleService();

  String? _studentId;
  List<Map<String, dynamic>> _units = [];
  Map<String, List<Map<String, dynamic>>> _messagesByUnit = {};
  Map<String, int> _newMessageCounts = {};  // Track new message counts
  bool _isLoading = false;

  Map<String, RealtimeChannel> _messageSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _initializeStudentData();
  }

  @override
  void dispose() {
    for (var subscription in _messageSubscriptions.values) {
      subscription.unsubscribe();
    }
    super.dispose();
  }

  Future<void> _initializeStudentData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get cached user data first
      final userData = _supabaseService.getCurrentUser();
      
      if (userData != null && userData['student_id'] != null) {
        setState(() => _studentId = userData['student_id']);
        await _loadStudentUnits();
        return;
      }

      // Fallback to getting data from Supabase if cache miss
      final user = _supabase.auth.currentUser;
      
      if (user != null) {
        var student = await _supabase
          .from('students')
          .select('id, name, email')
          .eq('user_id', user.id)
          .maybeSingle();
            
        if (student == null && user.email != null) {
          student = await _supabase
            .from('students')
            .select('id, name, email')
            .eq('email', user.email!)
            .maybeSingle();
        }
            
        if (!mounted) return;
        
        final studentId = student?['id'] as String?;
        
        if (studentId != null) {
          setState(() => _studentId = studentId);
          _supabaseService.updateCurrentUserCache({
            'student_id': studentId
          });
          await _loadStudentUnits();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student profile not found. Please contact support.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in again')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading student data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadStudentUnits() async {
    if (_studentId == null) {
      print('_loadStudentUnits: No student ID available');
      return;
    }

    try {
      print('_loadStudentUnits: Fetching units for student $_studentId');
      final units = await _scheduleService.getStudentUnits(_studentId!);
      print('_loadStudentUnits: Fetched ${units.length} units');
      print('Units data: $units');
      
      if (!mounted) return;

      setState(() {
        _units = units;
        // Initialize empty message lists for each unit
        for (var unit in units) {
          final unitId = unit['unit_id']?.toString();
          if (unitId != null) {
            _messagesByUnit[unitId] = [];
            print('_loadStudentUnits: Initialized message list for unit ${unit['unit_code']}');
          }
        }
      });

      // Load messages for all units
      for (var unit in units) {
        final unitId = unit['unit_id']?.toString();
        if (unitId != null) {
          print('_loadStudentUnits: Loading messages for unit ${unit['unit_code']}');
          await _loadMessagesForUnit(unitId);
          _subscribeToUnitMessages(unitId);
        }
      }
    } catch (e) {
      print('_loadStudentUnits: Error loading units: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading units: $e')),
        );
      }
    }
  }

  Future<void> _loadMessagesForUnit(String unitId) async {
    try {
      print('_loadMessagesForUnit: Loading messages for unit $unitId');
      final messages = await _scheduleService.getUnitMessages(unitId);
      print('_loadMessagesForUnit: Loaded ${messages.length} messages for unit $unitId');
      
      if (!mounted) return;

      setState(() {
        _messagesByUnit[unitId] = messages;
      });
    } catch (e) {
      print('_loadMessagesForUnit: Error loading messages for unit $unitId: $e');
    }
  }

  void _subscribeToUnitMessages(String unitId) {
    _messageSubscriptions[unitId]?.unsubscribe();

    final lastMessageTime = _messagesByUnit[unitId]?.isNotEmpty == true 
        ? DateTime.parse(_messagesByUnit[unitId]!.first['created_at'])
        : DateTime.now();

    _messageSubscriptions[unitId] = _supabase
      .channel('schedule_messages_$unitId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'schedule_messages',
        callback: (payload) async {
          final newRecordUnitId = payload.newRecord?['unit_id'];
          if (newRecordUnitId != null && 
              newRecordUnitId.toString() == unitId) {
            final newMessage = payload.newRecord!;
            
            setState(() {
              final messages = _messagesByUnit[unitId] ?? [];
              messages.insert(0, newMessage);
              _messagesByUnit[unitId] = messages;
              
              // Increment new message count for this unit
              _newMessageCounts[unitId] = (_newMessageCounts[unitId] ?? 0) + 1;
              
              // Show notification if the app is active
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New message in ${_units.firstWhere((u) => u['unit_id'].toString() == unitId)['unit_code']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.red[700],
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
          }
        },
      )
      .subscribe();
  }

  String _getMessageDateHeader(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    
    if (_isSameDay(date, now)) {
      return 'Today';
    } else if (_isSameDay(date, yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/get in touch.jpg'),
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
                color: Colors.white,
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Blue header with rounded bottom corners
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  bottom: 20,
                ),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Class Schedule',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '& ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Announcements',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ],
                ),
              ),
              // Messages and Calendar section
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Messages list
                      StreamBuilder<List<MapEntry<String, List<Map<String, dynamic>>>>>(
                        stream: Stream.fromFuture(Future(() {
                          // Group messages by unit
                          final Map<String, List<Map<String, dynamic>>> messagesByUnit = {};
                          
                          for (final unit in _units) {
                            final unitId = unit['unit_id'].toString();
                            final messages = _messagesByUnit[unitId] ?? [];
                            if (messages.isNotEmpty) {
                              final unitMessages = messages.map((msg) => {
                                ...msg,
                                'unit_code': unit['unit_code'],
                                'unit_name': unit['unit_name'],
                              }).toList();
                              
                              // Sort messages for this unit
                              unitMessages.sort((a, b) {
                                final dateA = DateTime.parse(a['created_at']);
                                final dateB = DateTime.parse(b['created_at']);
                                return dateB.compareTo(dateA);
                              });
                              
                              messagesByUnit[unit['unit_code']] = unitMessages;
                            }
                          }
                          
                          // Sort units by latest message time
                          final sortedEntries = messagesByUnit.entries.toList()
                            ..sort((a, b) {
                              final latestA = DateTime.parse(a.value.first['created_at']);
                              final latestB = DateTime.parse(b.value.first['created_at']);
                              return latestB.compareTo(latestA);
                            });
                          
                          return sortedEntries;
                        })),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Loading messages...',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final unitEntries = snapshot.data ?? [];
                          
                          if (unitEntries.isEmpty) {
                            return const Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Horizontal scrolling unit panels
                              SizedBox(
                                height: 260, // Slightly reduced height
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: unitEntries.length,
                                  itemBuilder: (context, index) {
                                    final entry = unitEntries[index];
                                    final unitCode = entry.key;
                                    final messages = entry.value;
                                    final latestMessage = messages.first;
                                    final messageDate = DateTime.parse(latestMessage['created_at']);
                                    final isNew = _newMessageCounts[unitCode] != null && _newMessageCounts[unitCode]! > 0;

                                    return Container(
                                      width: MediaQuery.of(context).size.width * 0.85,
                                      margin: const EdgeInsets.only(right: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.85),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.blue.withOpacity(0.1)),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Unit header
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.black12,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.message_outlined,
                                                      color: Colors.green,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'MESSAGES',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (isNew) ...[
                                                      const Spacer(),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red[700],
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              'NEW${(_newMessageCounts[unitCode] ?? 0) > 1 ? ' (${_newMessageCounts[unitCode]})' : ''}',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '$unitCode ',
                                                      style: const TextStyle(
                                                        color: Colors.blue,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        latestMessage['unit_name'],
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Latest message with scroll for history
                                          Expanded(
                                            child: ListView.builder(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              reverse: true,
                                              itemCount: messages.length,
                                              itemBuilder: (context, msgIndex) {
                                                final message = messages[msgIndex];
                                                final messageDate = DateTime.parse(message['created_at']);

                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                                      child: Text(
                                                        _getMessageDateHeader(messageDate),
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.fromLTRB(16, 4, 48, 8),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 12,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[100]?.withOpacity(0.7),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              message['content'],
                                                              style: const TextStyle(
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              DateFormat('h:mm a').format(messageDate).toLowerCase(),
                                                              style: TextStyle(
                                                                color: Colors.grey[600],
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Scroll indicator
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4), // Reduced margin
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // Reduced padding
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.swipe,
                                      color: Colors.blue[400],
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Swipe to see more units',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      // Calendar section with adjusted margins and height
                      Container(
                        height: 260, // Reduced height
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8), // Reduced bottom margin
                        child: CustomCalendar(
                          onDateSelected: (date) {
                            print('Selected date: $date');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 
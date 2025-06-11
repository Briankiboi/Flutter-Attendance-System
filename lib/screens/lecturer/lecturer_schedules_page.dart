import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui';  // Add this import for ImageFilter
import '../../services/supabase_service.dart';
import '../../services/schedule_service.dart';
import '../../widgets/custom_calendar.dart';

class LecturerSchedulesPage extends StatefulWidget {
  const LecturerSchedulesPage({super.key});

  @override
  State<LecturerSchedulesPage> createState() => _LecturerSchedulesPageState();
}

class _LecturerSchedulesPageState extends State<LecturerSchedulesPage> {
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  final _scheduleService = ScheduleService();

  // User data fields
  String? _lecturerId;
  String? _selectedUnitId;
  String? _selectedUnitName;
  final _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  RealtimeChannel? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLecturerData();
  }

  @override
  void dispose() {
    _messagesSubscription?.unsubscribe();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initializeLecturerData() async {
    print('Initializing lecturer data...');
    setState(() => _isLoading = true);
    
    try {
      // Get cached user data first
      final userData = _supabaseService.getCurrentUser();
      print('Cached user data: $userData');
      
      if (userData != null && userData['lecturer_id'] != null) {
        print('Found lecturer_id in cached data: ${userData['lecturer_id']}');
        setState(() => _lecturerId = userData['lecturer_id']);
        
        // Check if lecturer has any units assigned
        final units = await _scheduleService.getLecturerUnits(userData['lecturer_id']);
        if (units.isEmpty) {
          print('No units found, assigning test units...');
          await _scheduleService.assignTestUnits(userData['lecturer_id']);
        }
        return;
      }

      // Fallback to getting data from Supabase if cache miss
      final user = _supabase.auth.currentUser;
      print('Current user: ${user?.email}');
      
      if (user != null) {
        // Try to get lecturer by user_id first
        print('Trying to get lecturer by user_id: ${user.id}');
        var lecturer = await _supabase
          .from('lecturers')
          .select('id, name, email')
          .eq('user_id', user.id)
          .maybeSingle();
            
        print('Lecturer by user_id result: $lecturer');
            
        // If not found, try by email
        if (lecturer == null && user.email != null) {
          print('Trying to get lecturer by email: ${user.email}');
          lecturer = await _supabase
            .from('lecturers')
            .select('id, name, email')
            .eq('email', user.email!)
            .maybeSingle();
          print('Lecturer by email result: $lecturer');
        }
            
        if (!mounted) return;
        
        final lecturerId = lecturer?['id'] as String?;
        print('Final lecturer ID: $lecturerId');
        
        if (lecturerId != null) {
          // Update both state and cache
          setState(() => _lecturerId = lecturerId);
          _supabaseService.updateCurrentUserCache({
            'lecturer_id': lecturerId
          });
          print('Lecturer ID set successfully');
        } else {
          print('No lecturer ID found');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lecturer profile not found. Please contact support.')),
          );
        }
      } else {
        print('No user logged in');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in again')),
          );
        }
      }
    } catch (e) {
      print('Error loading lecturer data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lecturer data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_selectedUnitId == null || _lecturerId == null) return;

    try {
      setState(() => _isLoading = true);

      final messages = await _scheduleService.getUnitMessages(_selectedUnitId!);

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }

      _subscribeToMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    _messagesSubscription?.unsubscribe();

    if (_selectedUnitId == null) return;

    _messagesSubscription = _supabase
      .channel('schedule_messages')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'schedule_messages',
        callback: (payload) {
          final newRecordUnitId = payload.newRecord?['unit_id'];
          if (newRecordUnitId != null && 
              newRecordUnitId.toString() == _selectedUnitId) {
            _loadMessages();
          }
        },
      )
      .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Schedule'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[700],
            child: _lecturerId == null
              ? const SizedBox(height: 48)
              : FutureBuilder<List<Map<String, dynamic>>>(
                  future: _scheduleService.getLecturerUnits(_lecturerId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      print('Error loading units: ${snapshot.error}');
                      return Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Error loading units',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedUnitId,
                        isExpanded: true,
                        hint: const Text('Select Unit'),
                        underline: const SizedBox(),
                        items: snapshot.data!.map((unit) {
                          final unitId = unit['unit_id']?.toString() ?? '';
                          final unitCode = unit['unit_code'] ?? '';
                          final unitName = unit['unit_name'] ?? '';
                          final year = unit['year'] ?? '';
                          final semester = unit['semester'] ?? '';
                          
                          return DropdownMenuItem<String>(
                            value: unitId,
                            child: Text(
                              '$unitCode - $unitName ($year $semester)',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (selectedUnitId) {
                          if (selectedUnitId != null) {
                            final selectedUnit = snapshot.data!.firstWhere(
                              (unit) => unit['unit_id'].toString() == selectedUnitId
                            );
                            setState(() {
                              _selectedUnitId = selectedUnitId;
                              _selectedUnitName = '${selectedUnit['unit_code']} - ${selectedUnit['unit_name']}';
                              _messages = [];
                            });
                            _loadMessages();
                          }
                        },
                      ),
                    );
                  },
                ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Calendar section - fixed at top
            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: BoxDecoration(
                color: Colors.blue[700],
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 16.0),
                child: Material(
                  color: Colors.transparent,
                  child: CustomCalendar(
                    onDateSelected: (date) {
                      print('Selected date: $date');
                    },
                  ),
                ),
              ),
            ),

            // Messages section - scrollable
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.65,
                  ),
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/get in touch.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Messages content with blur effect
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A0072).withOpacity(0.15),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(40),
                            topRight: Radius.circular(40),
                          ),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Column(
                            children: [
                              // Draggable handle
                              Container(
                                margin: const EdgeInsets.only(top: 12, bottom: 4),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              
                              // Messages Header
                              Container(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.message_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Message My Students',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4A0072),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Messages List
                              _messages.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4A0072).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 32,
                                            color: const Color(0xFF4A0072).withOpacity(0.9),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No messages yet',
                                          style: TextStyle(
                                            color: const Color(0xFF4A0072).withOpacity(0.9),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    reverse: true,
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      final message = _messages[index];
                                      final messageDate = DateTime.parse(message['created_at']);
                                      final bool showDateHeader = index == _messages.length - 1 ||
                                          !_isSameDay(
                                            messageDate,
                                            DateTime.parse(_messages[index + 1]['created_at']),
                                          );

                                      return Column(
                                        children: [
                                          if (showDateHeader)
                                            Container(
                                              margin: const EdgeInsets.symmetric(vertical: 12),
                                              child: Text(
                                                _getMessageDateHeader(messageDate),
                                                style: const TextStyle(
                                                  color: Color(0xFF4A0072),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          MessageBubble(
                                            message: message,
                                            unitName: _selectedUnitName ?? '',
                                            onTap: () => _showReadReceipts(message['id'].toString()),
                                            onLongPress: () => _showMessageOptions(message),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              
                              // Message Input Field
                              Container(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(25),
                                          border: Border.all(
                                            color: const Color(0xFF4A0072),
                                            width: 2,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _messageController,
                                          decoration: InputDecoration(
                                            hintText: _selectedUnitId == null
                                                ? 'Select a unit first'
                                                : 'Message students here...',
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 10,
                                            ),
                                            hintStyle: TextStyle(
                                              color: const Color(0xFF4A0072).withOpacity(0.5),
                                              fontSize: 16,
                                            ),
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF4A0072),
                                          ),
                                          maxLines: 1,
                                          textAlignVertical: TextAlignVertical.center,
                                          enabled: _selectedUnitId != null,
                                          cursorColor: const Color(0xFF4A0072),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 45,
                                      height: 45,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF4A0072), Color(0xFF7B1FA2)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(23),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4A0072).withOpacity(0.3),
                                            spreadRadius: 0,
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(23),
                                          onTap: _selectedUnitId == null ? null : _sendMessage,
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Image.asset(
                                              'assets/images/sendicon.png',
                                              width: 24,
                                              height: 24,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  // Helper methods
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
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

  void _showReadReceipts(String messageId) {
    showDialog(
      context: context,
      builder: (context) => ReadReceiptDialog(messageId: messageId),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Message'),
            onTap: () {
              Navigator.pop(context);
              _editMessage(message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Message'),
                  content: const Text('Are you sure you want to delete this message?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteMessage(message['id'].toString());
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('View Read Receipts'),
            onTap: () {
              Navigator.pop(context);
              _showReadReceipts(message['id'].toString());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => EditMessageDialog(
        initialMessage: message['content'] as String,
      ),
    );

    if (result != null) {
      try {
        await _scheduleService.updateMessage(
          messageId: message['id'].toString(),
          message: result,
        );
        
        // Update the message in the local state
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == message['id']);
          if (index != -1) {
            _messages[index] = {
              ..._messages[index],
              'content': result,
            };
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating message: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _scheduleService.deleteMessage(
        messageId: messageId,
      );
      
      setState(() {
        _messages.removeWhere((message) => message['id'].toString() == messageId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit first')),
      );
      return;
    }

    if (_lecturerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lecturer ID not found')),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    try {
      await _scheduleService.sendMessage(
        unitId: _selectedUnitId!,
        message: _messageController.text,
        lecturerId: _lecturerId!,
      );

      _messageController.clear();
      _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }
}

class EditMessageDialog extends StatefulWidget {
  final String initialMessage;

  const EditMessageDialog({
    super.key,
    required this.initialMessage,
  });

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Message'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Enter new message',
        ),
        autofocus: true,
        maxLines: null,
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: const Text('Save'),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
        ),
      ],
    );
  }
}

class ReadReceiptDialog extends StatelessWidget {
  final String messageId;

  const ReadReceiptDialog({super.key, required this.messageId});

  @override
  Widget build(BuildContext context) {
    final scheduleService = ScheduleService();
    
    return Dialog(
      child: FutureBuilder<Map<String, dynamic>>(
        future: scheduleService.getMessageReadReceipts(messageId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final readReceipts = data['receipts'] as List<Map<String, dynamic>>;
          final totalStudents = data['total_students'] as int;
          final readCount = readReceipts.length;
          final readPercentage = totalStudents > 0 
              ? (readCount / totalStudents * 100).toStringAsFixed(1)
              : '0.0';

          return Container(
            constraints: const BoxConstraints(maxHeight: 400),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message info
                Text(
                  'Message Details',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Sent: ${DateFormat.yMMMd().add_jm().format(
                  DateTime.parse(data['message']['created_at']),
                )}'),
                const Divider(),

                // Statistics
                Text(
                  'Statistics',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Total Students: $totalStudents'),
                Text('Read by: $readCount ($readPercentage%)'),
                if (readReceipts.isNotEmpty)
                  Text('Last read: ${_getTimeAgo(DateTime.parse(
                    readReceipts.first['read_at'],
                  ))}'),
                const Divider(),

                // Read receipts list
                Text(
                  'Read by:',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (readReceipts.isEmpty)
                  const Text('No one has read this message yet')
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: readReceipts.length,
                      itemBuilder: (context, index) {
                        final receipt = readReceipts[index];
                        return ListTile(
                          title: Text(receipt['students']['name']),
                          subtitle: Text(DateFormat.jm()
                              .format(DateTime.parse(receipt['read_at']))),
                          trailing: receipt['device_info'] != null
                              ? Icon(
                                  _getDeviceIcon(receipt['device_info']['platform']),
                                  size: 16,
                                  color: Colors.grey[600],
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    child: const Text('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return DateFormat.yMMMd().format(dateTime);
    }
  }

  IconData _getDeviceIcon(String? platform) {
    if (platform == null) return Icons.devices;
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'windows':
        return Icons.computer;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.laptop;
      default:
        return Icons.devices;
    }
  }
}

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String unitName;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.unitName,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final messageDate = DateTime.parse(message['created_at']);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1BEE7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unitName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A0072),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message['content'],
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A0072),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        DateFormat.jm().format(messageDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: (message['read_stats']?[0]?['count'] ?? 0) > 0
                          ? const Color(0xFF4A0072)
                          : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
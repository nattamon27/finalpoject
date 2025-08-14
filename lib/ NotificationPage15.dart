// notification_page.dart
import 'package:appfinal/homepage6.2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    if (_subscription != null) {
      supabase.removeChannel(_subscription!);
    }
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('ผู้ใช้ยังไม่ล็อกอิน');
      final userId = user.id;

      final data = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final List<Map<String, dynamic>> loadedNotifications = await Future.wait(
        (data as List).map((item) => _mapNotification(item)),
      );

      setState(() {
        notifications = loadedNotifications;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        notifications = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('โหลดแจ้งเตือนไม่สำเร็จ: $e')));
    }
  }

  Future<Map<String, dynamic>> _mapNotification(dynamic mapItem) async {
    final item = mapItem as Map<String, dynamic>;
    String title = '';
    String description = item['message'] ?? '';
    IconData icon = Icons.notifications;
    Color iconBgColor = Colors.grey.shade300;
    Color iconColor = Colors.green.shade700;

    switch (item['type']) {
      case 'rating':
        title = 'ให้คะแนนบริการ';
        icon = Icons.star;
        iconBgColor = Colors.amber.shade100;
        iconColor = Colors.amber.shade700;
        break;
      case 'booking_reminder':
        title = 'เตือนการจองล่วงหน้า';
        icon = Icons.calendar_today;
        iconBgColor = Colors.blue.shade100;
        iconColor = Colors.blue.shade700;
        break;
      case 'booking_cancelled':
        title = 'แจ้งยกเลิกบริการ';
        icon = Icons.cancel;
        iconBgColor = Colors.red.shade100;
        iconColor = Colors.red.shade700;
        break;
      case 'booking_confirmed':
        title = 'การจองของคุณได้รับการยืนยันแล้ว';
        icon = Icons.check_circle;
        iconBgColor = Colors.green.shade100;
        iconColor = Colors.green.shade700;
        break;
      case 'contact_reply':
        title = 'ตอบกลับข้อความติดต่อ';
        icon = Icons.reply;
        iconBgColor = Colors.green.shade100;
        iconColor = Colors.green.shade700;

        // ดึง reply ล่าสุดจาก contactmessages
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final messages = await Supabase.instance.client
              .from('contactmessages')
              .select('reply')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(1);

          if (messages is List && messages.isNotEmpty) {
            description = messages.first['reply'] ?? description;
          }
        }
        break;
      default:
        title = 'แจ้งเตือนใหม่';
    }

    return {
      'icon': icon,
      'iconBgColor': iconBgColor,
      'iconColor': iconColor,
      'title': title,
      'description': description,
      'time': _formatTimeAgo(
        DateTime.parse(
          item['created_at'].toString().endsWith('Z')
              ? item['created_at']
              : '${item['created_at']}Z',
        ).toLocal(),
      ),
      'id': item['id'],
    };
  }

  void _setupRealtimeSubscription() {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    final channel = supabase.channel('public:notifications');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) async {
        final eventType = payload.eventType;
        final newRecord = payload.newRecord;
        final oldRecord = payload.oldRecord;

        if (!mounted) return;

        if (eventType == 'INSERT' && newRecord != null) {
          final newNotification = await _mapNotification(newRecord);
          setState(() {
            notifications.insert(0, newNotification);
            if (notifications.length > 50) {
              notifications.removeLast();
            }
          });
        } else if (eventType == 'UPDATE' && newRecord != null) {
          final updatedNotification = await _mapNotification(newRecord);
          setState(() {
            final index = notifications.indexWhere(
              (n) => n['id'] == updatedNotification['id'],
            );
            if (index != -1) {
              notifications[index] = updatedNotification;
            }
          });
        } else if (eventType == 'DELETE' && oldRecord != null) {
          final deletedId = oldRecord['id'];
          setState(() {
            notifications.removeWhere((n) => n['id'] == deletedId);
          });
        }
      },
    );

    channel.subscribe();
    _subscription = channel;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'ไม่กี่วินาทีที่แล้ว';
    if (difference.inMinutes < 60) return '${difference.inMinutes} นาทีที่แล้ว';
    if (difference.inHours < 24) return '${difference.inHours} ชั่วโมงที่แล้ว';
    if (difference.inDays < 7) return '${difference.inDays} วันที่แล้ว';
    return '${(difference.inDays / 7).floor()} สัปดาห์ที่แล้ว';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage6()),
            );
          },
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.notifications, color: Colors.white),
            SizedBox(width: 8),
            Text('การแจ้งเตือน', style: TextStyle(color: Colors.white)),
          ],
        ),
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? const Center(child: Text('ไม่มีการแจ้งเตือน'))
              : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return HoverContainer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: item['iconBgColor'],
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Icon(
                              item['icon'],
                              color: item['iconColor'],
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'],
                                  style: Theme.of(context).textTheme.titleLarge,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['description'],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      item['time'],
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class HoverContainer extends StatefulWidget {
  final Widget child;
  const HoverContainer({super.key, required this.child});

  @override
  State<HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<HoverContainer> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = Colors.grey.shade200;
    final normalColor = Colors.white;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
      },
      onExit: (_) {
        setState(() => _isHovering = false);
      },
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: _isHovering ? hoverColor : normalColor,
        child: widget.child,
      ),
    );
  }
}

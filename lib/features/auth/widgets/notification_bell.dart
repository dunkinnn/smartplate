import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';

// Bell icon with a red count badge for today's unread notifications.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  static const Color textSecondary = Color(0xFF64748B);
  static const Color badgeRed = Color(0xFFF25151);

  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final count = await unreadNotificationCount();
      if (mounted) setState(() => _unread = count);
    } catch (e) {
      debugPrint('Failed to load notification count: $e');
    }
  }

  // Opens notifications, then refreshes the badge since items may be read.
  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NotificationScreen(onBackToHome: () => Navigator.pop(context)),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _unread > 0 ? '$_unread unread notifications' : 'Notifications',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        backgroundColor: badgeRed,
        textColor: Colors.white,
        label: Text(_unread > 9 ? '9+' : '$_unread'),
        child: const Icon(
          Icons.notifications_none_rounded,
          color: textSecondary,
        ),
      ),
    );
  }
}

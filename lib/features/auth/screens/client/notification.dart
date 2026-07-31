import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';

// An alert derived from the user's own logs, not stored server side.
class AppNotification {
  final String id;
  final String title;
  final String description;
  final DateTime? time;
  final IconData icon;
  final Color iconColor;

  const AppNotification({
    required this.id,
    required this.title,
    required this.description,
    this.time,
    required this.icon,
    required this.iconColor,
  });
}

class NotificationScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const NotificationScreen({super.key, required this.onBackToHome});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Smart Plate Brand Colors
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF334155);
  static const Color lightGray = Color(0xFFF1F4F8);
  static const Color textSecondary = Color(0xFF64748B);

  List<AppNotification> _notifications = [];
  Set<String> _readIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // Read state is per day, so yesterday's keys do not silence today's alerts.
  String get _readStorageKey => 'notifications_read_$_todayKey';

  Future<void> _load() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Not signed in.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final logs = await supabase
          .from('food_logs')
          .select('meal_type, kcal, protein_g, created_at')
          .eq('user_id', user.id)
          .eq('logged_date', _todayKey)
          .timeout(const Duration(seconds: 10));

      final profile = await supabase
          .from('user_profiles')
          .select('calorie_target, protein_goal_g')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;
      setState(() {
        _readIds = (prefs.getStringList(_readStorageKey) ?? []).toSet();
        _notifications = _buildNotifications(logs as List, profile);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  // Every alert below is a plain statement of what the logs show. No advice,
  // no judgement, and nothing that nudges toward eating less than planned.
  List<AppNotification> _buildNotifications(
    List logs,
    Map<String, dynamic>? profile,
  ) {
    final now = DateTime.now();
    final result = <AppNotification>[];

    var kcal = 0;
    var protein = 0.0;
    final loggedMeals = <String>{};
    DateTime? lastLogTime;

    for (final row in logs) {
      final map = row as Map<String, dynamic>;
      kcal += (map['kcal'] as num?)?.round() ?? 0;
      protein += (map['protein_g'] as num?)?.toDouble() ?? 0;
      loggedMeals.add(map['meal_type'] as String? ?? '');

      final created = DateTime.tryParse(map['created_at'] as String? ?? '');
      if (created != null &&
          (lastLogTime == null || created.isAfter(lastLogTime))) {
        lastLogTime = created.toLocal();
      }
    }

    final target = (profile?['calorie_target'] as num?)?.round();
    final proteinGoal = (profile?['protein_goal_g'] as num?)?.toDouble();

    // Calorie progress against the target.
    if (target != null && target > 0 && kcal > 0) {
      final share = kcal / target;
      if (share >= 1.0) {
        result.add(
          AppNotification(
            id: 'calories_over',
            title: "Daily Target Reached",
            description:
                "You've logged ${_fmt(kcal)} kcal of your ${_fmt(target)} kcal target.",
            time: lastLogTime,
            icon: Icons.info_outline_rounded,
            iconColor: Colors.orange,
          ),
        );
      } else if (share >= 0.9) {
        result.add(
          AppNotification(
            id: 'calories_90',
            title: "Nearing Your Target",
            description:
                "You're at ${(share * 100).round()}% of your ${_fmt(target)} kcal target.",
            time: lastLogTime,
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.orange,
          ),
        );
      } else if (share >= 0.8) {
        result.add(
          AppNotification(
            id: 'on_track',
            title: "On Track",
            description:
                "You're at ${(share * 100).round()}% of your calorie target for today.",
            time: lastLogTime,
            icon: Icons.check_circle_outline,
            iconColor: brandGreen,
          ),
        );
      }
    }

    // Protein, reported only late in the day when the number is meaningful.
    if (proteinGoal != null && proteinGoal > 0 && now.hour >= 18 && kcal > 0) {
      if (protein < proteinGoal * 0.7) {
        result.add(
          AppNotification(
            id: 'protein_low',
            title: "Protein Below Goal",
            description:
                "Today's logs show ${protein.toStringAsFixed(0)}g of protein against a ${proteinGoal.toStringAsFixed(0)}g goal.",
            time: lastLogTime,
            icon: Icons.query_stats_rounded,
            iconColor: brandGreen,
          ),
        );
      }
    }

    // Meal reminders, once the usual window for that meal has passed.
    const windows = {'Breakfast': 10, 'Lunch': 14, 'Dinner': 21};
    windows.forEach((meal, hour) {
      if (now.hour >= hour && !loggedMeals.contains(meal)) {
        result.add(
          AppNotification(
            id: 'missing_${meal.toLowerCase()}',
            title: "$meal Not Logged",
            description: "You haven't logged $meal yet today.",
            icon: Icons.notifications_active_outlined,
            iconColor: darkBlue,
          ),
        );
      }
    });

    return result;
  }

  String _fmt(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  Future<void> _markRead(String id) async {
    if (_readIds.contains(id)) return;
    setState(() => _readIds.add(id));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readStorageKey, _readIds.toList());
  }

  Future<void> _markAllRead() async {
    setState(() => _readIds.addAll(_notifications.map((n) => n.id)));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readStorageKey, _readIds.toList());
  }

  String _formatTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((n) => !_readIds.contains(n.id))
        .length;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(unreadCount),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandGreen))
          : _error != null
          ? _buildErrorState()
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _load,
              color: brandGreen,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  // Clear the transparent app bar.
                  top: MediaQuery.of(context).padding.top + 64 + 12,
                ),
                children: _notifications
                    .map(
                      (n) => _buildNotificationItem(
                        notification: n,
                        isUnread: !_readIds.contains(n.id),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(int unreadCount) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Matches GlassHeader so titles line up across every client screen.
      toolbarHeight: 64,
      // Frosted glass, matching the other client screens.
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        // Updated to the modern/rounded iOS-style back icon
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFF1E293B),
          size: 20,
        ),
        onPressed: widget.onBackToHome,
      ),
      centerTitle: true,
      title: const HeaderTitle(
        title: "Notifications",
        subtitle: "Alerts based on your activity",
      ),
      // An icon rather than a text button, so the trailing width always
      // matches the leading back button and the title stays truly centred.
      actions: [
        SizedBox(
          width: 48,
          child: unreadCount > 0
              ? IconButton(
                  tooltip: 'Mark all as read',
                  onPressed: _markAllRead,
                  icon: const Icon(
                    Icons.done_all_rounded,
                    color: brandGreen,
                    size: 20,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 16),
            const Text(
              "Nothing to report",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Alerts appear here as you log meals through the day.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Color(0xFFF25151),
            ),
            const SizedBox(height: 14),
            const Text(
              "Could not load notifications",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Try again"),
              style: TextButton.styleFrom(foregroundColor: brandGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required AppNotification notification,
    required bool isUnread,
  }) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            // Minimalist unread indicator using subtle background tint
            color: isUnread
                ? brandGreen.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _markRead(notification.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Section with Unread Dot
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: lightGray),
                        ),
                        child: Icon(
                          notification.icon,
                          color: notification.iconColor,
                          size: 22,
                        ),
                      ),
                      if (isUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Content Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 15,
                                  color: darkBlue,
                                ),
                              ),
                            ),
                            if (notification.time != null)
                              Text(
                                _formatTime(notification.time!),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.description,
                          style: TextStyle(
                            color: isUnread
                                ? Colors.black87
                                : Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Subtle Divider to maintain clean typography and space
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, thickness: 0.5, color: lightGray),
        ),
      ],
    );
  }
}

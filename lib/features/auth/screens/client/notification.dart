import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  final VoidCallback onBackToHome;

  const NotificationScreen({super.key, required this.onBackToHome});

  // Smart Plate Brand Colors
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF334155);
  static const Color lightGray = Color(0xFFF1F4F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildNotificationItem(
            title: "Calorie Limit Reached",
            description: "You have reached 90% of your daily calorie target.",
            time: "10:30 AM",
            isUnread: true,
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.orange,
          ),
          _buildNotificationItem(
            title: "Low Protein Intake",
            description:
                "Your protein intake is below the recommended level today.",
            time: "11:30 AM",
            isUnread: true,
            icon: Icons.query_stats_rounded,
            iconColor: brandGreen,
          ),
          _buildNotificationItem(
            title: "Meal Reminder",
            description: "You haven't logged lunch yet.",
            time: "12:30 PM",
            isUnread: false,
            icon: Icons.notifications_active_outlined,
            iconColor: darkBlue,
          ),
          _buildNotificationItem(
            title: "On Track",
            description: "Great job! You’re within your calorie goal today.",
            time: "1:30 AM",
            isUnread: false,
            icon: Icons.check_circle_outline,
            iconColor: brandGreen,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      // Added consistent bottom border to match other screens
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      leading: IconButton(
        // Updated to the modern/rounded iOS-style back icon
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFF1E293B),
          size: 20,
        ),
        onPressed: onBackToHome,
      ),
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            "Notifications",
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 18,
              fontWeight:
                  FontWeight.w900, // Matching the 'Performance' header weight
              letterSpacing: -0.5,
            ),
          ),
          Text(
            "Alerts and reminders based on your activity.",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String description,
    required String time,
    required bool isUnread,
    required IconData icon,
    required Color iconColor,
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
            onTap: () {
              // Action for tapping notification
            },
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
                        child: Icon(icon, color: iconColor, size: 22),
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
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 15,
                                color: darkBlue,
                              ),
                            ),
                            Text(
                              time,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
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

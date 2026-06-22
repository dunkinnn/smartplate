import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/screens/login.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onBack;

  const ProfileScreen({super.key, required this.onBack});

  // Color Palette
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color bgGray = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkBlue,
            size: 20,
          ),
          onPressed: onBack,
        ),
        title: const Text(
          "Profile Settings",
          style: TextStyle(
            color: darkBlue,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildUserHeader(),
            const SizedBox(height: 30),

            // Account Group
            _buildSectionHeader("ACCOUNT"),
            _buildSettingsGroup([
              _buildOptionTile(
                Icons.person_outline_rounded,
                "Personal Info",
                "Name, Email, Phone",
              ),
              _buildOptionTile(
                Icons.shield_outlined,
                "Security",
                "Password and 2FA",
              ),
              _buildOptionTile(
                Icons.notifications_none_rounded,
                "Notifications",
                "Alerts & Reminders",
              ),
            ]),

            const SizedBox(height: 25),

            // Health Group
            _buildSectionHeader("HEALTH & GOALS"),
            _buildSettingsGroup([
              _buildOptionTile(
                Icons.restaurant_rounded,
                "Dietary Preferences",
                "Vegan, Keto, Allergies",
                isLast: false,
              ),
              _buildOptionTile(
                Icons.track_changes_rounded,
                "Nutritional Goals",
                "Weight loss, Muscle gain",
              ),
            ]),

            const SizedBox(height: 40),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton(
                onPressed: () {
                  // 1. Clear user session/token logic here if needed

                  // 2. Redirect to Login and clear the navigation stack
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ), // Ensure LoginScreen is imported
                    (route) =>
                        false, // This removes all previous routes from the stack
                  );
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFFEE2E2), width: 1),
                  ),
                  backgroundColor: const Color(0xFFFEF2F2),
                ),
                child: const Text(
                  "Log Out",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "App Version 1.0.0",
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: bgGray,
                backgroundImage: AssetImage('assets/images/profile.png'),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: brandGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Jemimah Jimenez",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  "Pro Member",
                  style: TextStyle(
                    color: brandGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    value: 0.8,
                    backgroundColor: borderColor,
                    color: brandGreen,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: textSecondary,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildOptionTile(
    IconData icon,
    String title,
    String subtitle, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: darkBlue, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: darkBlue,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: borderColor,
            size: 14,
          ),
          onTap: () {},
        ),
        if (!isLast) const Divider(height: 1, indent: 70, color: borderColor),
      ],
    );
  }
}

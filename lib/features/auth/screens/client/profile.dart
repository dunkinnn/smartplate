import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/alert_service.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'package:smart_plate/features/auth/screens/login.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
import 'package:smart_plate/features/auth/screens/client/settings/dietary_preferences.dart';
import 'package:smart_plate/features/auth/screens/client/settings/nutritional_goals_settings.dart';
import 'package:smart_plate/features/auth/screens/client/settings/personal_info.dart';
import 'package:smart_plate/features/auth/screens/client/settings/security.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ProfileScreen({super.key, required this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  // Shows a full-screen loader while signing out, then returns to Login.
  Future<void> _logOut() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white.withValues(alpha: 0.85),
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF67A75F)),
              SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: Text(
                  "Logging out...",
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Reminders belong to this account, so clear them on logout.
      await AlertService.cancelAll();
      await _supabase.auth.signOut();
      if (!mounted) return;

      // Removes the loader and every screen, leaving only Login.
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Failed to log out: $e');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }
  late final SupabaseClient _supabase;
  String userName = "User";
  String userEmail = "";
  String? profileImageUrl;

  // Color Palette
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color bgGray = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;

    // Show user email immediately from auth
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email ?? "No email";
        userName =
            user.userMetadata?['full_name'] ??
            user.email?.split('@')[0] ??
            "User";
      });
    }

    // Fetch additional data in background (optional)
    _fetchUserDataOptimized();
  }

  Future<void> _fetchUserDataOptimized() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        // Extra data lives in user_profiles, written by the signup wizard.
        final response = await _supabase
            .from('user_profiles')
            .select('full_name, avatar_url')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(
              const Duration(seconds: 3), // Max 3 seconds timeout
              onTimeout: () => {'full_name': null, 'avatar_url': null},
            );

        if (mounted && response != null) {
          setState(() {
            if (response['full_name'] != null) {
              userName = response['full_name'];
            }
            if (response['avatar_url'] != null) {
              profileImageUrl = response['avatar_url'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile data: $e");
      // Silently fail - we already have user email from auth
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkBlue,
            size: 20,
          ),
          onPressed: widget.onBack,
        ),
        title: const HeaderTitle(
          title: "Profile Settings",
          subtitle: "Account, health and goals",
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Clear the transparent app bar.
            SizedBox(height: MediaQuery.of(context).padding.top + 64 + 10),
            _buildUserHeader(),
            const SizedBox(height: 30),
            // Account Group
            _buildSectionHeader("ACCOUNT"),
            _buildSettingsGroup([
              _buildOptionTile(
                Icons.person_outline_rounded,
                "Personal Info",
                "Name, photo, measurements",
                onTap: () => _open(const PersonalInfoScreen()),
              ),
              _buildOptionTile(
                Icons.shield_outlined,
                "Security",
                "Change your password",
                onTap: () => _open(const SecurityScreen()),
              ),
              _buildOptionTile(
                Icons.notifications_none_rounded,
                "Notifications",
                "Alerts & Reminders",
                isLast: true,
                onTap: () => _open(
                  NotificationScreen(
                    onBackToHome: () => Navigator.pop(context),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 25),
            // Health Group
            _buildSectionHeader("HEALTH & GOALS"),
            _buildSettingsGroup([
              _buildOptionTile(
                Icons.restaurant_rounded,
                "Dietary Preferences",
                "Diet, taste, allergies",
                isLast: false,
                onTap: () => _open(const DietaryPreferencesScreen()),
              ),
              _buildOptionTile(
                Icons.track_changes_rounded,
                "Nutritional Goals",
                "Calorie target, macros",
                isLast: true,
                onTap: () => _open(const NutritionalGoalsSettingsScreen()),
              ),
            ]),
            const SizedBox(height: 40),
            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton(
                onPressed: _logOut,
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
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: bgGray,
            backgroundImage: profileImageUrl != null
                ? NetworkImage(profileImageUrl!)
                : const AssetImage('assets/images/profile.png')
                      as ImageProvider,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  userEmail,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

  // Reloads on return so an edited name or photo shows immediately.
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _fetchUserDataOptimized();
  }

  Widget _buildOptionTile(
    IconData icon,
    String title,
    String subtitle, {
    bool isLast = false,
    VoidCallback? onTap,
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
          onTap: onTap,
        ),
        if (!isLast) const Divider(height: 1, indent: 70, color: borderColor),
      ],
    );
  }
}

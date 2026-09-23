import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/calendar_days.dart';
import 'package:smart_plate/features/auth/screens/client/grocery.dart';
import 'package:smart_plate/features/auth/screens/client/insight.dart';
import 'package:smart_plate/features/auth/screens/client/meal_plan.dart';
import 'package:smart_plate/features/auth/screens/client/track.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
import 'package:smart_plate/features/auth/screens/client/profile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // Bumped on each tab switch so the other tabs reload fresh data.
  int _refreshTick = 0;
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B); // Refined dark blue
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  // Profile data loaded from Supabase.
  String? _fullName;
  String? _avatarUrl;
  int? _calorieTarget;
  bool _isLoadingProfile = true;

  // Today's totals from food_logs.
  int _consumedKcal = 0;
  int _mealsLogged = 0;

  // Today's generated meal plan, empty until one has been generated.
  List<Map<String, dynamic>> _todayPlan = [];

  // Planned meal types already marked as eaten today.
  Set<String> _eatenPlanMeals = {};

  // Consecutive days with at least one logged food, and which recent days count.
  int _streak = 0;
  bool _loggedToday = false;
  Set<String> _loggedDays = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTodayLogs();
    _loadTodayPlan();
    _loadStreak();
  }

  String _keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Counts back from today, or from yesterday while today is not logged yet.
  Future<void> _loadStreak() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now();
      final rows = await supabase
          .from('food_logs')
          .select('logged_date')
          .eq('user_id', user.id)
          .gte(
            'logged_date',
            _keyFor(today.subtract(const Duration(days: 90))),
          );

      final days = {for (final r in rows) r['logged_date'] as String};
      final loggedToday = days.contains(_keyFor(today));

      var streak = 0;
      var day = loggedToday ? today : today.subtract(const Duration(days: 1));
      while (days.contains(_keyFor(day))) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      }

      if (!mounted) return;
      setState(() {
        _streak = streak;
        _loggedToday = loggedToday;
        _loggedDays = days;
      });
    } catch (e) {
      debugPrint('Failed to load streak: $e');
    }
  }

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // Loads the dishes planned for today, if a plan exists.
  Future<void> _loadTodayPlan() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final plan = await supabase
          .from('meal_plans')
          .select('id')
          .eq('user_id', user.id)
          .eq('plan_date', _todayKey)
          .maybeSingle();

      if (plan == null) {
        if (mounted) setState(() => _todayPlan = []);
        return;
      }

      final items = await supabase
          .from('meal_plan_items')
          .select('meal_type, name, kcal')
          .eq('plan_id', plan['id'])
          .order('sort_order');

      if (!mounted) return;
      setState(
        () => _todayPlan = List<Map<String, dynamic>>.from(items as List),
      );
    } catch (e) {
      debugPrint('Failed to load today\'s plan: $e');
    }
  }

  // Counts today's calories and how many distinct meals have entries.
  Future<void> _loadTodayLogs() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final rows = await supabase
          .from('food_logs')
          .select('meal_type, kcal, source')
          .eq('user_id', user.id)
          .eq('logged_date', _todayKey);

      var kcal = 0;
      final meals = <String>{};
      final eatenPlan = <String>{};
      for (final row in rows as List) {
        kcal += ((row as Map)['kcal'] as num?)?.round() ?? 0;
        final meal = row['meal_type'] as String? ?? '';
        meals.add(meal);
        if (row['source'] == 'plan') eatenPlan.add(meal);
      }

      if (!mounted) return;
      setState(() {
        _consumedKcal = kcal;
        _mealsLogged = meals.length;
        _eatenPlanMeals = eatenPlan;
      });
    } catch (e) {
      debugPrint('Failed to load today\'s logs: $e');
    }
  }

  // Share of the calorie target consumed today, 0 when no goal is set.
  double get _goalProgress {
    final target = _calorieTarget;
    if (target == null || target <= 0) return 0;
    return (_consumedKcal / target).clamp(0.0, 1.0);
  }

  // Pulls the signed-in user's saved profile; falls back to auth metadata
  // so the greeting still works if the row is missing.
  Future<void> _loadProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final row = await supabase
          .from('user_profiles')
          .select('full_name, avatar_url, calorie_target')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _fullName =
            row?['full_name'] as String? ??
            user.userMetadata?['full_name'] as String?;
        _avatarUrl = row?['avatar_url'] as String?;
        _calorieTarget = (row?['calorie_target'] as num?)?.round();
        _isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      if (mounted) {
        setState(() {
          _fullName = user.userMetadata?['full_name'] as String?;
          _isLoadingProfile = false;
        });
      }
    }
  }

  // First name only, for the greeting.
  String get _greetingName {
    final name = _fullName?.trim();
    if (name == null || name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  // Logs and plans may have changed while the user was on another tab.
  void _selectTab(int index) {
    setState(() {
      if (index >= 1 && index != _selectedIndex) _refreshTick++;
      _selectedIndex = index;
    });
    if (index == 0) {
      _loadTodayLogs();
      _loadTodayPlan();
      _loadStreak();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeContent(),
      MealPlanScreen(
        key: ValueKey('meal-plan-$_refreshTick'),
        onBackToHome: () => _selectTab(0),
      ),
      GroceryScreen(
        key: ValueKey('grocery-$_refreshTick'),
        onBackToHome: () => setState(() => _selectedIndex = 0),
      ),
      TrackScreen(
        key: ValueKey('track-$_refreshTick'),
        onBackToHome: () => setState(() => _selectedIndex = 0),
      ),
      InsightsScreen(
        key: ValueKey('insights-$_refreshTick'),
        onBackToHome: () => setState(() => _selectedIndex = 0),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      // Content passes under the bar so the blur has something to blur.
      extendBodyBehindAppBar: true,
      appBar: _selectedIndex == 0 ? _buildHomeAppBar() : null,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _selectTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: brandGreen,
        unselectedItemColor: textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Meal Plan',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: brandGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront,
                color: Colors.white,
                size: 20,
              ),
            ),
            label: 'Grocery',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.edit_note),
            label: 'Track',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Insights',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 70,
      // The dashboard is the root of the signed-in app, so no back button.
      automaticallyImplyLeading: false,
      // Frosted glass: blur whatever scrolls beneath, tinted white so the
      // dark text stays legible, with a hairline edge to separate it.
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
      title: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 40,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.fastfood, color: brandGreen),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "SMART",
                style: TextStyle(
                  color: brandGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                "PLATE",
                style: TextStyle(
                  color: darkBlue,
                  fontSize: 10,
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationScreen(
                onBackToHome: () => Navigator.pop(context),
              ),
            ),
          ),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: textSecondary,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProfileScreen(onBack: () => Navigator.pop(context)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 15, left: 5),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: borderColor,
              backgroundImage: _avatarUrl != null
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: _avatarUrl == null
                  ? const Icon(Icons.person, size: 20, color: textSecondary)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // 1800 -> "1,800"
  String _formatNumber(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  Widget _buildHomeContent() {
    // The bar is transparent now, so the first item has to clear it manually.
    final topInset = MediaQuery.of(context).padding.top + 70;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topInset + 25),
          Text(
            _isLoadingProfile ? "Hello" : "Hello, $_greetingName",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: darkBlue,
              letterSpacing: -1,
            ),
          ),
          const Text(
            "Let's plan your meals today",
            style: TextStyle(
              color: textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 25),
          _buildStreakCard(),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildSummaryCard(
                "Calories",
                _formatNumber(_consumedKcal),
                _calorieTarget != null
                    ? "/ ${_formatNumber(_calorieTarget!)}"
                    : "logged today",
                _goalProgress,
                Icons.local_fire_department_rounded,
              ),
              const SizedBox(width: 15),
              _buildSummaryCard(
                "Log Status",
                "$_mealsLogged of 3",
                "Meals logged",
                (_mealsLogged / 3).clamp(0.0, 1.0),
                Icons.assignment_turned_in_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDailyGoalCard(),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Meal Plan",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: darkBlue,
                ),
              ),
              TextButton(
                onPressed: () => _selectTab(1),
                child: const Text(
                  "View All",
                  style: TextStyle(
                    color: brandGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_todayPlan.isEmpty)
            _buildNoPlanCard()
          else
            ..._todayPlan.map(
              (item) => _buildMealItem(
                item['meal_type'] as String? ?? 'Meal',
                item['name'] as String? ?? '',
                "${(item['kcal'] as num?)?.round() ?? 0} kcal",
              ),
            ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Current logging streak with this week's days as dots.
  Widget _buildStreakCard() {
    const streakColor = Color(0xFFF59E0B);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    // Same 7-day week from signup as the other screens.
    final lastWeek = visibleDays();

    final message = _streak == 0
        ? "Log a meal today to start a streak."
        : _loggedToday
        ? "You logged today. Keep it going tomorrow!"
        : "Log a meal today to keep your streak.";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: streakColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.whatshot_rounded,
                  color: _streak > 0 ? streakColor : textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$_streak-day streak",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: darkBlue,
                      ),
                    ),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in lastWeek)
                Column(
                  children: [
                    Container(
                      height: 26,
                      width: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _loggedDays.contains(_keyFor(d))
                            ? streakColor
                            : borderColor.withValues(alpha: 0.6),
                      ),
                      child: _loggedDays.contains(_keyFor(d))
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _keyFor(d) == _keyFor(today)
                          ? 'Today'
                          : dayLetters[d.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: _keyFor(d) == _keyFor(today)
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String mainVal,
    String subVal,
    double progress,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: brandGreen, size: 22),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: mainVal,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: darkBlue,
                    ),
                  ),
                  TextSpan(
                    text: " $subVal",
                    style: const TextStyle(
                      fontSize: 10,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: borderColor,
              color: brandGreen,
              minHeight: 6,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ), // 1px border for dark card
        boxShadow: [
          BoxShadow(
            color: darkBlue.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Daily Goal Progress",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _calorieTarget == null
                      ? "Set a calorie target to track progress."
                      : "You've consumed ${(_goalProgress * 100).round()}% of your target.",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () => _selectTab(3),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Details",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: _goalProgress,
                  strokeWidth: 8,
                  color: brandGreen,
                  backgroundColor: Colors.white10,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                "${(_goalProgress * 100).round()}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Shown when no plan has been generated for today.
  Widget _buildNoPlanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_menu_rounded,
            size: 32,
            color: borderColor,
          ),
          const SizedBox(height: 12),
          const Text(
            "No meal plan for today",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Generate one from your goals and preferences.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() => _selectedIndex = 1),
            icon: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: brandGreen,
            ),
            label: const Text(
              "Go to Meal Plan",
              style: TextStyle(color: brandGreen, fontWeight: FontWeight.w800),
            ),
            style: TextButton.styleFrom(
              backgroundColor: brandGreen.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // Icon and accent colour per meal type.
  (IconData, Color) _mealStyle(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return (Icons.wb_sunny_outlined, Colors.orange);
      case 'lunch':
        return (Icons.restaurant_rounded, brandGreen);
      case 'dinner':
        return (Icons.nights_stay_outlined, darkBlue);
      default:
        return (Icons.cookie_outlined, textSecondary);
    }
  }

  Widget _buildMealItem(String title, String dish, String kcal) {
    final (icon, accentColor) = _mealStyle(title);
    final eaten = _eatenPlanMeals.contains(title);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: darkBlue,
                  ),
                ),
                Text(
                  dish,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                kcal,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: darkBlue,
                  fontSize: 14,
                ),
              ),
              Text(
                eaten ? "eaten" : "planned",
                style: TextStyle(
                  fontSize: 10,
                  color: eaten ? brandGreen : textSecondary,
                  fontWeight: eaten ? FontWeight.w800 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      // --- THE 1PX BORDER ---
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          // Lightened shadow because the border now does the heavy lifting
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

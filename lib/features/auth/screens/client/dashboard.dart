import 'package:flutter/material.dart';
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
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B); // Refined dark blue
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildHomeContent(),
      MealPlanScreen(onBackToHome: () => setState(() => _selectedIndex = 0)),
      GroceryScreen(onBackToHome: () => setState(() => _selectedIndex = 0)),
      TrackScreen(onBackToHome: () => setState(() => _selectedIndex = 0)),
      InsightsScreen(onBackToHome: () => setState(() => _selectedIndex = 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _selectedIndex == 0 ? _buildHomeAppBar() : null,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
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
            label: 'Shop',
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
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
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
          child: const Padding(
            padding: EdgeInsets.only(right: 15, left: 5),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: borderColor,
              backgroundImage: AssetImage('assets/images/profile.png'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          const Text(
            "Hello, Jemima",
            style: TextStyle(
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
          Row(
            children: [
              _buildSummaryCard(
                "Calories",
                "1,200",
                "/ 1,800",
                0.66,
                Icons.local_fire_department_rounded,
              ),
              const SizedBox(width: 15),
              _buildSummaryCard(
                "Log Status",
                "2 of 3",
                "Meals logged",
                0.66,
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
                onPressed: () => setState(() => _selectedIndex = 1),
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
          _buildMealItem(
            "Breakfast",
            "Oatmeal with Egg",
            "350 kcal",
            Icons.wb_sunny_outlined,
            Colors.orange,
          ),
          _buildMealItem(
            "Lunch",
            "Grilled Chicken",
            "550 kcal",
            Icons.restaurant_rounded,
            brandGreen,
          ),
          _buildMealItem(
            "Dinner",
            "Vegetable Salad",
            "400 kcal",
            Icons.nights_stay_outlined,
            darkBlue,
          ),
          const SizedBox(height: 30),
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
                const Text(
                  "You've consumed 66% of your target.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {},
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
                  value: 0.66,
                  strokeWidth: 8,
                  color: brandGreen,
                  backgroundColor: Colors.white10,
                  strokeCap: StrokeCap.round,
                ),
              ),
              const Text(
                "66%",
                style: TextStyle(
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

  Widget _buildMealItem(
    String title,
    String dish,
    String kcal,
    IconData icon,
    Color accentColor,
  ) {
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
              const Text(
                "per serve",
                style: TextStyle(fontSize: 10, color: textSecondary),
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

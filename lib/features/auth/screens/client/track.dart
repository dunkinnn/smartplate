import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/screens/client/log_meal.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';

class TrackScreen extends StatefulWidget {
  final VoidCallback onBackToHome;
  const TrackScreen({super.key, required this.onBackToHome});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0); // New: Clean border color

  String selectedDate = "24";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    _buildHorizontalCalendar(),
                    const SizedBox(height: 25),
                    _buildCalorieProgressCard(),
                    const SizedBox(height: 30),

                    _buildSectionHeader("DAILY LOGS"),
                    _buildTrackMealCard("Breakfast", [
                      {"name": "Oatmeal with Egg", "kcal": "350 kcal"},
                      {"name": "Boiled Egg", "kcal": "120 kcal"},
                    ], Icons.wb_sunny_outlined),

                    _buildTrackMealCard("Lunch", [
                      {"name": "Grilled Chicken with Rice", "kcal": "550 kcal"},
                      {"name": "Steamed Vegetables", "kcal": "180 kcal"},
                    ], Icons.light_mode_outlined),

                    _buildTrackMealCard("Dinner", [
                      {"name": "Vegetable Salad", "kcal": "400 kcal"},
                      {"name": "Fruit Yogurt", "kcal": "150 kcal"},
                    ], Icons.dark_mode_outlined),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48), // Spacer for centering
          const Expanded(
            child: Column(
              children: [
                Text(
                  "Track",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),
                Text(
                  "Log meals & monitor nutrition",
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: textSecondary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationScreen(
                    onBackToHome: () => Navigator.pop(context),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar() {
    final List<Map<String, String>> days = [
      {"day": "Tue", "date": "23"},
      {"day": "Wed", "date": "24"},
      {"day": "Thu", "date": "25"},
      {"day": "Fri", "date": "26"},
      {"day": "Sat", "date": "27"},
      {"day": "Sun", "date": "28"},
      {"day": "Mon", "date": "29"},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((d) {
        bool isSelected = d["date"] == selectedDate;
        return GestureDetector(
          onTap: () => setState(() => selectedDate = d["date"]!),
          child: Column(
            children: [
              Text(
                d["day"]!,
                style: TextStyle(
                  color: isSelected ? darkBlue : textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? brandGreen : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? brandGreen : borderColor,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: brandGreen.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  d["date"]!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textMain,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalorieProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: CircularProgressIndicator(
                  value: 0.66,
                  strokeWidth: 10,
                  color: brandGreen,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  strokeCap: StrokeCap.round,
                ),
              ),
              const Column(
                children: [
                  Text(
                    "1,200",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    "kcal",
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 25),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Remaining",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  "600 kcal",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: brandGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "ON TRACK",
                    style: TextStyle(
                      color: brandGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
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
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTrackMealCard(
    String title,
    List<Map<String, String>> items,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: textSecondary, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkBlue,
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item["name"]!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: darkBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    item["kcal"]!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogMealScreen()),
              ),
              icon: const Icon(Icons.add_rounded, color: brandGreen, size: 18),
              label: const Text(
                "Log Item",
                style: TextStyle(
                  color: brandGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: bgLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

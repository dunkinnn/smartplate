import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
// import 'package:smart_plate/features/auth/screens/client/notification.dart';

class MealPlanScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const MealPlanScreen({super.key, required this.onBackToHome});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  // Executive Theme Palette
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
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
                    const SizedBox(height: 10),
                    _buildHorizontalCalendar(),
                    const SizedBox(height: 30),
                    _buildCalorieSummary(),
                    const SizedBox(height: 30),

                    _buildMealCard("Breakfast", [
                      {"name": "Oatmeal with Egg", "kcal": "350 kcal"},
                      {"name": "Boiled Egg", "kcal": "120 kcal"},
                    ]),

                    _buildMealCard("Lunch", [
                      {"name": "Grilled Chicken with Rice", "kcal": "550 kcal"},
                      {"name": "Steamed Vegetables", "kcal": "180 kcal"},
                    ]),

                    _buildMealCard("Dinner", [
                      {"name": "Vegetable Salad", "kcal": "400 kcal"},
                      {"name": "Fruit Yogurt", "kcal": "150 kcal"},
                    ]),

                    const SizedBox(height: 40),
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
                  "Meal",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),
                Text(
                  "AI-generated meal plan",
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

  Widget _buildCalorieSummary() {
    return Column(
      children: [
        const Text(
          "Daily Progress",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text(
              "1,800",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: darkBlue,
                letterSpacing: -1,
              ),
            ),
            SizedBox(width: 6),
            Text(
              "kcal",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSummaryChip(Icons.restaurant_rounded, "3 Meals"),
            const SizedBox(width: 12),
            _buildSummaryChip(
              Icons.check_circle_rounded,
              "On Track",
              color: brandGreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryChip(
    IconData icon,
    String label, {
    Color color = textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color == brandGreen ? color.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(String title, List<Map<String, String>> items) {
    IconData mealIcon;
    Color iconColor;

    switch (title.toLowerCase()) {
      case 'breakfast':
        mealIcon = Icons.wb_sunny_outlined;
        iconColor = Colors.orange.shade600;
        break;
      case 'lunch':
        mealIcon = Icons.restaurant_rounded;
        iconColor = brandGreen;
        break;
      case 'dinner':
        mealIcon = Icons.nights_stay_outlined;
        iconColor = darkBlue;
        break;
      default:
        mealIcon = Icons.fastfood_outlined;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1), // 1px Border
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 64,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(23), // Adjusted for border alignment
                  bottomLeft: Radius.circular(23),
                ),
                border: Border(right: BorderSide(color: borderColor, width: 1)),
              ),
              child: Icon(mealIcon, color: iconColor, size: 26),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: darkBlue,
                          ),
                        ),
                        const Icon(
                          Icons.more_horiz_rounded,
                          color: borderColor,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item["name"]!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textMain,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              item["kcal"]!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: darkBlue,
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
          ],
        ),
      ),
    );
  }
}

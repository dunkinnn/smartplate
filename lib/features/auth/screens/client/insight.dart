import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
// import 'package:smart_plate/features/auth/screens/client/notification.dart';

class InsightsScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const InsightsScreen({super.key, required this.onBackToHome});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color accentPink = Color(0xFFFB4B93);
  static const Color borderColor = Color(0xFFE2E8F0); // Consistent border color

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
                    const SizedBox(height: 20),
                    _buildDateSelector(),
                    const SizedBox(height: 25),
                    _buildCalorieIntakeCard(),
                    const SizedBox(height: 20),
                    _buildWeeklyTrendCard(),
                    const SizedBox(height: 20),
                    _buildNutrientDistributionCard(),
                    const SizedBox(height: 20),
                    _buildAIInsightsCard(),
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
                  "Performance",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),
                Text(
                  "Weekly Health Performance",
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

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 1), // 1px Border
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.calendar_today_rounded, size: 14, color: brandGreen),
          SizedBox(width: 10),
          Text(
            "Sept 18 – Sept 24",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: darkBlue,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildBaseCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1), // Standard 1px Border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: darkBlue,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  // Rest of your card logic using the updated _buildBaseCard...

  Widget _buildCalorieIntakeCard() {
    return _buildBaseCard(
      title: "Average Daily Intake",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 110,
                width: 110,
                child: CircularProgressIndicator(
                  value: 0.72,
                  strokeWidth: 10,
                  color: brandGreen,
                  backgroundColor: borderColor.withOpacity(0.5),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    "1,450",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: darkBlue,
                    ),
                  ),
                  Text(
                    "kcal",
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMiniStat("Daily Goal", "1,800", brandGreen),
              const SizedBox(height: 15),
              _buildMiniStat("Overall Status", "On Track", darkBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendCard() {
    return _buildBaseCard(
      title: "Weekly Calorie Trend",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar(0.4, "Mon"),
          _buildBar(0.7, "Tue"),
          _buildBar(0.9, "Wed"),
          _buildBar(0.6, "Thu"),
          _buildBar(0.8, "Fri"),
          _buildBar(0.3, "Sat"),
          _buildBar(0.5, "Sun"),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFactor, String day) {
    return Column(
      children: [
        Container(
          height: 100 * heightFactor,
          width: 30,
          decoration: BoxDecoration(
            color: heightFactor > 0.8 ? accentPink : brandGreen,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          day,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientDistributionCard() {
    return _buildBaseCard(
      title: "Macronutrients",
      child: Column(
        children: [
          _buildNutrientRow("Protein", 0.75, "112g", brandGreen),
          const SizedBox(height: 20),
          _buildNutrientRow("Carbs", 0.55, "210g", darkBlue),
          const SizedBox(height: 20),
          _buildNutrientRow("Fats", 0.35, "45g", accentPink),
        ],
      ),
    );
  }

  Widget _buildAIInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Text(
                "AI SMART ADVICE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInsightBullet(
            "Your protein is 15% lower than last week. Consider adding eggs.",
          ),
          const SizedBox(height: 12),
          _buildInsightBullet(
            "Consistency on Wednesday was peak! You hit 98% of your fiber goal.",
          ),
        ],
      ),
    );
  }

  Widget _buildInsightBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "• ",
          style: TextStyle(
            color: brandGreen,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientRow(
    String label,
    double val,
    String amount,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: darkBlue,
                fontSize: 14,
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: val,
          minHeight: 10,
          color: color,
          backgroundColor: borderColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }
}

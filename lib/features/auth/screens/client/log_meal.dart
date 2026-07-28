import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/screens/client/custom_food.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';

class LogMealScreen extends StatefulWidget {
  const LogMealScreen({super.key});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);

  String selectedDate = "24";
  String? selectedMealType = "Breakfast";

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 15),
                    _buildHorizontalCalendar(),
                    const SizedBox(height: 30),

                    const Text(
                      "SELECT MEAL",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMealTypeChips(), // Updated from Dropdown to Chips

                    const SizedBox(height: 25),
                    _buildSearchBar(),

                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedMealType ?? "Meal",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: darkBlue,
                          ),
                        ),
                        const Text(
                          "250 kcal total",
                          style: TextStyle(
                            color: brandGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    _buildFoodItem(
                      "Oatmeal",
                      "50g",
                      "150 kcal",
                      Icons.bakery_dining_rounded,
                    ),
                    _buildFoodItem(
                      "Banana",
                      "100g",
                      "100 kcal",
                      Icons.apple_rounded,
                    ),

                    const SizedBox(height: 12),
                    _buildCustomButton("Add Custom Food", Icons.add_rounded),

                    const SizedBox(height: 35),
                    _buildSummaryCard(),
                    const SizedBox(height: 25),
                    _buildSaveButton(),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: darkBlue,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  "Log Nutrition",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),
                Text(
                  "Keep your streak alive",
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                  color: isSelected ? brandGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: brandGreen.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  d["date"]!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textSecondary,
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

  Widget _buildMealTypeChips() {
    final types = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: types.map((type) {
        bool isSelected = selectedMealType == type;
        return GestureDetector(
          onTap: () => setState(() => selectedMealType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? brandGreen : bgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search food or scan barcode...",
          hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: brandGreen),
          suffixIcon: const Icon(
            Icons.qr_code_scanner_rounded,
            color: textSecondary,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItem(
    String name,
    String weight,
    String kcal,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: brandGreen, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: darkBlue,
                    fontSize: 15,
                  ),
                ),
                Text(
                  weight,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            kcal,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: darkBlue,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 15),
          const Icon(
            Icons.remove_circle_outline_rounded,
            color: Color(0xFFF25151),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomButton(String label, IconData icon) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomFoodScreen()),
      ),
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: brandGreen.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: brandGreen, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: brandGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Estimated Macros",
                style: TextStyle(fontWeight: FontWeight.w800, color: darkBlue),
              ),
              Text(
                "Per Meal",
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroInfo("Prot", "24g", brandGreen),
              _buildMacroInfo("Carb", "42g", darkBlue),
              _buildMacroInfo("Fat", "8g", const Color(0xFFFB4B93)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroInfo(String label, String val, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          val,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: darkBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "Save Meal Log",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

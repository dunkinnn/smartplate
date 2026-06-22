import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';

// --- MODEL ---
class GroceryItem {
  final String name;
  final String quantity;
  final String category;
  bool isBought;

  GroceryItem({
    required this.name,
    required this.quantity,
    required this.category,
    this.isBought = false,
  });
}

class GroceryScreen extends StatefulWidget {
  final VoidCallback onBackToHome;

  const GroceryScreen({super.key, required this.onBackToHome});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  final List<GroceryItem> _items = [
    GroceryItem(name: "Banana", quantity: "3 pcs", category: "Fruits"),
    GroceryItem(name: "Lettuce", quantity: "200 g", category: "Vegetables"),
    GroceryItem(name: "Chicken Breast", quantity: "500 g", category: "Protein"),
  ];

  @override
  Widget build(BuildContext context) {
    Map<String, List<GroceryItem>> groupedItems = {};
    for (var item in _items) {
      groupedItems.putIfAbsent(item.category, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildDateHeader(),
                  ...groupedItems.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 30,
                            bottom: 12,
                            left: 4,
                          ),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: textSecondary,
                              fontSize: 12,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        ...entry.value.map((item) => _buildGroceryTile(item)),
                      ],
                    );
                  }),
                  const SizedBox(height: 100), // Space for button
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildCompleteButton(),
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
                  "Grocery",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),
                Text(
                  "Ai-generated grocery list",
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

  Widget _buildDateHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Tue, Sept 24",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: darkBlue,
                ),
              ),
              Text(
                "Preparation for 3 meals",
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: brandGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "${_items.length} Items",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryTile(GroceryItem item) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: item.isBought ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isBought ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
        boxShadow: item.isBought
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Theme(
        data: ThemeData(
          checkboxTheme: CheckboxThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          value: item.isBought,
          activeColor: brandGreen,
          onChanged: (bool? value) => setState(() => item.isBought = value!),
          title: Text(
            item.name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: item.isBought ? textSecondary : darkBlue,
              decoration: item.isBought ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            item.quantity,
            style: TextStyle(
              fontSize: 13,
              color: item.isBought
                  ? textSecondary.withOpacity(0.5)
                  : textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          secondary: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.isBought
                  ? Colors.white.withOpacity(0.5)
                  : brandGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(item.category),
              color: item.isBought ? textSecondary : brandGreen,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Protein":
        return Icons.restaurant_menu_rounded;
      case "Fruits":
        return Icons.apple_rounded;
      case "Vegetables":
        return Icons.eco_rounded;
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  Widget _buildCompleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                darkBlue, // Changed to Dark Blue for "Executive" feel
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: darkBlue.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: () => _showSuccessModal(),
          child: const Text(
            "Finish Shopping",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: brandGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: brandGreen,
                  size: 45,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "All Set!",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Your pantry is restocked and you're ready for your healthy meal plan.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onBackToHome();
                  },
                  child: const Text(
                    "Back to Dashboard",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

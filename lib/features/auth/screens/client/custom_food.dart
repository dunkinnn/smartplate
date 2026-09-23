import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/food_entry.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';

class CustomFoodScreen extends StatefulWidget {
  const CustomFoodScreen({super.key});

  @override
  State<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends State<CustomFoodScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color fieldBg = Color(0xFFF8FAFC);

  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final caloriesController = TextEditingController();
  final proteinController = TextEditingController();
  final carbsController = TextEditingController();
  final fatController = TextEditingController();

  bool _saveToLibrary = true;
  bool _isSaving = false;

  // Inline message shown above the buttons instead of a snackbar.
  String? _message;
  bool _messageIsError = true;
  bool _libraryFailed = false;

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    super.dispose();
  }

  // Strips any unit the user typed, so "220 kcal" and "220" both work.
  double _parseNumber(String raw) =>
      double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  Future<void> _createFood() async {
    if (_isSaving) return;

    final name = nameController.text.trim();
    final kcal = _parseNumber(caloriesController.text);

    if (name.isEmpty || kcal <= 0) {
      setState(() {
        _message = 'Enter a food name and its calories.';
        _messageIsError = true;
      });
      return;
    }

    setState(() => _message = null);

    final food = FoodEntry(
      name: name,
      quantity: quantityController.text.trim(),
      kcal: kcal.round(),
      proteinG: _parseNumber(proteinController.text),
      carbsG: _parseNumber(carbsController.text),
      fatG: _parseNumber(fatController.text),
    );

    if (_saveToLibrary && !_libraryFailed) {
      setState(() => _isSaving = true);
      final saved = await _saveToFoodLibrary(food);
      if (!mounted) return;
      setState(() => _isSaving = false);

      // Do not silently discard what the user typed. Explain, and let the
      // next tap add it to this meal without saving to the library.
      if (!saved) {
        setState(() {
          _libraryFailed = true;
          _message =
              'Could not save to your library. Tap again to add it to this meal only.';
          _messageIsError = true;
        });
        return;
      }
    }

    if (mounted) Navigator.pop(context, food);
  }

  // Upserts so re-entering the same name updates it instead of erroring on
  // the unique index.
  Future<bool> _saveToFoodLibrary(FoodEntry food) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      await Supabase.instance.client.from('custom_foods').upsert({
        'user_id': user.id,
        'name': food.name,
        'quantity': food.quantity,
        'kcal': food.kcal,
        'protein_g': food.proteinG,
        'carbs_g': food.carbsG,
        'fat_g': food.fatG,
        'last_used_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,name');
      return true;
    } catch (e) {
      debugPrint('Failed to save custom food: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: GlassHeader.insetFor(context) + 25),
                _buildSectionHeader("BASIC INFORMATION"),
                _buildInputField(
                  "Food Name",
                  "e.g. Homemade Pancake",
                  Icons.restaurant_menu_rounded,
                  nameController,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        "Quantity",
                        "100g",
                        Icons.scale_rounded,
                        quantityController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputField(
                        "Calories",
                        "220 kcal",
                        Icons.local_fire_department_rounded,
                        caloriesController,
                        isNumeric: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),
                _buildSectionHeader("MACRONUTRIENTS (OPTIONAL)"),
                _buildInputField(
                  "Protein",
                  "0g",
                  Icons.fitness_center_rounded,
                  proteinController,
                  isNumeric: true,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  "Carbohydrates",
                  "0g",
                  Icons.bakery_dining_rounded,
                  carbsController,
                  isNumeric: true,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  "Fats",
                  "0g",
                  Icons.water_drop_rounded,
                  fatController,
                  isNumeric: true,
                ),
                const SizedBox(height: 24),
                _buildSaveToLibraryToggle(),
                _buildMessageBanner(),
                const SizedBox(height: 30),
                _buildActionButtons(context),
                const SizedBox(height: 30),
              ],
            ),
          ),
          _buildAppBar(context),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return GlassHeader(
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: darkBlue,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: HeaderTitle(
              title: "Custom Food",
              subtitle: "Add your own recipe",
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
          const SizedBox(width: 8), // Balances the leading spacer
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: brandGreen,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(fontWeight: FontWeight.w600, color: darkBlue),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, color: textSecondary, size: 20),
            filled: true,
            fillColor: fieldBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: brandGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // Inline, dismissible, and styled like the rest of the screen.
  Widget _buildMessageBanner() {
    final message = _message;
    if (message == null) return const SizedBox.shrink();

    final accent = _messageIsError ? const Color(0xFFF25151) : brandGreen;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _messageIsError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _message = null),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveToLibraryToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Save for later",
                  style: TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Find it by name next time you log a meal.",
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: _saveToLibrary,
            activeThumbColor: brandGreen,
            onChanged: (v) => setState(() => _saveToLibrary = v),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _createFood,
            style: ElevatedButton.styleFrom(
              backgroundColor: darkBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: darkBlue.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    _libraryFailed ? "Add to Meal" : "Create Food",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

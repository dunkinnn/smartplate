import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/widgets/notification_bell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/food_entry.dart';
import 'package:smart_plate/features/auth/models/nutrients.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
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
  bool _isEstimating = false;

  // Sugar, fiber and the rest from the last AI estimate, keyed by column.
  Map<String, double> _extra = {};

  // Name and amount the current estimate was made for.
  String? _estimatedFor;

  // Inline message shown above the buttons instead of a snackbar.
  String? _message;
  bool _messageIsError = true;
  bool _libraryFailed = false;

  @override
  void initState() {
    super.initState();
    // Rebuilds so the "estimate again" hint appears as soon as the input changes.
    nameController.addListener(() => setState(() {}));
    quantityController.addListener(() => setState(() {}));
  }

  String get _inputKey =>
      '${nameController.text.trim().toLowerCase()}|${quantityController.text.trim().toLowerCase()}';

  // True when the food or amount changed after the last estimate.
  bool get _isStale => _estimatedFor != null && _estimatedFor != _inputKey;

  // Asks the estimate-food Edge Function and fills the editable fields.
  Future<void> _estimate() async {
    if (_isEstimating) return;
    FocusScope.of(context).unfocus();

    if (nameController.text.trim().isEmpty) {
      setState(() {
        _message = 'Enter a food name first.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _isEstimating = true;
      _message = null;
    });

    try {
      final response = await Supabase.instance.client.functions
          .invoke(
            'estimate-food',
            body: {
              'name': nameController.text.trim(),
              'quantity': quantityController.text.trim(),
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = response.data;
      if (data is! Map) throw Exception('Could not estimate this food.');
      if (data['error'] != null) throw Exception(data['error']);

      double value(String key) => (data[key] as num?)?.toDouble() ?? 0;
      String fmt(double v) =>
          v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

      if (!mounted) return;
      setState(() {
        caloriesController.text = fmt(value('kcal'));
        proteinController.text = fmt(value('protein_g'));
        carbsController.text = fmt(value('carbs_g'));
        fatController.text = fmt(value('fat_g'));
        _extra = {for (final n in Nutrient.all) n.column: value(n.column)};
        _estimatedFor = _inputKey;
      });
    // Error: nutrition estimate for the custom food failed (Custom Food).
    } catch (e) {
      debugPrint('[Custom Food] Failed to estimate nutrition: $e');
      if (mounted) {
        setState(() {
          _message = friendlyError(e);
          _messageIsError = true;
        });
      }
    }

    if (mounted) setState(() => _isEstimating = false);
  }

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
        _message = name.isEmpty
            ? 'Enter a food name first.'
            : 'Tap Estimate with AI, or enter the calories yourself.';
        _messageIsError = true;
      });
      return;
    }

    setState(() => _message = null);

    // Extra nutrients are dropped if they belong to a different food or amount.
    final extra = _isStale ? const <String, double>{} : _extra;

    final food = FoodEntry(
      name: name,
      quantity: quantityController.text.trim(),
      kcal: kcal.round(),
      proteinG: _parseNumber(proteinController.text),
      carbsG: _parseNumber(carbsController.text),
      fatG: _parseNumber(fatController.text),
      sugarG: extra['sugar_g'] ?? 0,
      fiberG: extra['fiber_g'] ?? 0,
      saturatedFatG: extra['saturated_fat_g'] ?? 0,
      sodiumMg: extra['sodium_mg'] ?? 0,
      cholesterolMg: extra['cholesterol_mg'] ?? 0,
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
        'sugar_g': food.sugarG,
        'fiber_g': food.fiberG,
        'saturated_fat_g': food.saturatedFatG,
        'sodium_mg': food.sodiumMg,
        'cholesterol_mg': food.cholesterolMg,
        'last_used_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,name');
      return true;
    // Error: custom food could not be saved to the custom_foods table (Custom Food).
    } catch (e) {
      debugPrint('[Custom Food] Failed to save custom food: $e');
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
                _buildSectionHeader("FOOD"),
                _buildInputField(
                  "Food Name",
                  "e.g. Chicken adobo",
                  Icons.restaurant_menu_rounded,
                  nameController,
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  "Amount",
                  "e.g. 150 g",
                  Icons.scale_rounded,
                  quantityController,
                ),
                const SizedBox(height: 20),
                _buildEstimateButton(),
                const SizedBox(height: 35),
                _buildSectionHeader("NUTRITION (EDIT IF NEEDED)"),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        "Calories",
                        "kcal",
                        Icons.local_fire_department_rounded,
                        caloriesController,
                        isNumeric: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputField(
                        "Protein",
                        "g",
                        Icons.fitness_center_rounded,
                        proteinController,
                        isNumeric: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        "Carbs",
                        "g",
                        Icons.bakery_dining_rounded,
                        carbsController,
                        isNumeric: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputField(
                        "Fat",
                        "g",
                        Icons.water_drop_rounded,
                        fatController,
                        isNumeric: true,
                      ),
                    ),
                  ],
                ),
                _buildExtraNutrients(),
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
              subtitle: "AI fills in the nutrition",
            ),
          ),
          const NotificationBell(),
          const SizedBox(width: 8), // Balances the leading spacer
        ],
      ),
    );
  }

  // Fills the nutrition fields from the food name and amount.
  Widget _buildEstimateButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isEstimating ? null : _estimate,
            icon: _isEstimating
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: brandGreen,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              _isEstimating
                  ? "Estimating..."
                  : _estimatedFor == null
                  ? "Estimate with AI"
                  : "Estimate again",
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: brandGreen,
              side: BorderSide(
                color: brandGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            _isStale
                ? "Food or amount changed. Estimate again to update the values."
                : "Values are AI estimates. Edit them if you have a food label.",
            style: TextStyle(
              fontSize: 11,
              color: _isStale ? Colors.orange : textSecondary,
              fontWeight: _isStale ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  // Sugar, fiber and the rest from the estimate, shown read-only.
  Widget _buildExtraNutrients() {
    if (_extra.isEmpty || _isStale) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (final n in Nutrient.all)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      n.label,
                      style: const TextStyle(fontSize: 13, color: darkBlue),
                    ),
                  ),
                  Text(
                    n.format(_extra[n.column] ?? 0),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: darkBlue,
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

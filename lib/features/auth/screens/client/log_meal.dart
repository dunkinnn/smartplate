import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/widgets/notification_bell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/alert_service.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'package:smart_plate/features/auth/models/food_entry.dart';
import 'package:smart_plate/features/auth/screens/client/custom_food.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';
import 'package:smart_plate/features/auth/widgets/meal_badge.dart';
import 'package:smart_plate/features/auth/services/calendar_days.dart';

class LogMealScreen extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialMealType;
  const LogMealScreen({super.key, this.initialDate, this.initialMealType});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);

  late DateTime selectedDate;
  String selectedMealType = "Breakfast";
  bool isSaving = false;

  // Inline message shown above the save button instead of a snackbar.
  String? _message;
  bool _messageIsError = true;

  // Foods staged for this meal, saved together when the user taps Save.
  final List<FoodEntry> stagedFoods = [];

  // Saved food library, searched by the bar above the list.
  final searchController = TextEditingController();
  List<FoodEntry> _savedFoods = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate ?? DateTime.now();
    selectedMealType = widget.initialMealType ?? selectedMealType;
    _loadSavedFoods();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // Empty query shows the most recently used foods.
  Future<void> _loadSavedFoods([String query = '']) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSearching = true);

    try {
      var request = Supabase.instance.client
          .from('custom_foods')
          .select()
          .eq('user_id', user.id);

      if (query.trim().isNotEmpty) {
        request = request.ilike('name', '%${query.trim()}%');
      }

      final rows = await request
          .order('last_used_at', ascending: false)
          .limit(8)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _savedFoods = (rows as List)
            .map((r) => FoodEntry.fromRow(r as Map<String, dynamic>))
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Failed to load saved foods: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // Adds a saved food to this meal and bumps it up the recents list.
  Future<void> _addSavedFood(FoodEntry food) async {
    setState(() {
      stagedFoods.add(food);
      searchController.clear();
      _message = null; // Adding food resolves the "add a food" error.
    });

    if (food.id == null) return;
    try {
      await Supabase.instance.client
          .from('custom_foods')
          .update({'last_used_at': DateTime.now().toIso8601String()})
          .eq('id', food.id!);
    } catch (e) {
      debugPrint('Failed to bump food: $e');
    }
  }

  int get _totalKcal => stagedFoods.fold(0, (sum, food) => sum + food.kcal);
  double get _totalProtein =>
      stagedFoods.fold(0.0, (sum, food) => sum + food.proteinG);
  double get _totalCarbs =>
      stagedFoods.fold(0.0, (sum, food) => sum + food.carbsG);
  double get _totalFat => stagedFoods.fold(0.0, (sum, food) => sum + food.fatG);

  Future<void> _addCustomFood() async {
    final food = await Navigator.push<FoodEntry>(
      context,
      MaterialPageRoute(builder: (context) => const CustomFoodScreen()),
    );

    if (food != null && mounted) {
      setState(() {
        stagedFoods.add(food);
        _message = null;
      });
      _loadSavedFoods(searchController.text); // Pick up a newly saved food.
    }
  }

  void _showMessage(String text, {bool isError = true}) {
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  Future<void> _saveMealLog() async {
    if (isSaving) return;

    if (stagedFoods.isEmpty) {
      _showMessage('Add at least one food before saving.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showMessage('No user session found. Please log in again.');
      return;
    }

    setState(() {
      isSaving = true;
      _message = null;
    });

    try {
      await Supabase.instance.client
          .from('food_logs')
          .insert(
            stagedFoods
                .map(
                  (food) => food.toRow(
                    userId: user.id,
                    date: selectedDate,
                    mealType: selectedMealType,
                  ),
                )
                .toList(),
          );

      AlertService.update();
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) _showMessage(friendlyError(e));
    } catch (e) {
      if (mounted) _showMessage(friendlyError(e));
    }

    if (mounted) setState(() => isSaving = false);
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: GlassHeader.insetFor(context) + 15),
                _buildHorizontalCalendar(),
                const SizedBox(height: 28),
                _buildLabel("MEAL"),
                _buildMealTypeChips(),

                const SizedBox(height: 24),
                _buildLabel("ADD FOOD"),
                _buildSearchBar(),
                _buildSavedFoodResults(),

                const SizedBox(height: 24),
                _buildLabel("YOUR PLATE"),
                _buildPlateCard(),

                const SizedBox(height: 16),
                _buildMessageBanner(),
                const SizedBox(height: 16),
                _buildSaveButton(),
                const SizedBox(height: 30),
              ],
            ),
          ),
          _buildAppBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return GlassHeader(
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
            child: HeaderTitle(
              title: "Log Nutrition",
              subtitle: "Keep your streak alive",
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }

  // Rolling week ending today, so the dates are always current.
  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Same week and look as Track; only today can be picked, since food is
  // logged for today only.
  Widget _buildHorizontalCalendar() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const borderColor = Color(0xFFE2E8F0);
    final today = DateTime.now();
    final days = visibleDays();

    // Each day takes an equal share of the width, so it fits any screen size.
    return Row(
      children: days.map((date) {
        final isSelected = _dateKey(date) == _dateKey(selectedDate);
        final isToday = _dateKey(date) == _dateKey(today);

        return Expanded(
          child: Opacity(
            opacity: isToday || isSelected ? 1 : 0.45,
            child: GestureDetector(
              onTap: isToday ? () => setState(() => selectedDate = date) : null,
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isToday ? 'Today' : dayNames[date.weekday - 1],
                      style: TextStyle(
                        color: isSelected ? darkBlue : textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
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
                                color: brandGreen.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : darkBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }


  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Four equal chips with the same meal icons as Home and Track.
  Widget _buildMealTypeChips() {
    const types = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

    return Row(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          Expanded(child: _buildMealChip(types[i])),
          if (i < types.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildMealChip(String type) {
    final isSelected = selectedMealType == type;
    final (icon, color) = mealStyle(type);

    return GestureDetector(
      onTap: () => setState(() => selectedMealType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? brandGreen.withValues(alpha: 0.1) : bgLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? brandGreen : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? brandGreen : color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected ? brandGreen : textSecondary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Searches the user's saved foods.
  Widget _buildSearchBar() {
    return SizedBox(
      child: TextField(
        controller: searchController,
        onChanged: _loadSavedFoods,
        decoration: InputDecoration(
          hintText: "Search your saved foods...",
          hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: brandGreen),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: textSecondary,
                  onPressed: () {
                    searchController.clear();
                    _loadSavedFoods();
                  },
                ),
          filled: true,
          fillColor: bgLight,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
    );
  }

  // Tappable saved foods, shown as recents until the user types.
  Widget _buildSavedFoodResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(color: brandGreen, strokeWidth: 2),
          ),
        ),
      );
    }

    if (_savedFoods.isEmpty) {
      if (searchController.text.trim().isEmpty) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.only(top: 14, left: 4),
        child: Text(
          "No saved food matches that name.",
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            searchController.text.trim().isEmpty ? "RECENT" : "MATCHES",
            style: const TextStyle(
              color: textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _savedFoods
                .map(
                  (food) => GestureDetector(
                    onTap: () => _addSavedFood(food),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            size: 15,
                            color: brandGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            food.name,
                            style: const TextStyle(
                              color: darkBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${food.kcal} kcal",
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // Everything staged for this meal in one card: foods, add custom, and totals.
  Widget _buildPlateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MealBadge(mealType: selectedMealType, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedMealType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),
              ),
              Text(
                "$_totalKcal kcal",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (stagedFoods.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Search a saved food above, or add a custom one.",
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
            )
          else
            for (var i = 0; i < stagedFoods.length; i++)
              _buildFoodItem(i, stagedFoods[i]),
          TextButton.icon(
            onPressed: _addCustomFood,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text("Add custom food"),
            style: TextButton.styleFrom(
              foregroundColor: brandGreen,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (stagedFoods.isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            Row(
              children: [
                _buildMacroInfo("Protein", _totalProtein, brandGreen),
                const SizedBox(width: 12),
                _buildMacroInfo("Carbs", _totalCarbs, darkBlue),
                const SizedBox(width: 12),
                _buildMacroInfo("Fat", _totalFat, const Color(0xFFFB4B93)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // One staged food: name and amount, calories, and a remove button.
  Widget _buildFoodItem(int index, FoodEntry food) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: darkBlue,
                    fontSize: 14,
                  ),
                ),
                if (food.quantity.isNotEmpty)
                  Text(
                    food.quantity,
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            "${food.kcal} kcal",
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: textSecondary,
              fontSize: 13,
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => stagedFoods.removeAt(index)),
            icon: const Icon(
              Icons.close_rounded,
              color: textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // Grams for one macro across the staged foods.
  Widget _buildMacroInfo(String label, double grams, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                "${grams.round()} g",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: darkBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBanner() {
    final message = _message;
    if (message == null) return const SizedBox.shrink();

    final accent = _messageIsError ? const Color(0xFFF25151) : brandGreen;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isSaving ? null : _saveMealLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: brandGreen.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isSaving
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                "Save to Track",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}

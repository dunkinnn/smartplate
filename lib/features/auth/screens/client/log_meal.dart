import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/food_entry.dart';
import 'package:smart_plate/features/auth/screens/client/custom_food.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';

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

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage('Something went wrong. Please try again.');
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
                    _buildMealTypeChips(),

                    const SizedBox(height: 25),
                    _buildSearchBar(),
                    _buildSavedFoodResults(),

                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedMealType,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: darkBlue,
                          ),
                        ),
                        Text(
                          "$_totalKcal kcal total",
                          style: const TextStyle(
                            color: brandGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    if (stagedFoods.isEmpty)
                      _buildEmptyState()
                    else
                      ...stagedFoods.asMap().entries.map(
                        (entry) => _buildFoodItem(entry.key, entry.value),
                      ),

                    const SizedBox(height: 12),
                    _buildCustomButton("Add Custom Food", Icons.add_rounded),

                const SizedBox(height: 35),
                _buildSummaryCard(),
                _buildMessageBanner(),
                const SizedBox(height: 25),
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

  // Rolling week ending today, so the dates are always current.
  Widget _buildHorizontalCalendar() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day - (6 - i)),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((date) {
        final isSelected =
            date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day;

        return GestureDetector(
          onTap: () => setState(() => selectedDate = date),
          child: Column(
            children: [
              Text(
                dayNames[date.weekday - 1],
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
                  '${date.day}',
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

  // Searches the user's saved foods.
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
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
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
                        color: bgLight,
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.no_food_outlined, color: textSecondary, size: 32),
          SizedBox(height: 10),
          Text(
            "No food added yet",
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(int index, FoodEntry food) {
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
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: brandGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: darkBlue,
                    fontSize: 15,
                  ),
                ),
                if (food.quantity.isNotEmpty)
                  Text(
                    food.quantity,
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
            "${food.kcal} kcal",
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: darkBlue,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () => setState(() => stagedFoods.removeAt(index)),
            child: const Icon(
              Icons.remove_circle_outline_rounded,
              color: Color(0xFFF25151),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomButton(String label, IconData icon) {
    return InkWell(
      onTap: _addCustomFood,
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
              _buildMacroInfo("Prot", _totalProtein, brandGreen),
              _buildMacroInfo("Carb", _totalCarbs, darkBlue),
              _buildMacroInfo("Fat", _totalFat, const Color(0xFFFB4B93)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroInfo(String label, double grams, Color color) {
    final display = grams % 1 == 0
        ? grams.toStringAsFixed(0)
        : grams.toStringAsFixed(1);

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
          "${display}g",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: darkBlue,
          ),
        ),
      ],
    );
  }

  // Inline, dismissible, and styled like the rest of the screen. Stays on
  // screen until resolved rather than disappearing after a few seconds.
  Widget _buildMessageBanner() {
    final message = _message;
    if (message == null) return const SizedBox.shrink();

    final accent = _messageIsError
        ? const Color(0xFFF25151)
        : brandGreen;

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
      height: 60,
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
                "Save Meal Log",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}

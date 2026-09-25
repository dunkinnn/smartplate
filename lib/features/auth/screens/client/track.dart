import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/widgets/notification_bell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/nutrients.dart';
import 'package:smart_plate/features/auth/widgets/nutrient_guide_row.dart';
import 'package:smart_plate/features/auth/services/alert_service.dart';
import 'package:smart_plate/features/auth/services/calendar_days.dart';
import 'package:smart_plate/features/auth/models/food_entry.dart';
import 'package:smart_plate/features/auth/services/meal_log_service.dart';
import 'package:smart_plate/features/auth/screens/client/log_meal.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';
import 'package:smart_plate/features/auth/widgets/meal_badge.dart';

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
  static const Color borderColor = Color(0xFFE2E8F0);

  static const mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  DateTime selectedDate = DateTime.now();
  Map<String, List<FoodEntry>> logsByMeal = {};
  int? calorieTarget;
  Map<String, dynamic> _macroGoals = {};
  bool isLoading = true;

  // Sugar, fiber and the rest stay folded until the user asks for them.
  bool _showAllNutrients = false;

  // The day's generated plan by meal type, shown until the meal is eaten.
  Map<String, List<FoodEntry>> planByMeal = {};
  String? _togglingMeal;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadDay();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await MealLogService.currentStreak();
      if (mounted) setState(() => _streak = streak);
    } catch (e) {
      debugPrint('Failed to load streak: $e');
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Loads the selected day's logs plus the calorie goal they are measured against.
  Future<void> _loadDay({bool showSpinner = true}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    if (showSpinner) setState(() => isLoading = true);

    try {
      final rows = await supabase
          .from('food_logs')
          .select()
          .eq('user_id', user.id)
          .eq('logged_date', _dateKey(selectedDate))
          .order('created_at');

      final profile = await supabase
          .from('user_profiles')
          .select('calorie_target, protein_goal_g, carbs_goal_g, fat_goal_g')
          .eq('id', user.id)
          .maybeSingle();

      final plan = await supabase
          .from('meal_plans')
          .select('id')
          .eq('user_id', user.id)
          .eq('plan_date', _dateKey(selectedDate))
          .maybeSingle();

      final planItems = plan == null
          ? const []
          : await supabase
                .from('meal_plan_items')
                .select('meal_type, name, kcal, protein_g, carbs_g, fat_g')
                .eq('plan_id', plan['id'])
                .order('sort_order');

      final grouped = <String, List<FoodEntry>>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final meal = map['meal_type'] as String? ?? 'Snack';
        grouped.putIfAbsent(meal, () => []).add(FoodEntry.fromRow(map));
      }

      final planned = <String, List<FoodEntry>>{};
      for (final row in planItems) {
        final map = row as Map<String, dynamic>;
        final meal = map['meal_type'] as String? ?? 'Snack';
        planned.putIfAbsent(meal, () => []).add(FoodEntry.fromPlanItem(map));
      }

      if (!mounted) return;
      setState(() {
        logsByMeal = grouped;
        planByMeal = planned;
        calorieTarget = (profile?['calorie_target'] as num?)?.round();
        _macroGoals = profile ?? {};
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load logs: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  int get _consumedKcal => logsByMeal.values
      .expand((list) => list)
      .fold(0, (sum, food) => sum + food.kcal);

  double _total(double Function(FoodEntry) pick) => logsByMeal.values
      .expand((list) => list)
      .fold(0.0, (sum, food) => sum + pick(food));

  // Maps each tracked nutrient to its field on a logged food.
  static final Map<Nutrient, double Function(FoodEntry)> _nutrientOf = {
    Nutrient.sugar: (f) => f.sugarG,
    Nutrient.fiber: (f) => f.fiberG,
    Nutrient.saturatedFat: (f) => f.saturatedFatG,
    Nutrient.sodium: (f) => f.sodiumMg,
    Nutrient.cholesterol: (f) => f.cholesterolMg,
  };

  // Only today can be changed; other days are read-only history or plans.
  bool get _isToday => _dateKey(selectedDate) == _dateKey(DateTime.now());

  bool get _isFuture =>
      _dateKey(selectedDate).compareTo(_dateKey(DateTime.now())) > 0;

  bool _isPlanEaten(String mealType) =>
      (logsByMeal[mealType] ?? const []).any((f) => f.source == 'plan');

  int get _plannedKcal => planByMeal.values
      .expand((list) => list)
      .fold(0, (sum, food) => sum + food.kcal);

  // Marks a planned meal as eaten or undoes it; Home shares the same rows.
  Future<void> _togglePlanned(String mealType) async {
    if (_togglingMeal != null) return;
    setState(() => _togglingMeal = mealType);

    try {
      await MealLogService.setPlannedMealEaten(
        date: selectedDate,
        mealType: mealType,
        dishes: planByMeal[mealType] ?? const [],
        eaten: !_isPlanEaten(mealType),
      );
      await _loadDay(showSpinner: false);
      await _loadStreak();
    } catch (e) {
      debugPrint('Failed to update planned meal: $e');
    }

    if (mounted) setState(() => _togglingMeal = null);
  }

  // Asks before removing a hand-logged food, then deletes its food_logs row.
  Future<void> _confirmDelete(FoodEntry item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this food?'),
        content: Text(
          '${item.name} (${item.kcal} kcal) will be removed from your log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF25151),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('food_logs')
          .delete()
          .eq('id', item.id!);
      await _loadDay(showSpinner: false);
      AlertService.update();
    } catch (e) {
      debugPrint('Failed to remove food: $e');
    }
  }

  Future<void> _openLogMeal(String mealType) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LogMealScreen(initialDate: selectedDate, initialMealType: mealType),
      ),
    );
    if (saved == true) _loadDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RefreshIndicator(
            onRefresh: _loadDay,
            color: brandGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SizedBox(height: GlassHeader.insetFor(context) + 15),
                  _buildHorizontalCalendar(),
                  const SizedBox(height: 25),
                  _buildCalorieProgressCard(),
                  const SizedBox(height: 16),
                  if (!_isFuture) ...[
                    _buildNutrientsCard(),
                    const SizedBox(height: 28),
                  ],

                  _buildSectionHeader("MEALS"),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: brandGreen),
                    )
                  else
                    ...mealTypes.map(
                      (type) => _buildTrackMealCard(
                        type,
                        logsByMeal[type] ?? const [],
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
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
          const SizedBox(width: 56), // Matches trailing icon plus padding
          const Expanded(
            child: HeaderTitle(
              title: "Track",
              subtitle: "Log meals & monitor nutrition",
            ),
          ),
          const NotificationBell(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // The current 7-day week from signup.
  Widget _buildHorizontalCalendar() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final days = visibleDays();

    // Each day takes an equal share of the width, so it fits any screen size.
    return Row(
      children: days.map((date) {
        final isSelected = _dateKey(date) == _dateKey(selectedDate);
        final isToday = _dateKey(date) == _dateKey(today);
        // Days after today cannot be opened yet.
        final isFuture = _dateKey(date).compareTo(_dateKey(today)) > 0;

        return Expanded(
          child: Opacity(
            opacity: isFuture ? 0.45 : 1,
            child: GestureDetector(
            onTap: isFuture ? null : () {
              setState(() => selectedDate = date);
              _loadDay();
            },
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
                      color: isSelected ? Colors.white : textMain,
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

  Widget _buildCalorieProgressCard() {
    final target = calorieTarget;
    final consumed = _consumedKcal;
    final progress = (target != null && target > 0)
        ? (consumed / target).clamp(0.0, 1.0)
        : 0.0;
    final remaining = target != null ? target - consumed : null;
    final isOver = remaining != null && remaining < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  color: isOver ? const Color(0xFFF25151) : brandGreen,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text(
                    _formatNumber(consumed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
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
                Text(
                  isOver ? "Over by" : "Remaining",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  remaining != null
                      ? "${_formatNumber(remaining.abs())} kcal"
                      : "No goal set",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (isOver ? const Color(0xFFF25151) : brandGreen)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOver
                        ? "OVER TARGET"
                        : consumed == 0
                        ? "NOTHING LOGGED"
                        : "ON TRACK",
                    style: TextStyle(
                      color: isOver ? const Color(0xFFF25151) : brandGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                    if (_streak > 0) StreakPill(days: _streak, onDark: true),
                  ],
                ),
              ],
            ),
          ),
        ],
          ),
          if (planByMeal.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildPlanProgress(),
          ],
        ],
      ),
    );
  }

  // How many planned meals are eaten, as one segment per meal.
  Widget _buildPlanProgress() {
    final meals = mealTypes.where(planByMeal.containsKey).toList();
    final eaten = meals.where(_isPlanEaten).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "$eaten of ${meals.length} planned meals eaten",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              "Plan ${_formatNumber(_plannedKcal)} kcal",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < meals.length; i++) ...[
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: _isPlanEaten(meals[i])
                        ? brandGreen
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < meals.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  String _formatNumber(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  // Macros against goals, with sugar, fiber and the rest folded underneath.
  Widget _buildNutrientsCard() {
    Widget macro(String label, double grams, String goalKey, Color color) {
      final goal = (_macroGoals[goalKey] as num?)?.toDouble();
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              "${grams.round()} g",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: goal != null && goal > 0
                    ? (grams / goal).clamp(0.0, 1.0)
                    : 0,
                minHeight: 5,
                color: color,
                backgroundColor: borderColor,
              ),
            ),
            if (goal != null) ...[
              const SizedBox(height: 4),
              Text(
                "of ${goal.round()} g",
                style: const TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              macro("Protein", _total((f) => f.proteinG), 'protein_goal_g', brandGreen),
              const SizedBox(width: 12),
              macro("Carbs", _total((f) => f.carbsG), 'carbs_goal_g', darkBlue),
              const SizedBox(width: 12),
              macro(
                "Fat",
                _total((f) => f.fatG),
                'fat_goal_g',
                const Color(0xFFFB4B93),
              ),
            ],
          ),
          InkWell(
            onTap: () => setState(() => _showAllNutrients = !_showAllNutrients),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text(
                    _showAllNutrients ? "Hide nutrients" : "See all nutrients",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: brandGreen,
                    ),
                  ),
                  Icon(
                    _showAllNutrients
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: brandGreen,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showAllNutrients)
            for (final e in _nutrientOf.entries)
              NutrientGuideRow(nutrient: e.key, value: _total(e.value)),
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

  // Planned dish with an Ate button; once eaten it shows the logged rows.
  Widget? _buildPlannedRow(String mealType, List<FoodEntry> items) {
    final eaten = items.where((f) => f.source == 'plan').toList();
    final dishes = eaten.isNotEmpty
        ? eaten
        : planByMeal[mealType] ?? const <FoodEntry>[];
    if (dishes.isEmpty) return null;

    final isEaten = eaten.isNotEmpty;
    final busy = _togglingMeal == mealType;

    Widget action;
    if (_isToday) {
      action = SizedBox(
        height: 34,
        child: busy
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: brandGreen,
                  ),
                ),
              )
            : isEaten
            ? FilledButton.icon(
                onPressed: () => _togglePlanned(mealType),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text("Eaten"),
                style: FilledButton.styleFrom(
                  backgroundColor: brandGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : OutlinedButton(
                onPressed: () => _togglePlanned(mealType),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandGreen,
                  side: const BorderSide(color: brandGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text("Ate"),
              ),
      );
    } else {
      action = Text(
        isEaten
            ? "Eaten"
            : _isFuture
            ? "Planned"
            : "Not eaten",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isEaten ? brandGreen : textSecondary,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: isEaten ? brandGreen.withValues(alpha: 0.08) : bgLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "FROM YOUR PLAN",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                for (final d in dishes)
                  Text(
                    "${d.name} · ${d.kcal} kcal",
                    style: const TextStyle(
                      fontSize: 14,
                      color: darkBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }

  Widget _buildTrackMealCard(String title, List<FoodEntry> items) {
    final planned = _buildPlannedRow(title, items);
    final extras = items.where((f) => f.source != 'plan').toList();
    final kcal = items.fold(0, (s, f) => s + f.kcal);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MealBadge(mealType: title, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),
              ),
              Text(
                kcal == 0 ? "—" : "$kcal kcal",
                style: const TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ?planned,
          // Foods added with Add food, listed under the planned dish.
          for (final item in extras)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.quantity.isEmpty
                          ? item.name
                          : "${item.name} (${item.quantity})",
                      style: const TextStyle(
                        fontSize: 14,
                        color: darkBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    "${item.kcal} kcal",
                    style: const TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Hand-logged foods can be removed on the same day only.
                  if (_isToday && item.id != null)
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDelete(item),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: textSecondary,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          if (planned == null && extras.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                "Nothing logged",
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
            ),
          // Extra foods can only be logged for today.
          if (_isToday)
            TextButton.icon(
              onPressed: () => _openLogMeal(title),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Add food"),
              style: TextButton.styleFrom(
                foregroundColor: brandGreen,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

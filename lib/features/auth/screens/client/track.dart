import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/services/calendar_days.dart';
import 'package:smart_plate/features/auth/models/food_entry.dart';
import 'package:smart_plate/features/auth/services/meal_log_service.dart';
import 'package:smart_plate/features/auth/screens/client/log_meal.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
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
  bool isLoading = true;

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
          .select('calorie_target')
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
                  const SizedBox(height: 30),

                  _buildSectionHeader("DAILY LOGS"),
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

  // The current 7-day week from signup.
  Widget _buildHorizontalCalendar() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final days = visibleDays();

    // A full week spreads out; fewer days since signup sit to the left.
    return Row(
      mainAxisAlignment: days.length == 7
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      children: days.map((date) {
        final isSelected = _dateKey(date) == _dateKey(selectedDate);
        final isToday = _dateKey(date) == _dateKey(today);

        return Padding(
          padding: EdgeInsets.only(right: days.length == 7 ? 0 : 12),
          child: GestureDetector(
            onTap: () {
              setState(() => selectedDate = date);
              _loadDay();
            },
            child: Column(
              children: [
                Text(
                  isToday ? 'Today' : dayNames[date.weekday - 1],
                  style: TextStyle(
                    color: isSelected ? darkBlue : textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w800
                        : FontWeight.normal,
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
      child: Row(
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
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
                if (_streak > 0) ...[
                  const SizedBox(height: 10),
                  StreakPill(days: _streak, onDark: true),
                ],
                if (planByMeal.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Plan ${_formatNumber(_plannedKcal)} kcal · "
                    "${planByMeal.keys.where(_isPlanEaten).length} of "
                    "${planByMeal.length} meals eaten",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

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

  // Planned dish with an eaten check; shows the logged rows once eaten.
  List<Widget> _buildPlannedRows(String mealType, List<FoodEntry> items) {
    final eaten = items.where((f) => f.source == 'plan').toList();
    final dishes = eaten.isNotEmpty
        ? eaten
        : planByMeal[mealType] ?? const <FoodEntry>[];
    if (dishes.isEmpty) return const [];

    final isEaten = eaten.isNotEmpty;
    final busy = _togglingMeal == mealType;
    final label = isEaten
        ? "FROM YOUR PLAN · EATEN"
        : _isFuture
        ? "PLANNED"
        : _isToday
        ? "PLANNED · TAP IF EATEN"
        : "PLANNED · NOT EATEN";

    return [
      InkWell(
        onTap: busy || !_isToday ? null : () => _togglePlanned(mealType),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isEaten ? brandGreen.withValues(alpha: 0.08) : bgLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: brandGreen,
                      ),
                    )
                  : Icon(
                      isEaten
                          ? Icons.check_circle_rounded
                          : _isFuture
                          ? Icons.schedule_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isEaten ? brandGreen : textSecondary,
                      size: 20,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isEaten ? brandGreen : textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ...dishes.map(
                      (d) => Text(
                        d.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: darkBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "${dishes.fold(0, (s, d) => s + d.kcal)} kcal",
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
    ];
  }

  Widget _buildTrackMealCard(
    String title,
    List<FoodEntry> items,
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
              MealBadge(mealType: title),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkBlue,
                ),
              ),
              const Spacer(),
              Text(
                items.isEmpty
                    ? "—"
                    : "${items.fold(0, (s, f) => s + f.kcal)} kcal",
                style: const TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildPlannedRows(title, items),
          if (items.isEmpty && (planByMeal[title] ?? const []).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                "Nothing logged yet",
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            ...items
                .where((f) => f.source != 'plan')
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ),
          // Extra foods can only be logged for today.
          if (_isToday) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton.icon(
                onPressed: () => _openLogMeal(title),
                icon: const Icon(
                  Icons.add_rounded,
                  color: brandGreen,
                  size: 18,
                ),
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
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/widgets/notification_bell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/nutrients.dart';
import 'package:smart_plate/features/auth/widgets/nutrient_guide_row.dart';
import 'package:smart_plate/features/auth/widgets/meal_badge.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'package:smart_plate/features/auth/services/calendar_days.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';
import 'package:smart_plate/features/auth/screens/client/plan_confirmed.dart';

class MealPlanScreen extends StatefulWidget {
  final VoidCallback onBackToHome;
  final VoidCallback? onOpenTrack;

  const MealPlanScreen({
    super.key,
    required this.onBackToHome,
    this.onOpenTrack,
  });

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  // Executive Theme Palette
  static const Color brandGreen = Color(0xFF67A75F);
  static const Color darkBlue = Color(0xFF1E293B);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  static const mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  DateTime selectedDate = DateTime.now();
  Map<String, List<Map<String, dynamic>>> itemsByMeal = {};
  int totalKcal = 0;
  bool isLoading = true;
  bool isGenerating = false;

  // A confirmed plan is final for the day and hides Regenerate.
  bool isSaved = false;
  bool isSaving = false;

  bool get _isToday => _dateKey(selectedDate) == _dateKey(DateTime.now());

  // Sugar, fiber and the rest stay folded until the user asks for them.
  bool _showAllNutrients = false;

  bool get _isFuture =>
      _dateKey(selectedDate).compareTo(_dateKey(DateTime.now())) > 0;

  // Goals the plan is measured against, from user_profiles.
  Map<String, dynamic> _goals = {};

  // Plan status per date in the calendar: 'planned' or 'confirmed'.
  Map<String, String> _weekStatus = {};

  // Inline message instead of a snackbar.
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Loads the saved plan for the selected date, if one has been generated.
  Future<void> _loadPlan() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      final days = visibleDays();
      final week = await supabase
          .from('meal_plans')
          .select('plan_date, saved_at')
          .eq('user_id', user.id)
          .gte('plan_date', _dateKey(days.first))
          .lte('plan_date', _dateKey(days.last));

      final goals = await supabase
          .from('user_profiles')
          .select(
            'calorie_target, protein_goal_g, carbs_goal_g, fat_goal_g, allergen',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _goals = goals ?? {};
          _weekStatus = {
            for (final r in week)
              r['plan_date'] as String: r['saved_at'] != null
                  ? 'confirmed'
                  : 'planned',
          };
        });
      }

      final plan = await supabase
          .from('meal_plans')
          .select('id, total_kcal, saved_at')
          .eq('user_id', user.id)
          .eq('plan_date', _dateKey(selectedDate))
          .maybeSingle();

      if (plan == null) {
        if (!mounted) return;
        setState(() {
          itemsByMeal = {};
          isSaved = false;
          totalKcal = 0;
          isLoading = false;
        });
        return;
      }

      final items = await supabase
          .from('meal_plan_items')
          .select()
          .eq('plan_id', plan['id'])
          .order('sort_order');

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in items as List) {
        final map = row as Map<String, dynamic>;
        final meal = map['meal_type'] as String? ?? 'Snack';
        grouped.putIfAbsent(meal, () => []).add(map);
      }

      if (!mounted) return;
      setState(() {
        itemsByMeal = grouped;
        isSaved = plan['saved_at'] != null;
        totalKcal = (plan['total_kcal'] as num?)?.round() ?? 0;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load meal plan: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Asks the Edge Function for a plan, then reloads from the database.
  Future<void> _generatePlan() async {
    if (isGenerating) return;
    setState(() {
      isGenerating = true;
      _message = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate-meal-plan',
        body: {'plan_date': _dateKey(selectedDate)},
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }

      await _loadPlan();
    } catch (e) {
      // Covers function errors (e.g. the daily limit) and network failures.
      if (mounted) setState(() => _message = friendlyError(e));
    }

    if (mounted) setState(() => isGenerating = false);
  }

  // Confirms the plan for the day; eating is recorded in Track.
  Future<void> _usePlan() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null || isSaving) return;

    setState(() {
      isSaving = true;
      _message = null;
    });

    try {
      final updated = await supabase
          .from('meal_plans')
          .update({'saved_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', user.id)
          .eq('plan_date', _dateKey(selectedDate))
          .select('id');
      if ((updated as List).isEmpty) throw Exception('Plan not updated');

      if (mounted) {
        setState(() => isSaved = true);
        // A confirmation screen replaces the old in-page banner.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanConfirmedScreen(
              totalKcal: totalKcal,
              meals: [
                for (final type in mealOrder)
                  for (final item in itemsByMeal[type] ?? const [])
                    (type, item['name'] as String? ?? ''),
              ],
              onOpenTrack: widget.onOpenTrack,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to confirm meal plan: $e');
      if (mounted) setState(() => _message = 'Could not confirm your plan.');
    }

    if (mounted) setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasPlan = itemsByMeal.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RefreshIndicator(
            onRefresh: _loadPlan,
            color: brandGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SizedBox(height: GlassHeader.insetFor(context) + 10),
                  _buildHorizontalCalendar(),
                  const SizedBox(height: 12),
                  _buildCalendarLegend(),
                  _buildMessageBanner(),
                  const SizedBox(height: 30),

                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: CircularProgressIndicator(color: brandGreen),
                    )
                  else if (!hasPlan)
                    _buildEmptyState()
                  else ...[
                    _buildCalorieSummary(),
                    const SizedBox(height: 28),
                    _buildSectionHeader(),
                    const SizedBox(height: 12),
                    ...mealOrder
                        .where((type) => itemsByMeal.containsKey(type))
                        .map(
                          (type) => _buildMealCard(type, itemsByMeal[type]!),
                        ),
                    const SizedBox(height: 8),
                    if (_isToday)
                      _buildPlanActions()
                    else
                      const Text(
                        "Past plan, view only.",
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    const SizedBox(height: 16),
                    _buildAllergyNote(),
                  ],

                  const SizedBox(height: 40),
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
              title: "Meal Plan",
              subtitle: "Your AI meal plan for today",
            ),
          ),
          const NotificationBell(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // The current 7-day week from signup; only today can be generated.
  Widget _buildHorizontalCalendar() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final days = visibleDays();

    // Each day takes an equal share of the width, so it fits any screen size.
    return Row(
      children: days.map((date) {
        final isSelected = _dateKey(date) == _dateKey(selectedDate);
        final isToday = _dateKey(date) == _dateKey(today);

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => selectedDate = date);
              _loadPlan();
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
                const SizedBox(height: 6),
                // Green dot for a confirmed plan, outlined dot for a draft plan.
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _weekStatus[_dateKey(date)] == 'confirmed'
                        ? brandGreen
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _weekStatus.containsKey(_dateKey(date))
                          ? brandGreen
                          : Colors.transparent,
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

  // Inline, dismissible, styled like the rest of the screen.
  Widget _buildMessageBanner() {
    final message = _message;
    if (message == null) return const SizedBox.shrink();

    const accent = Color(0xFFF25151);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
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
            const Icon(Icons.error_outline_rounded, color: accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
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

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.restaurant_menu_rounded, size: 48, color: borderColor),
        const SizedBox(height: 16),
        Text(
          _isToday
              ? "No plan for today yet"
              : _isFuture
              ? "Not planned yet"
              : "No plan was made for this day",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isToday
              ? "Generate one from your goals, diet and allergies."
              : _isFuture
              ? "You can generate this plan on that day."
              : "Meal plans can only be generated for the current day.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_isToday) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: isGenerating ? null : _generatePlan,
              icon: isGenerating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 20),
              label: Text(
                isGenerating ? "Generating..." : "Generate Meal Plan",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: brandGreen.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Plans are checked against allergies, but hidden ingredients cannot be.
  Widget _buildAllergyNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Always check ingredients and labels if you have a severe allergy. "
              "Plans are checked against your allergies, but store-bought "
              "sauces and mixes can contain hidden ingredients.",
              style: TextStyle(fontSize: 12, color: textMain, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // Regenerate and Use this plan side by side; nothing once confirmed.
  Widget _buildPlanActions() {
    // Confirmed plans need no buttons; the calendar dot shows the status.
    if (isSaved) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(child: _buildRegenerateButton()),
        const SizedBox(width: 12),
        Expanded(child: _buildSaveButton()),
      ],
    );
  }

  Widget _buildSaveButton() {
    final busy = isSaving || isGenerating;

    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: busy ? null : _usePlan,
        icon: isSaving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.check_rounded, size: 18),
        label: Text(
          isSaving ? "Saving..." : "Use this plan",
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildRegenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: isGenerating || isSaving ? null : _generatePlan,
        icon: isGenerating
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  color: brandGreen,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.refresh_rounded, size: 18, color: brandGreen),
        label: Text(
          isGenerating ? "Generating..." : "Regenerate",
          style: const TextStyle(
            color: brandGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: brandGreen.withValues(alpha: 0.5),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // One card: planned total, goal check and macros, with other nutrients folded.
  Widget _buildCalorieSummary() {
    final mealCount = itemsByMeal.values.fold(0, (s, l) => s + l.length);
    final target = (_goals['calorie_target'] as num?)?.round();
    final fitsGoal =
        target != null && (totalKcal - target).abs() <= target * 0.1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PLANNED TOTAL",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _formatNumber(totalKcal),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: darkBlue,
                              letterSpacing: -1,
                            ),
                          ),
                          const TextSpan(
                            text: " kcal",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "$mealCount meals · AI generated",
                      style: const TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (target != null) _buildGoalPill(target, fitsGoal),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMacroStat("Protein", 'protein_g', 'protein_goal_g', brandGreen),
              const SizedBox(width: 12),
              _buildMacroStat("Carbs", 'carbs_g', 'carbs_goal_g', darkBlue),
              const SizedBox(width: 12),
              _buildMacroStat(
                "Fat",
                'fat_g',
                'fat_goal_g',
                const Color(0xFFFB4B93),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showAllNutrients = !_showAllNutrients),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
          if (_showAllNutrients) ...[
            const SizedBox(height: 4),
            for (final n in Nutrient.all)
              NutrientGuideRow(nutrient: n, value: _sumOf(n.column)),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalPill(int target, bool fitsGoal) {
    final color = fitsGoal ? brandGreen : textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fitsGoal ? Icons.check_circle_rounded : Icons.flag_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            fitsGoal ? "Fits goal" : "Goal ${_formatNumber(target)}",
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

  double _sumOf(String key) => itemsByMeal.values
      .expand((l) => l)
      .fold(0.0, (s, i) => s + ((i[key] as num?)?.toDouble() ?? 0));

  // Grams planned for one macro, with a thin bar against the user's goal.
  Widget _buildMacroStat(String label, String key, String goalKey, Color color) {
    final value = _sumOf(key);
    final goal = (_goals[goalKey] as num?)?.toDouble();
    final progress = goal != null && goal > 0
        ? (value / goal).clamp(0.0, 1.0)
        : 0.0;

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
            "${value.round()} g",
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
              value: progress,
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

  Widget _buildSectionHeader() {
    return const Row(
      children: [
        Text(
          "MEALS",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        Spacer(),
        Text(
          "Tap a dish for details",
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildCalendarLegend() {
    Widget dot(bool filled) => Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: filled ? brandGreen : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: brandGreen),
      ),
    );
    const style = TextStyle(fontSize: 11, color: textSecondary);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(false),
        const SizedBox(width: 6),
        const Text("Planned", style: style),
        const SizedBox(width: 16),
        dot(true),
        const SizedBox(width: 6),
        const Text("Confirmed", style: style),
      ],
    );
  }

  // Ingredients, macros and allergy note for one dish.
  void _showDishDetails(String mealType, Map<String, dynamic> item) {
    final ingredients = (item['ingredients'] as List?) ?? const [];
    final allergen = (_goals['allergen'] as String? ?? '').trim();
    final hasAllergen = allergen.isNotEmpty && allergen.toLowerCase() != 'none';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              mealType.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['name'] as String? ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildNutrientTile("kcal", item['kcal']),
                _buildNutrientTile("Protein", item['protein_g'], unit: 'g'),
                _buildNutrientTile("Carbs", item['carbs_g'], unit: 'g'),
                _buildNutrientTile("Fat", item['fat_g'], unit: 'g'),
              ],
            ),
            const SizedBox(height: 16),
            for (final n in Nutrient.all)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      n.label,
                      style: const TextStyle(fontSize: 13, color: textMain),
                    ),
                    const Spacer(),
                    Text(
                      n.format((item[n.column] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: darkBlue,
                      ),
                    ),
                  ],
                ),
              ),
            if (hasAllergen) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: brandGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Checked against your allergies: $allergen",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: brandGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildAllergyNote(),
            const SizedBox(height: 24),
            const Text(
              "INGREDIENTS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            for (final raw in ingredients)
              if (raw is Map)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          raw['name'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textMain,
                          ),
                        ),
                      ),
                      Text(
                        raw['quantity'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientTile(String label, Object? value, {String unit = ''}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            "${(value as num?)?.round() ?? 0}$unit",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: darkBlue,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  // Meal type header with the same icon tile as Home, then its dishes.
  Widget _buildMealCard(String title, List<Map<String, dynamic>> items) {
    final mealKcal = items.fold(
      0,
      (sum, i) => sum + ((i['kcal'] as num?)?.round() ?? 0),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
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
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  "$mealKcal kcal",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items)
            InkWell(
              onTap: () => _showDishDetails(title, item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 8, 0, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['name'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: textMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

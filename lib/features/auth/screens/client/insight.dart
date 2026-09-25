import 'package:flutter/material.dart';
import 'package:smart_plate/features/auth/widgets/notification_bell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/nutrients.dart';
import 'package:smart_plate/features/auth/widgets/nutrient_guide_row.dart';
import 'package:smart_plate/features/auth/services/friendly_error.dart';
import 'package:smart_plate/features/auth/services/calendar_days.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';
import 'package:smart_plate/features/auth/widgets/meal_badge.dart';
import 'package:smart_plate/features/auth/services/meal_log_service.dart';

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

  // Daily totals for the trailing week, oldest first.
  List<_DayTotals> _week = [];
  int? _calorieTarget;
  double? _proteinGoal;
  double? _carbsGoal;
  double? _fatGoal;
  bool _isLoading = true;
  int _streak = 0;

  // Sugar, fiber and the rest stay folded until the user asks for them.
  bool _showAllNutrients = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeek();
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

  // Same 7-day week from signup as Meal Plan and Track.
  List<DateTime> get _weekDays => visibleDays();

  // Days of this week up to and including today; future days cannot be logged.
  int get _daysSoFar {
    final today = _key(DateTime.now());
    return _weekDays.where((d) => _key(d).compareTo(today) <= 0).length;
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadWeek() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Not signed in.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final days = _weekDays;

      final rows = await supabase
          .from('food_logs')
          .select(
            'logged_date, kcal, protein_g, carbs_g, fat_g, '
            'sugar_g, fiber_g, saturated_fat_g, sodium_mg, cholesterol_mg',
          )
          .eq('user_id', user.id)
          .gte('logged_date', _key(days.first))
          .lte('logged_date', _key(days.last))
          .timeout(const Duration(seconds: 10));

      final profile = await supabase
          .from('user_profiles')
          .select('calorie_target, protein_goal_g, carbs_goal_g, fat_goal_g')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      final totals = {for (final d in days) _key(d): _DayTotals(d)};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final day = totals[map['logged_date'] as String? ?? ''];
        if (day == null) continue;
        day.kcal += (map['kcal'] as num?)?.round() ?? 0;
        day.protein += (map['protein_g'] as num?)?.toDouble() ?? 0;
        day.carbs += (map['carbs_g'] as num?)?.toDouble() ?? 0;
        day.fat += (map['fat_g'] as num?)?.toDouble() ?? 0;
        for (final n in Nutrient.all) {
          day.extra[n] =
              (day.extra[n] ?? 0) + ((map[n.column] as num?)?.toDouble() ?? 0);
        }
      }

      if (!mounted) return;
      setState(() {
        _week = days.map((d) => totals[_key(d)]!).toList();
        _calorieTarget = (profile?['calorie_target'] as num?)?.round();
        _proteinGoal = (profile?['protein_goal_g'] as num?)?.toDouble();
        _carbsGoal = (profile?['carbs_goal_g'] as num?)?.toDouble();
        _fatGoal = (profile?['fat_goal_g'] as num?)?.toDouble();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load insights: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  // Only days with entries count, so one logged day does not read as a
  // seventh of itself.
  List<_DayTotals> get _loggedDays => _week.where((d) => d.kcal > 0).toList();

  int get _avgKcal {
    final days = _loggedDays;
    if (days.isEmpty) return 0;
    return (days.fold(0, (s, d) => s + d.kcal) / days.length).round();
  }

  double _avgMacro(double Function(_DayTotals) pick) {
    final days = _loggedDays;
    if (days.isEmpty) return 0;
    return days.fold(0.0, (s, d) => s + pick(d)) / days.length;
  }

  String _formatNumber(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        // Every child is positioned, so the Stack needs an explicit size.
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: brandGreen),
                  )
                : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadWeek,
                    color: brandGreen,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          SizedBox(height: GlassHeader.insetFor(context) + 20),
                          // Wraps to a second line on narrow screens.
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _buildDateSelector(),
                              if (_streak > 0) StreakPill(days: _streak),
                            ],
                          ),
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
              title: "Insights",
              subtitle: "Your week at a glance",
            ),
          ),
          const NotificationBell(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Color(0xFFF25151),
            ),
            const SizedBox(height: 14),
            const Text(
              "Could not load your insights",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadWeek,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Try again"),
              style: TextButton.styleFrom(foregroundColor: brandGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = _weekDays;
    final from = days.first;
    final to = days.last;
    final label =
        '${months[from.month - 1]} ${from.day} – ${months[to.month - 1]} ${to.day}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 1), // 1px Border
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: brandGreen),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: darkBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // Average intake this week against the goal, in the same style as Meal Plan.
  Widget _buildCalorieIntakeCard() {
    final target = _calorieTarget;
    final avg = _avgKcal;
    final progress = (target != null && target > 0)
        ? (avg / target).clamp(0.0, 1.0)
        : 0.0;

    final (status, statusColor) = _loggedDays.isEmpty
        ? ("No data yet", textSecondary)
        : target == null
        ? ("No goal set", textSecondary)
        : avg > target * 1.1
        ? ("Over target", accentPink)
        : avg < target * 0.8
        ? ("Under target", textSecondary)
        : ("On track", brandGreen);

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
                      "AVERAGE DAILY INTAKE",
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
                            text: _formatNumber(avg),
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
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: statusColor == accentPink ? accentPink : brandGreen,
              backgroundColor: borderColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "${target != null ? 'Goal ${_formatNumber(target)} kcal · ' : ''}"
            "${_loggedDays.length} of $_daysSoFar days logged",
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendCard() {
    // Scale against the goal so bars mean "share of target", falling back to
    // the week's own peak when no goal exists.
    final target = _calorieTarget;
    final peak = _week.fold(0, (m, d) => d.kcal > m ? d.kcal : m);
    final scale = (target != null && target > 0)
        ? target
        : (peak == 0 ? 1 : peak);

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = _key(DateTime.now());

    return _buildBaseCard(
      title: "Weekly Calorie Trend",
      trailing: target != null
          ? Text(
              "- - goal",
              style: TextStyle(
                fontSize: 11,
                color: textSecondary.withValues(alpha: 0.8),
              ),
            )
          : null,
      child: _loggedDays.isEmpty
          ? _buildNoDataRow("Log a meal to see your trend.")
          : Stack(
              children: [
                // Goal line at full bar height, since bars are scaled to the goal.
                if (target != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 1,
                      color: textSecondary.withValues(alpha: 0.35),
                    ),
                  ),
                Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _week
                  .map(
                    (day) => _buildBar(
                      (day.kcal / scale).clamp(0.0, 1.0),
                      _key(day.date) == today
                          ? 'Today'
                          : dayNames[day.date.weekday - 1],
                      target != null && day.kcal > target,
                      isFuture: _key(day.date).compareTo(today) > 0,
                    ),
                  )
                  .toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildBar(
    double heightFactor,
    String day,
    bool isOver, {
    bool isFuture = false,
  }) {
    return Column(
      children: [
        // Fixed-height slot so every bar starts from the same baseline.
        SizedBox(
          height: 100,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
          // Keeps empty days visible as a sliver rather than nothing at all.
          height: (100 * heightFactor).clamp(4.0, 100.0),
          width: 22,
          decoration: BoxDecoration(
            // Days still ahead in the week are shown as a faint placeholder.
            color: isFuture
                ? borderColor
                : isOver
                ? accentPink
                : brandGreen,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
          ),
        ),
        const SizedBox(height: 8),
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

  Widget _buildNoDataRow(String message) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientDistributionCard() {
    return _buildBaseCard(
      title: "Nutrients (daily average)",
      child: _loggedDays.isEmpty
          ? _buildNoDataRow("No nutrients logged this week.")
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildMacroStat(
                      "Protein",
                      _avgMacro((d) => d.protein),
                      _proteinGoal,
                      brandGreen,
                    ),
                    const SizedBox(width: 12),
                    _buildMacroStat(
                      "Carbs",
                      _avgMacro((d) => d.carbs),
                      _carbsGoal,
                      darkBlue,
                    ),
                    const SizedBox(width: 12),
                    _buildMacroStat(
                      "Fat",
                      _avgMacro((d) => d.fat),
                      _fatGoal,
                      accentPink,
                    ),
                  ],
                ),
                InkWell(
                  onTap: () =>
                      setState(() => _showAllNutrients = !_showAllNutrients),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Text(
                          _showAllNutrients
                              ? "Hide nutrients"
                              : "See all nutrients",
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
                  for (final n in Nutrient.all)
                    NutrientGuideRow(
                      nutrient: n,
                      value: _avgMacro((d) => d.extra[n] ?? 0),
                    ),
              ],
            ),
    );
  }

  // Average grams for one macro with a thin bar against the goal.
  Widget _buildMacroStat(
    String label,
    double grams,
    double? goal,
    Color color,
  ) {
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

  // Tips computed from this week's logs; descriptive, never medical.
  List<String> get _adviceTips {
    final days = _loggedDays;
    if (days.isEmpty) {
      return [
        'Mark meals as eaten in Track or on Home to get tips for your week.',
      ];
    }

    final tips = <String>[];
    final target = _calorieTarget;
    if (target != null && target > 0) {
      final diff = _avgKcal - target;
      if (diff.abs() <= target * 0.1) {
        tips.add(
          'Your average intake is within 10% of your ${_formatNumber(target)} kcal goal. Keep it up.',
        );
      } else if (diff > 0) {
        tips.add(
          'You averaged ${_formatNumber(diff)} kcal above your goal on logged days.',
        );
      } else {
        tips.add(
          'You averaged ${_formatNumber(-diff)} kcal below your goal on logged days.',
        );
      }
    }

    final macros = {
      'Protein': (_avgMacro((d) => d.protein), _proteinGoal),
      'Carbs': (_avgMacro((d) => d.carbs), _carbsGoal),
      'Fat': (_avgMacro((d) => d.fat), _fatGoal),
    };
    for (final m in macros.entries) {
      final (avg, goal) = m.value;
      if (goal != null && goal > 0 && avg < goal * 0.8) {
        tips.add(
          '${m.key} was below your goal: ${avg.round()} g of ${goal.round()} g on average.',
        );
      }
    }

    // Limits passed on average, and fiber well under its target.
    for (final n in Nutrient.all) {
      final avg = _avgMacro((d) => d.extra[n] ?? 0);
      if (n.isLimit && avg > n.dailyGuide) {
        tips.add(
          '${n.label} averaged ${n.format(avg)} a day, above the ${n.format(n.dailyGuide)} guide.',
        );
      } else if (!n.isLimit && avg > 0 && avg < n.dailyGuide * 0.6) {
        tips.add(
          '${n.label} averaged ${n.format(avg)} a day. The guide is ${n.format(n.dailyGuide)}.',
        );
      }
    }

    if (days.length < _daysSoFar) {
      tips.add(
        'You logged ${days.length} of $_daysSoFar days so far this week. More logged days make these tips more accurate.',
      );
    }
    return tips.take(3).toList();
  }

  Widget _buildAIInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Text(
                "SMART ADVICE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final tip in _adviceTips)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildInsightBullet(tip),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 10),
          child: Icon(
            Icons.lightbulb_outline_rounded,
            color: Colors.amber,
            size: 16,
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
}

// One day's summed totals.
class _DayTotals {
  final DateTime date;
  int kcal = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  // Sugar, fiber, saturated fat, sodium and cholesterol for the day.
  final Map<Nutrient, double> extra = {};

  _DayTotals(this.date);
}

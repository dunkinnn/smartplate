import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  List<DateTime> get _weekDays {
    final now = DateTime.now();
    return List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );
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
          .select('logged_date, kcal, protein_g, carbs_g, fat_g')
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
          _error = e.toString();
        });
      }
    }
  }

  // Only days with entries count, so one logged day does not read as a
  // seventh of itself.
  List<_DayTotals> get _loggedDays =>
      _week.where((d) => d.kcal > 0).toList();

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
                          _buildDateSelector(),
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
      'Sept',
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

  Widget _buildBaseCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1), // Standard 1px Border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: darkBlue,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildCalorieIntakeCard() {
    final target = _calorieTarget;
    final avg = _avgKcal;
    final progress = (target != null && target > 0)
        ? (avg / target).clamp(0.0, 1.0)
        : 0.0;

    final status = _loggedDays.isEmpty
        ? "No data"
        : target == null
        ? "No goal set"
        : avg > target * 1.1
        ? "Over target"
        : avg < target * 0.8
        ? "Under target"
        : "On Track";

    return _buildBaseCard(
      title: "Average Daily Intake",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 110,
                width: 110,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  color: brandGreen,
                  backgroundColor: borderColor.withValues(alpha: 0.5),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatNumber(avg),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: darkBlue,
                    ),
                  ),
                  const Text(
                    "kcal",
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMiniStat(
                "Daily Goal",
                target != null ? _formatNumber(target) : "—",
                brandGreen,
              ),
              const SizedBox(height: 15),
              _buildMiniStat("Overall Status", status, darkBlue),
              const SizedBox(height: 15),
              _buildMiniStat(
                "Days Logged",
                "${_loggedDays.length} of 7",
                textSecondary,
              ),
            ],
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
    final scale = (target != null && target > 0) ? target : (peak == 0 ? 1 : peak);

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _buildBaseCard(
      title: "Weekly Calorie Trend",
      child: _loggedDays.isEmpty
          ? _buildNoDataRow("Log a meal to see your trend.")
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _week
                  .map(
                    (day) => _buildBar(
                      (day.kcal / scale).clamp(0.0, 1.0),
                      dayNames[day.date.weekday - 1],
                      target != null && day.kcal > target,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildBar(double heightFactor, String day, bool isOver) {
    return Column(
      children: [
        Container(
          // Keeps empty days visible as a sliver rather than nothing at all.
          height: (100 * heightFactor).clamp(4.0, 100.0),
          width: 30,
          decoration: BoxDecoration(
            color: isOver ? accentPink : brandGreen,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 10),
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
    final protein = _avgMacro((d) => d.protein);
    final carbs = _avgMacro((d) => d.carbs);
    final fat = _avgMacro((d) => d.fat);

    return _buildBaseCard(
      title: "Macronutrients",
      child: _loggedDays.isEmpty
          ? _buildNoDataRow("No macros logged this week.")
          : Column(
              children: [
                _buildNutrientRow("Protein", protein, _proteinGoal, brandGreen),
                const SizedBox(height: 20),
                _buildNutrientRow("Carbs", carbs, _carbsGoal, darkBlue),
                const SizedBox(height: 20),
                _buildNutrientRow("Fats", fat, _fatGoal, accentPink),
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

    if (days.length < 7) {
      tips.add(
        'You logged ${days.length} of the last 7 days. More logged days make these tips more accurate.',
      );
    }
    return tips.take(3).toList();
  }

  Widget _buildAIInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 20),
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
        const Text(
          "• ",
          style: TextStyle(
            color: brandGreen,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientRow(
    String label,
    double grams,
    double? goal,
    Color color,
  ) {
    final progress = (goal != null && goal > 0)
        ? (grams / goal).clamp(0.0, 1.0)
        : 0.0;
    final display = grams % 1 == 0
        ? grams.toStringAsFixed(0)
        : grams.toStringAsFixed(1);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: darkBlue,
                fontSize: 14,
              ),
            ),
            Text(
              goal != null
                  ? "${display}g / ${goal.toStringAsFixed(0)}g"
                  : "${display}g",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          color: color,
          backgroundColor: borderColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
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

  _DayTotals(this.date);
}

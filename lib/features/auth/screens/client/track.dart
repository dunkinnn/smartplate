import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/food_entry.dart';
import 'package:smart_plate/features/auth/screens/client/log_meal.dart';
import 'package:smart_plate/features/auth/screens/client/notification.dart';
import 'package:smart_plate/features/auth/widgets/glass_header.dart';

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
  static const mealIcons = {
    'Breakfast': Icons.wb_sunny_outlined,
    'Lunch': Icons.light_mode_outlined,
    'Dinner': Icons.dark_mode_outlined,
    'Snack': Icons.cookie_outlined,
  };

  DateTime selectedDate = DateTime.now();
  Map<String, List<FoodEntry>> logsByMeal = {};
  int? calorieTarget;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Loads the selected day's logs plus the calorie goal they are measured against.
  Future<void> _loadDay() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

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

      final grouped = <String, List<FoodEntry>>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final meal = map['meal_type'] as String? ?? 'Snack';
        grouped.putIfAbsent(meal, () => []).add(FoodEntry.fromRow(map));
      }

      if (!mounted) return;
      setState(() {
        logsByMeal = grouped;
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

  Future<void> _openLogMeal() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => LogMealScreen(initialDate: selectedDate),
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
                        mealIcons[type]!,
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

  // Rolling week ending today.
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
        final isSelected = _dateKey(date) == _dateKey(selectedDate);

        return GestureDetector(
          onTap: () {
            setState(() => selectedDate = date);
            _loadDay();
          },
          child: Column(
            children: [
              Text(
                dayNames[date.weekday - 1],
                style: TextStyle(
                  color: isSelected ? darkBlue : textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
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

  Widget _buildTrackMealCard(
    String title,
    List<FoodEntry> items,
    IconData icon,
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
              Icon(icon, color: textSecondary, size: 20),
              const SizedBox(width: 10),
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
          if (items.isEmpty)
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
            ...items.map(
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
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton.icon(
              onPressed: _openLogMeal,
              icon: const Icon(Icons.add_rounded, color: brandGreen, size: 18),
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
      ),
    );
  }
}

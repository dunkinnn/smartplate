import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/food_entry.dart';

// Records planned meals as eaten; Track and Home share these food_logs rows.
class MealLogService {
  static SupabaseClient get _db => Supabase.instance.client;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Unlocks plans from today on so they can be regenerated; returns how many.
  static Future<int> reopenUpcomingPlans() async {
    final user = _db.auth.currentUser;
    if (user == null) return 0;

    final rows = await _db
        .from('meal_plans')
        .update({'saved_at': null})
        .eq('user_id', user.id)
        .gte('plan_date', dateKey(DateTime.now()))
        .select('id');
    return rows.length;
  }

  // Consecutive logged days, counted from today or from yesterday if today is empty.
  static Future<int> currentStreak() async {
    final user = _db.auth.currentUser;
    if (user == null) return 0;

    final today = DateTime.now();
    final rows = await _db
        .from('food_logs')
        .select('logged_date')
        .eq('user_id', user.id)
        .gte('logged_date', dateKey(today.subtract(const Duration(days: 90))));

    final days = {for (final r in rows) r['logged_date'] as String};
    var day = days.contains(dateKey(today))
        ? today
        : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // Logs a planned meal's dishes when eaten, or removes them when not.
  static Future<void> setPlannedMealEaten({
    required DateTime date,
    required String mealType,
    required List<FoodEntry> dishes,
    required bool eaten,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    if (eaten) {
      await _db.from('food_logs').insert([
        for (final dish in dishes)
          dish.toRow(userId: user.id, date: date, mealType: mealType),
      ]);
    } else {
      await _db
          .from('food_logs')
          .delete()
          .eq('user_id', user.id)
          .eq('logged_date', dateKey(date))
          .eq('meal_type', mealType)
          .eq('source', 'plan');
    }
  }
}

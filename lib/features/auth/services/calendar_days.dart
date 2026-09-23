import 'package:supabase_flutter/supabase_flutter.dart';

// Seven-day week shown in the Meal Plan and Track calendars. Weeks start on the
// signup day (day 1 to 7, then 8 to 14, and so on), so today is always inside.
List<DateTime> visibleDays() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final created = DateTime.tryParse(
    Supabase.instance.client.auth.currentUser?.createdAt ?? '',
  )?.toLocal();
  final joined = created == null
      ? today
      : DateTime(created.year, created.month, created.day);

  final weeks = today.difference(joined).inDays ~/ 7;
  final start = joined.add(Duration(days: weeks * 7));

  return [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
}

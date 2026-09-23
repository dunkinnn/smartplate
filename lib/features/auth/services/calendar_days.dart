import 'package:supabase_flutter/supabase_flutter.dart';

// Days shown in the Meal Plan and Track calendars: up to the past six days and
// today, never earlier than the day the account was created.
List<DateTime> visibleDays() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final created = DateTime.tryParse(
    Supabase.instance.client.auth.currentUser?.createdAt ?? '',
  )?.toLocal();
  final joined = created == null
      ? today.subtract(const Duration(days: 6))
      : DateTime(created.year, created.month, created.day);

  return [
    for (var i = 6; i >= 0; i--)
      if (!today.subtract(Duration(days: i)).isBefore(joined))
        today.subtract(Duration(days: i)),
  ];
}

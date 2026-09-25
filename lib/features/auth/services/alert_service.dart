import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_plate/features/auth/models/nutrients.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// Phone notifications for the Calorie and Nutrient Alert System: meal reminders
// scheduled on the device, plus instant alerts when calorie or protein goals are hit.
class AlertService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _askedPermission = false;

  // Same reminder hours as the in-app Notifications screen.
  static const _mealHours = {'Breakfast': 10, 'Lunch': 14, 'Dinner': 21};

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'smart_plate_alerts',
      'Meal and nutrition alerts',
      channelDescription: 'Meal reminders and calorie or nutrient alerts',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  // Never throws, so a notification problem cannot stop the app from starting.
  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      // Users are in the Philippines, so reminders follow Manila time.
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Failed to set up notifications: $e');
    }
  }

  // Asks once per launch; the phone only shows the prompt the first time.
  static Future<void> _requestPermission() async {
    if (_askedPermission) return;
    _askedPermission = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Reschedules reminders and sends any goal alert; call after food is logged.
  static Future<void> update() async {
    try {
      await init();
      if (!_ready) return;

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        await cancelAll();
        return;
      }
      await _requestPermission();

      final now = tz.TZDateTime.now(tz.local);
      final logs = await supabase
          .from('food_logs')
          .select(
            'meal_type, kcal, protein_g, sugar_g, saturated_fat_g, sodium_mg, cholesterol_mg',
          )
          .eq('user_id', user.id)
          .eq('logged_date', _key(now));
      final profile = await supabase
          .from('user_profiles')
          .select('calorie_target, protein_goal_g')
          .eq('id', user.id)
          .maybeSingle();

      await _scheduleReminders(now, {for (final r in logs) r['meal_type']});
      await _checkGoals(now, logs, profile);
    } catch (e) {
      debugPrint('Failed to update alerts: $e');
    }
  }

  // Today's remaining unlogged meals plus the next two days, so reminders keep
  // coming even if the app is not opened for a while.
  static Future<void> _scheduleReminders(
    tz.TZDateTime now,
    Set<dynamic> loggedToday,
  ) async {
    final meals = _mealHours.entries.toList();

    for (var day = 0; day < 3; day++) {
      for (var i = 0; i < meals.length; i++) {
        final id = 100 + day * 10 + i;
        await _plugin.cancel(id: id);

        final meal = meals[i].key;
        final at = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + day,
          meals[i].value,
        );
        if (!at.isAfter(now) || (day == 0 && loggedToday.contains(meal))) {
          continue;
        }

        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: at,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: '$meal not logged yet',
          body: 'Open Smart Plate and mark your $meal in Track.',
        );
      }
    }
  }

  // Instant alerts at 90 and 100 percent of the calorie goal, and low protein
  // in the evening; each is sent at most once per day.
  static Future<void> _checkGoals(
    tz.TZDateTime now,
    List logs,
    Map<String, dynamic>? profile,
  ) async {
    var kcal = 0;
    var protein = 0.0;
    for (final r in logs) {
      kcal += (r['kcal'] as num?)?.round() ?? 0;
      protein += (r['protein_g'] as num?)?.toDouble() ?? 0;
    }

    final target = (profile?['calorie_target'] as num?)?.round();
    final proteinGoal = (profile?['protein_goal_g'] as num?)?.toDouble();

    if (target != null && target > 0) {
      if (kcal >= target) {
        await _alertOnce(
          now,
          'calorie_reached',
          201,
          'Daily calorie target reached',
          "You've logged $kcal of your $target kcal today.",
        );
      } else if (kcal >= target * 0.9) {
        await _alertOnce(
          now,
          'calorie_near',
          202,
          'Nearing your calorie target',
          "You're at ${(kcal / target * 100).round()}% of your $target kcal goal.",
        );
      }
    }

    if (proteinGoal != null &&
        proteinGoal > 0 &&
        now.hour >= 18 &&
        kcal > 0 &&
        protein < proteinGoal * 0.7) {
      await _alertOnce(
        now,
        'protein_low',
        203,
        'Protein below your goal',
        'Today: ${protein.round()} g of ${proteinGoal.round()} g protein.',
      );
    }

    // Sugar, saturated fat, sodium and cholesterol past their daily guide.
    var id = 204;
    for (final n in Nutrient.all.where((n) => n.isLimit)) {
      final total = logs.fold<double>(
        0,
        (sum, r) => sum + ((r[n.column] as num?)?.toDouble() ?? 0),
      );
      if (total > n.dailyGuide) {
        await _alertOnce(
          now,
          'limit_${n.column}',
          id,
          '${n.label} above daily guide',
          "Today: ${n.format(total)}. The daily guide is ${n.format(n.dailyGuide)}.",
        );
      }
      id++;
    }
  }

  static Future<void> _alertOnce(
    tz.TZDateTime now,
    String type,
    int id,
    String title,
    String body,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'alert_${type}_${_key(now)}';
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  // Removes every scheduled reminder, for example on logout.
  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}

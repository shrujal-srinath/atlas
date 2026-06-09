import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/dev/dev_mode.dart';
import '../../shared/models/models.dart';
import '../../shared/services/notification_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/weather_service.dart';
import '../auth/providers/auth_provider.dart';
import '../habits/providers/habit_provider.dart';

/// Detects "outdoor" habits by name/icon keywords. Lets us avoid a DB
/// migration for a dedicated `outdoor` column on `habits` — see [[3.4 plan]].
/// Adjust this list as more outdoor activities show up.
const _outdoorKeywords = <String>[
  'run',
  'walk',
  'jog',
  'cycle',
  'cycling',
  'bike',
  'biking',
  'hike',
  'hiking',
  'climb',
  'tennis',
  'golf',
  'soccer',
  'football',
  'cricket',
  'bowl',
  'sprint',
  'swim',
  'paddle',
  'kayak',
  'surf',
  'ski',
  'skate',
];

bool _looksOutdoor(Habit h) {
  if (h.type != HabitType.positive) return false;
  final n = h.name.toLowerCase();
  final ic = h.icon.toLowerCase();
  for (final kw in _outdoorKeywords) {
    if (n.contains(kw) || ic.contains(kw)) return true;
  }
  return false;
}

const _kLastNudgeKey = 'weather_nudge:last_fired_at';
// Minimum time between weather nudges per day so we don't spam.
const _kCooldownHours = 6;

/// One-shot weather nudge runner. Reads the user's habits, asks Open-Meteo
/// for the next 6h forecast, and — if any outdoor habit has rain in the next
/// 2h — schedules a local notification ~5s out. Honors a 6h cooldown via
/// shared_preferences so a freshly-rebuilt provider doesn't spam.
///
/// Best-effort. Network / schema / permission failures are swallowed.
final weatherNudgeRunnerProvider = FutureProvider<void>((ref) async {
  if (ref.watch(devModeProvider)) return;
  final session = ref.watch(sessionProvider);
  if (session == null) return;

  // Cooldown guard.
  final prefs = await SharedPreferences.getInstance();
  final lastFiredStr = prefs.getString(_kLastNudgeKey);
  if (lastFiredStr != null) {
    final lastFired = DateTime.tryParse(lastFiredStr);
    if (lastFired != null &&
        DateTime.now().difference(lastFired).inHours < _kCooldownHours) {
      return;
    }
  }

  final habits = await ref.read(habitsProvider.future);
  final outdoor = habits.where(_looksOutdoor).toList();
  if (outdoor.isEmpty) return;

  final forecast = await WeatherService().next6Hours();
  if (!forecast.rainExpectedWithin(windowHours: 2)) return;

  // Pick the most "important" outdoor habit (priority > critical > … > low).
  outdoor.sort(
      (a, b) => b.priority.index.compareTo(a.priority.index));
  final target = outdoor.first;

  await NotificationService.instance.init();

  // Schedule for ~5 seconds out — fires while user is roughly still in-app
  // / pocket. flutter_local_notifications expects a future TZ datetime.
  try {
    await _scheduleNudge(
      habitName: target.name,
    );
  } catch (_) {
    // ignore
  }

  // Best-effort Supabase mirror for the inbox feed.
  try {
    await SupabaseService.client.from('notifications').insert({
      'user_id': session.user.id,
      'type': 'weather',
      'title': 'Rain in ~2h',
      'body': 'Get your ${target.name} in before the storm.',
      'payload': {'habit_id': target.id},
    });
  } catch (_) {}

  await prefs.setString(_kLastNudgeKey, DateTime.now().toIso8601String());
});

Future<void> _scheduleNudge({required String habitName}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'weather_nudges',
      'Weather nudges',
      channelDescription: 'Heads-up when rain is forecast for outdoor habits.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
  await plugin.show(
    // Negative id won't collide with the dow-derived habit reminder ids.
    -1,
    'Rain in ~2h',
    'Get your $habitName in before the storm.',
    details,
    payload: 'weather:$habitName',
  );
}

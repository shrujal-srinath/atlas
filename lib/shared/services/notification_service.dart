import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications wrapper. Schedules per-habit reminders that repeat on
/// the supplied days-of-week.
///
/// Notification ids are derived deterministically from `habitId` (md5-like hash
/// truncated to int32) so re-scheduling a habit cleanly replaces previous
/// triggers.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      // Fall back to UTC if device timezone lookup fails.
      tz.setLocalLocation(tz.UTC);
      if (kDebugMode) debugPrint('NotificationService: timezone fallback ($e)');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  /// Requests OS-level notification permission (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Schedules a repeating daily reminder for [habitId] on each day in
  /// [daysOfWeek] (1=Mon … 7=Sun).
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String name,
    required ({int hour, int minute}) time,
    required List<int> daysOfWeek,
  }) async {
    await init();
    if (daysOfWeek.isEmpty) return;
    await cancelHabit(habitId);

    for (final dow in daysOfWeek) {
      final id = _idFor(habitId, dow);
      final next = _nextInstance(dow, time.hour, time.minute);
      await _plugin.zonedSchedule(
        id,
        name,
        'Tap to log your habit',
        next,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'habit:$habitId',
      );
    }
  }

  /// Cancels all reminder slots for a habit.
  Future<void> cancelHabit(String habitId) async {
    await init();
    for (int dow = 1; dow <= 7; dow++) {
      await _plugin.cancel(_idFor(habitId, dow));
    }
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Habit reminders',
          channelDescription: 'Scheduled reminders for habits you track.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  tz.TZDateTime _nextInstance(int dow, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // Advance to the matching weekday.
    while (scheduled.weekday != dow || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _idFor(String habitId, int dow) {
    // 31-bit positive int derived from habitId + dow.
    final base = habitId.hashCode & 0x7FFFFFFF;
    return ((base ~/ 10) * 10) + dow;
  }
}


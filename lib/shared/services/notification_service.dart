import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'quiet_hours.dart';

/// Entry point for taps that arrive while the app is terminated/backgrounded.
/// Runs in a separate isolate, so it can't navigate — the real routing happens
/// on next foreground via [NotificationService.consumeLaunchPayload]. Must be a
/// top-level (or static) `vm:entry-point` function for the plugin to find it.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Intentionally empty — see doc comment above.
}

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

  /// Emits the `payload` of a notification the user tapped while the app was
  /// alive (foreground/background). The app listens to this and deep-links.
  final ValueNotifier<String?> tappedPayload = ValueNotifier<String?>(null);

  /// Payload of the notification that cold-started the app, if any. Read once
  /// via [consumeLaunchPayload] after the first frame, then cleared.
  String? _launchPayload;

  /// Returns the cold-start launch payload exactly once, then clears it so a
  /// router rebuild can't re-trigger the same deep-link.
  String? consumeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

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
      onDidReceiveNotificationResponse: (response) {
        tappedPayload.value = response.payload;
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Capture a cold-start payload (app launched by tapping a notification).
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchPayload = launch!.notificationResponse?.payload;
      }
    } catch (_) {
      // Non-fatal — just means no deep-link on this launch.
    }

    _initialized = true;
  }

  /// Requests OS-level notification permission (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Requests every permission the scheduler needs and reports whether
  /// notifications can actually fire. Safe to call repeatedly — once the OS has
  /// a decision it won't re-prompt. Covers POST_NOTIFICATIONS (Android 13+/iOS)
  /// and the user-grantable SCHEDULE_EXACT_ALARM (Android 12+). If exact-alarm
  /// is denied the scheduler degrades to inexact alarms (see [_scheduleMode])
  /// rather than failing — so the app never needs the Play-restricted
  /// USE_EXACT_ALARM permission.
  Future<bool> ensurePermissions() async {
    await init();
    final granted = await requestPermission();
    try {
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {
      // Permission unavailable on this OS version — inexact fallback covers it.
    }
    return granted;
  }

  /// Schedule mode chosen by exact-alarm permission: exact when the user has
  /// granted SCHEDULE_EXACT_ALARM, otherwise inexact (a few minutes of OS
  /// batching). Inexact never throws and needs no restricted permission, so
  /// reminders always fire even if the user declines exact alarms.
  Future<AndroidScheduleMode> _scheduleMode() async {
    try {
      if (await Permission.scheduleExactAlarm.isGranted) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // Permission API unavailable on this OS version.
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
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
        androidScheduleMode: await _scheduleMode(),
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

  // ── Meal reminders (per slot) ────────────────────────────────────

  /// Schedules a daily reminder for [slotKey] at [time]. Idempotent — calling
  /// twice for the same slot replaces the previous notification.
  /// [slotKey] is the snake_case DB value (e.g. 'breakfast', 'pre_workout').
  Future<void> scheduleMealReminder({
    required String slotKey,
    required ({int hour, int minute}) time,
    required String title,
    required String body,
  }) async {
    await init();
    final id = _idForSlot('meal', slotKey);
    await _plugin.cancel(id);
    final next = _nextDailyInstance(time.hour, time.minute);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      _detailsMeal(),
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'meal:$slotKey',
    );
  }

  Future<void> cancelMealReminder(String slotKey) async {
    await init();
    await _plugin.cancel(_idForSlot('meal', slotKey));
  }

  Future<void> cancelAllMealReminders() async {
    await init();
    for (final s in const [
      'breakfast', 'lunch', 'dinner',
      'snack', 'pre_workout', 'post_workout',
    ]) {
      await _plugin.cancel(_idForSlot('meal', s));
    }
  }

  // ── Water nudges ────────────────────────────────────────────────

  /// Schedules a chain of evenly-spaced water nudges between [startHour] and
  /// [endHour] today, repeating daily. Replaces any previous water nudges.
  Future<void> scheduleWaterNudges({
    required int intervalHours,
    required int startHour,
    required int endHour,
    QuietHours? quiet,
  }) async {
    await init();
    await cancelWaterNudges();
    if (intervalHours <= 0 || endHour <= startHour) return;
    int idx = 0;
    for (int h = startHour; h <= endHour; h += intervalHours) {
      // Skip nudges that fall inside quiet hours rather than shifting them —
      // shifting a recurring chain would collapse several onto the window edge.
      if (quiet != null && quiet.contains(h * 60)) continue;
      final id = _kWaterIdBase + idx++;
      await _plugin.zonedSchedule(
        id,
        'Hydration check',
        'Time for a glass of water.',
        _nextDailyInstance(h, 0),
        _detailsWater(),
        androidScheduleMode: await _scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'water',
      );
      if (idx > 12) break; // safety cap
    }
  }

  Future<void> cancelWaterNudges() async {
    await init();
    for (int i = 0; i < 24; i++) {
      await _plugin.cancel(_kWaterIdBase + i);
    }
  }

  // ── Mood check-ins ──────────────────────────────────────────────

  /// Schedules a chain of evenly-spaced mood check-in nudges between
  /// [startHour] and [endHour], repeating daily. Replaces any previous mood
  /// nudges. Skips slots inside [quiet] (same policy as water nudges).
  Future<void> scheduleMoodCheckins({
    required int intervalHours,
    required int startHour,
    required int endHour,
    QuietHours? quiet,
  }) async {
    await init();
    await cancelMoodCheckins();
    if (intervalHours <= 0 || endHour <= startHour) return;
    int idx = 0;
    for (int h = startHour; h <= endHour; h += intervalHours) {
      if (quiet != null && quiet.contains(h * 60)) continue;
      final id = _kMoodIdBase + idx++;
      await _plugin.zonedSchedule(
        id,
        'Energy check-in',
        "How's your energy right now? Tap to log 1–5.",
        _nextDailyInstance(h, 0),
        _detailsMood(),
        androidScheduleMode: await _scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'energy_checkin',
      );
      if (idx > 12) break; // safety cap
    }
  }

  Future<void> cancelMoodCheckins() async {
    await init();
    for (int i = 0; i < 16; i++) {
      await _plugin.cancel(_kMoodIdBase + i);
    }
  }

  // ── Streak-at-risk daily nudge ─────────────────────────────────

  Future<void> scheduleStreakAtRisk({
    required int hour,
    required int minute,
  }) async {
    await init();
    await cancelStreakAtRisk();
    await _plugin.zonedSchedule(
      _kStreakRiskId,
      'Streak check',
      'Tap to see which streaks need logging tonight.',
      _nextDailyInstance(hour, minute),
      _detailsStreak(),
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'streak_at_risk',
    );
  }

  Future<void> cancelStreakAtRisk() async {
    await init();
    await _plugin.cancel(_kStreakRiskId);
  }

  // ── Weekly weight nudge ─────────────────────────────────────────

  Future<void> scheduleWeightNudge({
    required int weekday, // 1=Mon … 7=Sun
    required int hour,
    required int minute,
  }) async {
    await init();
    await cancelWeightNudge();
    await _plugin.zonedSchedule(
      _kWeightNudgeId,
      'Weekly check-in',
      'Log your weight to keep the trend chart honest.',
      _nextInstance(weekday, hour, minute),
      _detailsWeight(),
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weight_nudge',
    );
  }

  Future<void> cancelWeightNudge() async {
    await init();
    await _plugin.cancel(_kWeightNudgeId);
  }

  // ── Note reminders ──────────────────────────────────────────────
  //
  // A note can carry one reminder. One-time reminders fire once at an exact
  // moment; repeating ones fire at a time-of-day on a set of weekdays. We map
  // each to up to 8 OS slots per note (slot 0 = one-time/daily, 1..7 = a
  // specific weekday) so cancelling cleanly replaces any previous schedule.

  /// Schedules a one-time reminder for [noteId] at [whenLocal]. Past moments
  /// are skipped (nothing is queued).
  Future<void> scheduleNoteOnce({
    required String noteId,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    await init();
    await cancelNoteReminder(noteId);
    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      _noteIdFor(noteId, 0),
      title,
      body,
      scheduled,
      _detailsNote(),
      androidScheduleMode: await _scheduleMode(),
      payload: 'note:$noteId',
    );
  }

  /// Schedules a repeating reminder for [noteId] at [time]. When [daysOfWeek]
  /// is empty it repeats every day; otherwise only on the listed days
  /// (1=Mon … 7=Sun).
  Future<void> scheduleNoteRepeating({
    required String noteId,
    required String title,
    required String body,
    required ({int hour, int minute}) time,
    required List<int> daysOfWeek,
  }) async {
    await init();
    await cancelNoteReminder(noteId);
    if (daysOfWeek.isEmpty) {
      await _plugin.zonedSchedule(
        _noteIdFor(noteId, 0),
        title,
        body,
        _nextDailyInstance(time.hour, time.minute),
        _detailsNote(),
        androidScheduleMode: await _scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'note:$noteId',
      );
      return;
    }
    for (final dow in daysOfWeek) {
      await _plugin.zonedSchedule(
        _noteIdFor(noteId, dow),
        title,
        body,
        _nextInstance(dow, time.hour, time.minute),
        _detailsNote(),
        androidScheduleMode: await _scheduleMode(),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'note:$noteId',
      );
    }
  }

  Future<void> cancelNoteReminder(String noteId) async {
    await init();
    for (int slot = 0; slot <= 7; slot++) {
      await _plugin.cancel(_noteIdFor(noteId, slot));
    }
  }

  // ── Channel details ─────────────────────────────────────────────

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

  NotificationDetails _detailsMeal() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_reminders',
          'Meal reminders',
          channelDescription: 'Nudges to log breakfast, lunch, dinner, snacks.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  NotificationDetails _detailsWater() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'water_nudges',
          'Water nudges',
          channelDescription: 'Periodic hydration check-ins.',
          importance: Importance.low,
          priority: Priority.low,
        ),
        iOS: DarwinNotificationDetails(),
      );

  NotificationDetails _detailsMood() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'mood_checkins',
          'Mood check-ins',
          channelDescription: 'Periodic prompts to log how you feel.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  NotificationDetails _detailsStreak() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_at_risk',
          'Streak at risk',
          channelDescription: 'Single evening nudge when a streak might break.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  NotificationDetails _detailsWeight() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'weight_nudges',
          'Weekly weight check',
          channelDescription: 'Weekly weight log nudge.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  NotificationDetails _detailsNote() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'note_reminders',
          'Note reminders',
          channelDescription: 'Reminders you attach to notes and lists.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  // ── Time helpers ─────────────────────────────────────────────────

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

  tz.TZDateTime _nextDailyInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ── Notification ID space ────────────────────────────────────────
  //
  // Habit reminders use _idFor(habitId, dow), a hash-derived value spanning
  // the full 0..0x7FFFFFFF positive range — any fixed positive band, however
  // "far" it looks, is reachable by chance. Every non-habit category is
  // therefore parked in **negative** ids instead: habit ids are always
  // non-negative (masked with 0x7FFFFFFF), so negative bands can never
  // collide with them, by construction rather than by low probability.

  static const _kWaterIdBase   = -1024; // -1024..-1001 — up to 24 water slots
  static const _kMoodIdBase    = -2048; // -2048..-2033 — up to 16 mood-checkin slots
  static const _kStreakRiskId  = -3001;
  static const _kWeightNudgeId = -3002;
  static const _kMealIdBase    = -4096; // -4096..-12095 — hashed meal slots
  static const _kNoteIdBase    = -1000000000; // -1e9 .. -1.096e9 — hashed note slots

  int _idFor(String habitId, int dow) {
    // 31-bit positive int derived from habitId + dow.
    final base = habitId.hashCode & 0x7FFFFFFF;
    return ((base ~/ 10) * 10) + dow;
  }

  /// Deterministic ID for a non-habit category slot (currently used for meals).
  int _idForSlot(String category, String slotKey) {
    final base = '$category:$slotKey'.hashCode & 0x7FFFFFFF;
    return _kMealIdBase - (base % 8000);
  }

  /// Deterministic ID for note-reminder [slot] (0=one-time/daily, 1..7=weekday).
  /// 8 consecutive ids reserved per note so a re-schedule replaces cleanly.
  int _noteIdFor(String noteId, int slot) {
    final base = (noteId.hashCode & 0x7FFFFFFF) % 12000000;
    return _kNoteIdBase - (base * 8 + slot);
  }
}


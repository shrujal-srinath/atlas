import 'package:flutter/foundation.dart';
import '../../features/notifications/domain/notification_prefs.dart';
import '../../shared/models/models.dart';
import 'notification_service.dart';
import 'quiet_hours.dart';

/// Single point of truth for "what notifications should the OS have queued
/// right now?" Reconciles the OS notification store with the current user
/// preferences. Idempotent — call after every prefs/habit/quiet-hours change
/// and on app boot without worrying about duplicate schedules.
///
/// Habit reminders are reconciled here too (from the habit list), so the master
/// switch and the per-category `habits` toggle actually take effect, and
/// re-enabling notifications restores per-habit reminders instead of silently
/// dropping them.
class ReminderScheduler {
  ReminderScheduler._();
  static final ReminderScheduler instance = ReminderScheduler._();

  /// Reconcile the OS schedule against the current prefs.
  /// `master` is `AppUser.notificationsEnabled`. When false, cancel everything.
  /// [quiet] shifts/suppresses notifications inside the user's Do-Not-Disturb
  /// window (null = no quiet hours configured).
  Future<void> reconcile({
    required bool master,
    required NotificationPrefs prefs,
    required List<Habit>? habits,
    QuietHours? quiet,
  }) async {
    final svc = NotificationService.instance;
    try {
      // Habit reminders first — always reconciled so toggling the master or the
      // `habits` category cancels/restores them. `cancelHabit` runs per habit
      // regardless, so disabling never leaves a stale schedule behind.
      // `habits == null` means "unknown" (offline/loading): leave them as-is.
      if (habits != null) {
        await _reconcileHabits(svc, habits,
            enabled: master && prefs.habits, quiet: quiet);
      }

      if (!master) {
        await svc.cancelAllMealReminders();
        await svc.cancelWaterNudges();
        await svc.cancelMoodCheckins();
        await svc.cancelStreakAtRisk();
        await svc.cancelWeightNudge();
        return;
      }
      await _reconcileMeals(svc, prefs.meals, quiet);
      await _reconcileWater(svc, prefs.water, quiet);
      await _reconcileMood(svc, prefs.moodCheckin, quiet);
      await _reconcileStreak(svc, prefs.streakAtRisk, quiet);
      await _reconcileWeight(svc, prefs.weight, quiet);
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('ReminderScheduler.reconcile failed: $e\n$s');
      }
    }
  }

  Future<void> _reconcileHabits(
    NotificationService svc,
    List<Habit> habits, {
    required bool enabled,
    QuietHours? quiet,
  }) async {
    for (final h in habits) {
      // Always clear first so disabling/editing/archiving can't leave a stale
      // slot queued in the OS.
      await svc.cancelHabit(h.id);
      final plan = plannedHabitReminder(h, enabled: enabled, quiet: quiet);
      if (plan == null) continue;
      await svc.scheduleHabitReminder(
        habitId: h.id,
        name: h.name,
        time: (hour: plan.hour, minute: plan.minute),
        daysOfWeek: plan.days,
      );
    }
  }

  Future<void> _reconcileMeals(
    NotificationService svc,
    MealPrefs prefs,
    QuietHours? quiet,
  ) async {
    if (!prefs.enabled) {
      await svc.cancelAllMealReminders();
      return;
    }
    for (final entry in prefs.slots.entries) {
      final slot = entry.key;
      final t = entry.value;
      final key = MealPrefs.slotKey(slot);
      if (t == null) {
        await svc.cancelMealReminder(key);
        continue;
      }
      final hm = _parseHHmm(t);
      if (hm == null) continue;
      final shifted = quiet?.shift(hm.$1, hm.$2) ?? hm;
      await svc.scheduleMealReminder(
        slotKey: key,
        time: (hour: shifted.$1, minute: shifted.$2),
        title: '${_slotLabel(slot)} reminder',
        body: 'Time to log your ${_slotLabel(slot).toLowerCase()}.',
      );
    }
  }

  Future<void> _reconcileWater(
    NotificationService svc,
    WaterNudgePrefs prefs,
    QuietHours? quiet,
  ) async {
    if (!prefs.enabled) {
      await svc.cancelWaterNudges();
      return;
    }
    await svc.scheduleWaterNudges(
      intervalHours: prefs.intervalHours,
      startHour: prefs.startHour,
      endHour: prefs.endHour,
      quiet: quiet,
    );
  }

  Future<void> _reconcileMood(
    NotificationService svc,
    MoodCheckinPrefs prefs,
    QuietHours? quiet,
  ) async {
    if (!prefs.enabled) {
      await svc.cancelMoodCheckins();
      return;
    }
    await svc.scheduleMoodCheckins(
      intervalHours: prefs.intervalHours,
      startHour: prefs.startHour,
      endHour: prefs.endHour,
      quiet: quiet,
    );
  }

  Future<void> _reconcileStreak(
    NotificationService svc,
    StreakRiskPrefs prefs,
    QuietHours? quiet,
  ) async {
    if (!prefs.enabled) {
      await svc.cancelStreakAtRisk();
      return;
    }
    final shifted = quiet?.shift(prefs.hour, prefs.minute) ?? (prefs.hour, prefs.minute);
    await svc.scheduleStreakAtRisk(hour: shifted.$1, minute: shifted.$2);
  }

  Future<void> _reconcileWeight(
    NotificationService svc,
    WeightNudgePrefs prefs,
    QuietHours? quiet,
  ) async {
    if (!prefs.enabled) {
      await svc.cancelWeightNudge();
      return;
    }
    final shifted = quiet?.shift(prefs.hour, prefs.minute) ?? (prefs.hour, prefs.minute);
    await svc.scheduleWeightNudge(
      weekday: prefs.weekday,
      hour: shifted.$1,
      minute: shifted.$2,
    );
  }

  static String _slotLabel(MealTimeSlot s) => switch (s) {
        MealTimeSlot.breakfast => 'Breakfast',
        MealTimeSlot.lunch => 'Lunch',
        MealTimeSlot.dinner => 'Dinner',
        MealTimeSlot.snack => 'Snack',
        MealTimeSlot.preWorkout => 'Pre-workout',
        MealTimeSlot.postWorkout => 'Post-workout',
      };
}

/// Pure decision: what (if anything) to schedule for [h]. Returns null when no
/// reminder should fire. Extracted from [ReminderScheduler] so the gating +
/// day-resolution + quiet-hours logic is unit-testable without the plugin.
({int hour, int minute, List<int> days})? plannedHabitReminder(
  Habit h, {
  required bool enabled,
  QuietHours? quiet,
}) {
  if (!enabled) return null;
  if (h.isArchived) return null;
  if (!h.reminderEnabled || h.reminderTime == null) return null;
  final hm = _parseHHmm(h.reminderTime);
  if (hm == null) return null;
  final days = reminderDaysFor(h);
  if (days.isEmpty) return null;
  final shifted = quiet?.shift(hm.$1, hm.$2) ?? hm;
  return (hour: shifted.$1, minute: shifted.$2, days: days);
}

/// Days a habit's reminder should repeat on. Prefers the explicit
/// `reminderDays`; falls back to the habit's own schedule (every-day and
/// times-per-week habits remind daily since they have no fixed weekdays).
List<int> reminderDaysFor(Habit h) {
  if (h.reminderDays.isNotEmpty) return h.reminderDays;
  switch (h.frequencyMode) {
    case FrequencyMode.specificDays:
      return h.daysOfWeek;
    case FrequencyMode.everyDay:
    case FrequencyMode.timesPerWeek:
      return const [1, 2, 3, 4, 5, 6, 7];
  }
}

(int, int)? _parseHHmm(String? hhmm) {
  if (hhmm == null) return null;
  final p = hhmm.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return (h, m);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/shared/models/models.dart';
import 'package:atlas/shared/services/quiet_hours.dart';
import 'package:atlas/shared/services/reminder_scheduler.dart';

Habit _habit({
  bool reminderEnabled = true,
  String? reminderTime = '08:00',
  List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7],
  bool isArchived = false,
  FrequencyMode frequencyMode = FrequencyMode.everyDay,
  List<int> daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
}) =>
    Habit(
      id: 'h1',
      userId: 'u1',
      name: 'Stretch',
      icon: 'activity',
      sectionId: 'athletic',
      type: HabitType.positive,
      daysOfWeek: daysOfWeek,
      effortRatingEnabled: false,
      noteEnabled: false,
      isArchived: isArchived,
      frequencyMode: frequencyMode,
      reminderEnabled: reminderEnabled,
      reminderTime: reminderTime,
      reminderDays: reminderDays,
    );

void main() {
  group('plannedHabitReminder gating', () {
    test('returns null when the category is disabled', () {
      expect(plannedHabitReminder(_habit(), enabled: false), isNull);
    });

    test('returns null for archived habits even when enabled', () {
      expect(
        plannedHabitReminder(_habit(isArchived: true), enabled: true),
        isNull,
      );
    });

    test('returns null when the habit has no reminder set', () {
      expect(
        plannedHabitReminder(
          _habit(reminderEnabled: false),
          enabled: true,
        ),
        isNull,
      );
      expect(
        plannedHabitReminder(
          _habit(reminderTime: null),
          enabled: true,
        ),
        isNull,
      );
    });

    test('returns null when no days resolve', () {
      final h = _habit(
        reminderDays: const [],
        frequencyMode: FrequencyMode.specificDays,
        daysOfWeek: const [],
      );
      expect(plannedHabitReminder(h, enabled: true), isNull);
    });

    test('schedules at the habit time when enabled and outside quiet hours', () {
      final plan = plannedHabitReminder(_habit(), enabled: true)!;
      expect(plan.hour, 8);
      expect(plan.minute, 0);
      expect(plan.days, [1, 2, 3, 4, 5, 6, 7]);
    });

    test('shifts the time out of quiet hours', () {
      final quiet = QuietHours.parse('22:00', '09:00');
      final plan = plannedHabitReminder(
        _habit(reminderTime: '06:30'),
        enabled: true,
        quiet: quiet,
      )!;
      expect(plan.hour, 9); // 06:30 falls in the window -> pushed to 09:00
      expect(plan.minute, 0);
    });
  });

  group('reminderDaysFor', () {
    test('prefers explicit reminderDays', () {
      final h = _habit(reminderDays: const [2, 4, 6]);
      expect(reminderDaysFor(h), [2, 4, 6]);
    });

    test('falls back to specificDays schedule when reminderDays empty', () {
      final h = _habit(
        reminderDays: const [],
        frequencyMode: FrequencyMode.specificDays,
        daysOfWeek: const [1, 3, 5],
      );
      expect(reminderDaysFor(h), [1, 3, 5]);
    });

    test('every-day and times-per-week fall back to all 7 days', () {
      final everyDay = _habit(
        reminderDays: const [],
        frequencyMode: FrequencyMode.everyDay,
      );
      final twp = _habit(
        reminderDays: const [],
        frequencyMode: FrequencyMode.timesPerWeek,
      );
      expect(reminderDaysFor(everyDay), [1, 2, 3, 4, 5, 6, 7]);
      expect(reminderDaysFor(twp), [1, 2, 3, 4, 5, 6, 7]);
    });
  });
}

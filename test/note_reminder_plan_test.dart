import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/notes/domain/note.dart';
import 'package:atlas/features/notes/domain/note_reminder_plan.dart';

void main() {
  final now = DateTime(2026, 6, 19, 12, 0); // Friday noon

  group('planNoteReminder', () {
    test('no reminder set → null', () {
      expect(planNoteReminder(at: null, rule: null, now: now), isNull);
      expect(
        planNoteReminder(at: DateTime(2026, 6, 20), rule: null, now: now),
        isNull,
      );
    });

    test('future one-time → exact schedule', () {
      final at = DateTime(2026, 6, 20, 9, 0);
      final plan =
          planNoteReminder(at: at, rule: ReminderRule.once, now: now);
      expect(plan, isNotNull);
      expect(plan!.isOnce, isTrue);
      expect(plan.exactWhen, at);
    });

    test('past one-time → null (nothing scheduled)', () {
      final at = DateTime(2026, 6, 19, 9, 0); // earlier today
      expect(
        planNoteReminder(at: at, rule: ReminderRule.once, now: now),
        isNull,
      );
    });

    test('daily → time only, no specific days', () {
      final at = DateTime(2026, 6, 19, 7, 30);
      final plan =
          planNoteReminder(at: at, rule: ReminderRule.daily, now: now);
      expect(plan!.isOnce, isFalse);
      expect(plan.hour, 7);
      expect(plan.minute, 30);
      expect(plan.daysOfWeek, isEmpty);
    });

    test('weekdays → Mon–Fri', () {
      final at = DateTime(2026, 6, 19, 8, 0);
      final plan =
          planNoteReminder(at: at, rule: ReminderRule.weekdays, now: now);
      expect(plan!.daysOfWeek, [1, 2, 3, 4, 5]);
      expect(plan.hour, 8);
    });

    test('weekends → Sat–Sun', () {
      final at = DateTime(2026, 6, 19, 8, 0);
      final plan =
          planNoteReminder(at: at, rule: ReminderRule.weekends, now: now);
      expect(plan!.daysOfWeek, [6, 7]);
    });

    test('weekly → the chosen date\'s weekday', () {
      final at = DateTime(2026, 6, 21, 10, 0); // Sunday
      final plan =
          planNoteReminder(at: at, rule: ReminderRule.weekly, now: now);
      expect(plan!.daysOfWeek, [DateTime.sunday]);
      expect(plan.hour, 10);
    });
  });
}

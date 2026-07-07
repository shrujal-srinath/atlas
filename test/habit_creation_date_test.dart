import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/shared/models/models.dart';
import 'package:atlas/features/habits/providers/habit_provider.dart';
import 'package:atlas/core/utils/day_quality.dart';

/// A habit only affects days from its creation day forward. These tests pin the
/// user-reported scenario: "Day 1 I have 3 habits; Day 2 I add 2 more — the new
/// ones must not retroactively count against Day 1's score/stats."

Habit _hab(String id, {DateTime? createdAt, List<int>? days}) => Habit(
      id: id,
      userId: 'u',
      name: id,
      icon: 'run',
      sectionId: 'athletic',
      type: HabitType.positive,
      daysOfWeek: days ?? const [1, 2, 3, 4, 5, 6, 7],
      effortRatingEnabled: false,
      noteEnabled: false,
      isArchived: false,
      createdAt: createdAt,
    );

HabitLog _done(String habitId, DateTime d) => HabitLog(
      id: 'l-$habitId-${d.day}',
      habitId: habitId,
      userId: 'u',
      date:
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      completed: true,
      urgeOnly: false,
    );

void main() {
  final day1 = DateTime(2026, 7, 1);
  final day2 = DateTime(2026, 7, 2);

  group('Habit.existedOn', () {
    test('the creation day counts; days before it do not', () {
      final h = _hab('h', createdAt: DateTime(2026, 6, 20, 15, 30));
      expect(h.existedOn(DateTime(2026, 6, 19)), isFalse);
      expect(h.existedOn(DateTime(2026, 6, 20)), isTrue); // creation day itself
      expect(h.existedOn(DateTime(2026, 6, 21)), isTrue);
    });

    test('a null createdAt imposes no lower bound (e.g. demo data)', () {
      expect(_hab('h').existedOn(DateTime(2000, 1, 1)), isTrue);
    });
  });

  group('habitsForDate — new habits do not appear on past days', () {
    final old3 = [for (var i = 0; i < 3; i++) _hab('old$i', createdAt: day1)];
    final new2 = [for (var i = 0; i < 2; i++) _hab('new$i', createdAt: day2)];
    final all = [...old3, ...new2];

    test('Day 1 sees only the 3 habits that existed then', () {
      expect(habitsForDate(all, day1).map((h) => h.id).toSet(),
          {'old0', 'old1', 'old2'});
    });

    test('Day 2 sees all 5', () {
      expect(habitsForDate(all, day2).length, 5);
    });
  });

  group('computeDayQuality — a new habit does not lower a past good day', () {
    test("Day 1 stays 3/3 done after 2 habits are added on Day 2", () {
      final old3 = [for (var i = 0; i < 3; i++) _hab('old$i', createdAt: day1)];
      final new2 = [for (var i = 0; i < 2; i++) _hab('new$i', createdAt: day2)];
      // On Day 1 the user completed all 3 habits that existed then.
      final logs = [for (final h in old3) _done(h.id, day1)];

      final q = computeDayQuality([...old3, ...new2], logs, day1);

      // The 2 Day-2 habits are excluded from Day 1 — it's still a perfect day,
      // not 3/5.
      expect(q.posScheduled, 3);
      expect(q.posDone, 3);
      expect(q.isGoodDay, isTrue);
      expect(q.positiveRate, 1.0);
    });
  });
}

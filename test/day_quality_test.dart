import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/utils/day_quality.dart';
import 'package:atlas/shared/models/models.dart';

final _day = DateTime(2026, 6, 22);

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Habit _hab(String id, HabitType type) => Habit(
      id: id,
      userId: 'u',
      name: id,
      icon: 'dumbbell',
      sectionId: 'athletic',
      type: type,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      effortRatingEnabled: false,
      noteEnabled: false,
      isArchived: false,
    );

HabitLog _log(String habitId, DateTime d, bool completed) => HabitLog(
      id: 'l-$habitId-${_ds(d)}',
      habitId: habitId,
      userId: 'u',
      date: _ds(d),
      completed: completed,
      urgeOnly: false,
    );

void main() {
  group('computeDayQuality', () {
    test('all positives done, no negatives → good day', () {
      final habits = [_hab('a', HabitType.positive), _hab('b', HabitType.positive)];
      final logs = [_log('a', _day, true), _log('b', _day, true)];
      final q = computeDayQuality(habits, logs, _day);
      expect(q.isGoodDay, isTrue);
      expect(q.positiveRate, 1.0);
      expect(q.isRestDay, isFalse);
    });

    test('a logged negative slip breaks the good day even at 100% positives', () {
      final habits = [_hab('a', HabitType.positive), _hab('n', HabitType.negative)];
      // Negative 'n' is logged as a slip (completed:false = broke it).
      final logs = [_log('a', _day, true), _log('n', _day, false)];
      final q = computeDayQuality(habits, logs, _day);
      expect(q.negSlips, 1);
      expect(q.isGoodDay, isFalse);
    });

    test('un-logged negative is clean by default → good day', () {
      final habits = [_hab('a', HabitType.positive), _hab('n', HabitType.negative)];
      final logs = [_log('a', _day, true)]; // 'n' has no log → clean, not a slip
      final q = computeDayQuality(habits, logs, _day);
      expect(q.negSlips, 0);
      expect(q.isGoodDay, isTrue);
    });

    test('maintained negative + done positive → good day', () {
      final habits = [_hab('a', HabitType.positive), _hab('n', HabitType.negative)];
      final logs = [_log('a', _day, true), _log('n', _day, true)];
      final q = computeDayQuality(habits, logs, _day);
      expect(q.negSlips, 0);
      expect(q.isGoodDay, isTrue);
    });

    test('below 85% positives → not a good day', () {
      final habits = [
        for (int i = 0; i < 5; i++) _hab('p$i', HabitType.positive),
      ];
      final logs = [for (int i = 0; i < 3; i++) _log('p$i', _day, true)]; // 3/5 = 60%
      final q = computeDayQuality(habits, logs, _day);
      expect(q.positiveRate, closeTo(0.6, 1e-9));
      expect(q.isGoodDay, isFalse);
    });

    test('nothing scheduled → rest day, not good', () {
      final h = _hab('a', HabitType.positive);
      final off = Habit(
        id: h.id,
        userId: h.userId,
        name: h.name,
        icon: h.icon,
        sectionId: h.sectionId,
        type: h.type,
        daysOfWeek: const [], // never scheduled
        effortRatingEnabled: false,
        noteEnabled: false,
        isArchived: false,
      );
      final q = computeDayQuality([off], const [], _day);
      expect(q.isRestDay, isTrue);
      expect(q.isGoodDay, isFalse);
    });
  });

  group('streakSummary', () {
    test('counts current and best, rest days skip', () {
      final byDay = <DateTime, bool?>{
        for (int i = 0; i < 10; i++)
          DateTime(2026, 6, 22 - i): i == 4 ? null : true, // a rest day mid-run
      };
      final s = streakSummary(byDay, today: _day);
      expect(s.current, 9); // 10 days, 1 rest skipped → 9 wins in the run
      expect(s.best, 9);
    });

    test('a past miss breaks the current run', () {
      final byDay = <DateTime, bool?>{
        DateTime(2026, 6, 22): true,
        DateTime(2026, 6, 21): true,
        DateTime(2026, 6, 20): false, // miss
        DateTime(2026, 6, 19): true,
      };
      final s = streakSummary(byDay, today: _day);
      expect(s.current, 2);
      expect(s.best, 2);
    });

    test('today-miss gets grace (does not break)', () {
      final byDay = <DateTime, bool?>{
        DateTime(2026, 6, 22): false, // today missed
        DateTime(2026, 6, 21): true,
        DateTime(2026, 6, 20): true,
      };
      final s = streakSummary(byDay, today: _day);
      expect(s.current, 2);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/utils/day_quality.dart';
import 'package:atlas/core/utils/streak_engine.dart';
import 'package:atlas/shared/models/models.dart';

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Habit _flexHabit(String id) => Habit(
      id: id,
      userId: 'u',
      name: id,
      icon: 'dumbbell',
      sectionId: 'athletic',
      type: HabitType.positive,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7], // flexible count = all 7 days
      frequencyMode: FrequencyMode.timesPerWeek,
      timesPerWeek: 5,
      effortRatingEnabled: false,
      noteEnabled: false,
      isArchived: false,
    );

HabitLog _log(String habitId, DateTime d,
        {bool completed = false, bool rest = false}) =>
    HabitLog(
      id: 'l-$habitId-${_ds(d)}',
      habitId: habitId,
      userId: 'u',
      date: _ds(d),
      completed: completed,
      urgeOnly: false,
      restDay: rest,
    );

void main() {
  group('rest days are neutral in calculateStreak', () {
    // "now" is a Sunday; calculateStreak walks back from yesterday (Saturday).
    final now = DateTime(2026, 6, 28); // Sunday
    final h = _flexHabit('gym');

    test('a rest day skips without breaking the run', () {
      // Mon..Sat: done, done, REST, done, done, done → streak should be 5
      // (the rest is skipped, not counted, not a break).
      final logs = [
        _log('gym', DateTime(2026, 6, 22), completed: true), // Mon
        _log('gym', DateTime(2026, 6, 23), completed: true), // Tue
        _log('gym', DateTime(2026, 6, 24), rest: true), // Wed (rest)
        _log('gym', DateTime(2026, 6, 25), completed: true), // Thu
        _log('gym', DateTime(2026, 6, 26), completed: true), // Fri
        _log('gym', DateTime(2026, 6, 27), completed: true), // Sat
      ];
      expect(calculateStreak(h, logs, now: now), 5);
    });

    test('an un-rested, un-completed day still breaks the run', () {
      // Sat done, Fri MISSED (no log) → walking back from Sat: Sat counts (1),
      // Fri breaks.
      final logs = [
        _log('gym', DateTime(2026, 6, 27), completed: true), // Sat
        // Fri (26) has no log → miss → break
        _log('gym', DateTime(2026, 6, 25), completed: true), // Thu
      ];
      expect(calculateStreak(h, logs, now: now), 1);
    });
  });

  group('rest days are neutral in computeDayQuality', () {
    final day = DateTime(2026, 6, 24);

    test('a rested habit is excluded from the scheduled set', () {
      final habits = [_flexHabit('a'), _flexHabit('b')];
      // 'a' done, 'b' rested → only 'a' is scheduled → 100% positive, good day.
      final logs = [
        _log('a', day, completed: true),
        _log('b', day, rest: true),
      ];
      final q = computeDayQuality(habits, logs, day);
      expect(q.posScheduled, 1);
      expect(q.posDone, 1);
      expect(q.positiveRate, 1.0);
      expect(q.isGoodDay, isTrue);
    });

    test('all habits rested → a neutral rest day (not a good day, not a miss)',
        () {
      final habits = [_flexHabit('a'), _flexHabit('b')];
      final logs = [
        _log('a', day, rest: true),
        _log('b', day, rest: true),
      ];
      final q = computeDayQuality(habits, logs, day);
      expect(q.totalScheduled, 0);
      expect(q.isRestDay, isTrue);
      expect(q.isGoodDay, isFalse); // rest days neither extend nor break
    });

    test('a plain incomplete (not rested) day still counts against you', () {
      final habits = [_flexHabit('a'), _flexHabit('b')];
      final logs = [_log('a', day, completed: true)]; // 'b' neither done nor rested
      final q = computeDayQuality(habits, logs, day);
      expect(q.posScheduled, 2);
      expect(q.posDone, 1);
      expect(q.positiveRate, 0.5);
    });
  });

  group('HabitLog rest_day serialization', () {
    test('round-trips through fromJson', () {
      final l = _log('a', DateTime(2026, 6, 24), rest: true);
      final back = HabitLog.fromJson({
        'id': l.id,
        'habit_id': l.habitId,
        'user_id': l.userId,
        'date': l.date,
        'completed': false,
        'rest_day': true,
      });
      expect(back.restDay, isTrue);
      expect(back.completed, isFalse);
    });

    test('absent rest_day defaults to false (legacy logs)', () {
      final back = HabitLog.fromJson({
        'id': 'x',
        'habit_id': 'a',
        'user_id': 'u',
        'date': '2026-06-24',
        'completed': true,
      });
      expect(back.restDay, isFalse);
    });
  });
}

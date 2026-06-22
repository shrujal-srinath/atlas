import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/utils/task_stats.dart';
import 'package:atlas/shared/models/models.dart';

// Fixed "today" so windows are deterministic. (The environment date is also
// 2026-06-22, which keeps calculateStreak — which reads the real now — aligned.)
final _now = DateTime(2026, 6, 22);

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Habit _hab({
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  GoalType? goalType,
  double? goalValue,
  bool effort = false,
}) =>
    Habit(
      id: 'h',
      userId: 'u',
      name: 'Gym',
      icon: 'dumbbell',
      section: HabitSection.athletic,
      type: HabitType.positive,
      daysOfWeek: days,
      goalType: goalType,
      goalValue: goalValue,
      effortRatingEnabled: effort,
      noteEnabled: false,
      isArchived: false,
    );

HabitLog _log(
  DateTime d, {
  bool completed = true,
  double? actualValue,
  int? effortRating,
}) =>
    HabitLog(
      id: 'l-${_ds(d)}',
      habitId: 'h',
      userId: 'u',
      date: _ds(d),
      completed: completed,
      urgeOnly: false,
      actualValue: actualValue,
      effortRating: effortRating,
    );

void main() {
  group('computeTaskStats', () {
    test('all done over the window → rate 1.0 and full counts', () {
      final logs = [for (int i = 0; i < 40; i++) _log(_now.subtract(Duration(days: i)))];
      final s = computeTaskStats(
          habit: _hab(), logs: logs, range: StatRange.month, now: _now);
      expect(s.completionRate, 1.0);
      expect(s.scheduledCount, 30);
      expect(s.completedCount, 30);
      expect(s.bestStreak, greaterThanOrEqualTo(30));
      expect(s.currentStreak, greaterThanOrEqualTo(29));
      expect(s.rateTrend.length, 5); // month → 5 weekly buckets
      expect(s.rateTrend.every((b) => b.rate == 1.0), isTrue);
    });

    test('a miss lowers the rate', () {
      final logs = [
        for (int i = 0; i < 10; i++)
          if (i != 3) _log(_now.subtract(Duration(days: i))),
      ];
      final s = computeTaskStats(
          habit: _hab(), logs: logs, range: StatRange.week, now: _now);
      expect(s.completionRate, closeTo(6 / 7, 1e-9));
      expect(s.rateTrend.length, 7); // week → 7 daily buckets
    });

    test('bucket count differs by range', () {
      expect(
        computeTaskStats(
                habit: _hab(), logs: const [], range: StatRange.week, now: _now)
            .rateTrend
            .length,
        7,
      );
      expect(
        computeTaskStats(
                habit: _hab(), logs: const [], range: StatRange.year, now: _now)
            .rateTrend
            .length,
        12,
      );
    });

    test('performance series extracted for goal habit, empty for binary', () {
      final logs = [
        _log(_now.subtract(const Duration(days: 1)), actualValue: 40),
        _log(_now.subtract(const Duration(days: 2)), actualValue: 50),
      ];
      final goal = computeTaskStats(
        habit: _hab(goalType: GoalType.durationMin, goalValue: 60),
        logs: logs,
        range: StatRange.month,
        now: _now,
      );
      expect(goal.performance.length, 2);
      expect((goal.performance.map((p) => p.value).toList()..sort()), [40, 50]);
      expect(goal.goalValue, 60);

      final binary = computeTaskStats(
        habit: _hab(),
        logs: [_log(_now.subtract(const Duration(days: 1)))],
        range: StatRange.month,
        now: _now,
      );
      expect(binary.performance, isEmpty);
    });

    test('effort series only from rated logs', () {
      final logs = [
        _log(_now.subtract(const Duration(days: 1)), effortRating: 4),
        _log(_now.subtract(const Duration(days: 2))),
      ];
      final s = computeTaskStats(
          habit: _hab(effort: true), logs: logs, range: StatRange.month, now: _now);
      expect(s.effort.length, 1);
      expect(s.effort.first.value, 4);
    });

    test('weekday distribution respects the schedule', () {
      final s = computeTaskStats(
          habit: _hab(days: const [1, 3, 5]),
          logs: const [],
          range: StatRange.month,
          now: _now);
      expect(s.weekday.firstWhere((w) => w.weekday == 2).scheduled, 0);
      expect(s.weekday.firstWhere((w) => w.weekday == 1).scheduled, greaterThan(0));
    });
  });
}

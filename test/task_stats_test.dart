import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/utils/task_stats.dart';
import 'package:atlas/shared/models/models.dart';

// Fixed "today" so windows AND streaks are fully deterministic — `now` is
// threaded all the way through computeTaskStats → calculateStreak, so this no
// longer depends on the real environment date.
final _now = DateTime(2026, 6, 22);

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Habit _hab({
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  GoalType? goalType,
  double? goalValue,
  bool effort = false,
  DateTime? createdAt,
  FrequencyMode frequencyMode = FrequencyMode.everyDay,
  int? timesPerWeek,
}) =>
    Habit(
      id: 'h',
      userId: 'u',
      name: 'Gym',
      icon: 'dumbbell',
      sectionId: 'athletic',
      type: HabitType.positive,
      daysOfWeek: days,
      goalType: goalType,
      goalValue: goalValue,
      effortRatingEnabled: effort,
      noteEnabled: false,
      isArchived: false,
      createdAt: createdAt,
      frequencyMode: frequencyMode,
      timesPerWeek: timesPerWeek,
    );

HabitLog _log(
  DateTime d, {
  bool completed = true,
  double? actualValue,
  int? effortRating,
  bool restDay = false,
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
      restDay: restDay,
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

    test('days before the habit existed are not counted as scheduled', () {
      // Created 4 days before "today" → it existed for 5 days incl. today.
      final created = _now.subtract(const Duration(days: 4));
      final logs = [for (int i = 0; i <= 4; i++) _log(_now.subtract(Duration(days: i)))];
      final s = computeTaskStats(
        habit: _hab(createdAt: created),
        logs: logs,
        range: StatRange.month, // 30-day window
        now: _now,
      );
      // Only the 5 days from creation → today count — NOT the full 30-day window,
      // so a brand-new habit reads 100%, not 5/30.
      expect(s.scheduledCount, 5);
      expect(s.completedCount, 5);
      expect(s.completionRate, 1.0);
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

    // ── HABITS_AUDIT §3.2: rest days are neutral, not a miss ─────────────
    group('rest-day awareness', () {
      test('a rest day is excluded from the rate, not counted as a miss', () {
        // Last 7 days: 2 deliberate rests, 5 completed. Without the fix a
        // rest reads as a scheduled-but-missed day and drags the rate to
        // 5/7 instead of the correct 5/5.
        final logs = [
          for (int i = 0; i < 7; i++)
            if (i == 2 || i == 5)
              _log(_now.subtract(Duration(days: i)),
                  completed: false, restDay: true)
            else
              _log(_now.subtract(Duration(days: i))),
        ];
        final s = computeTaskStats(
            habit: _hab(), logs: logs, range: StatRange.week, now: _now);
        expect(s.scheduledCount, 5);
        expect(s.completedCount, 5);
        expect(s.completionRate, 1.0);
      });

      test('a rest day does not break the best streak, mirroring calculateStreak', () {
        // today-4..today, all completed except today-2 which is a rest.
        final logs = [
          for (int i = 0; i <= 4; i++)
            if (i == 2)
              _log(_now.subtract(Duration(days: i)),
                  completed: false, restDay: true)
            else
              _log(_now.subtract(Duration(days: i))),
        ];
        final s = computeTaskStats(
            habit: _hab(), logs: logs, range: StatRange.week, now: _now);
        // The rest is skipped (like a non-scheduled day) rather than
        // resetting the run, so all 4 completed days chain into one streak.
        expect(s.bestStreak, 4);
      });
    });

    // ── HABITS_AUDIT §3.3: flexible "X / week" habits use weekly attainment ──
    group('flexible timesPerWeek habits', () {
      test('hitting the weekly target reads 100%, not a ~43% per-day rate', () {
        // 3 completions somewhere in the last 7 days against a 3x/week goal.
        final logs = [
          _log(_now.subtract(const Duration(days: 0))),
          _log(_now.subtract(const Duration(days: 2))),
          _log(_now.subtract(const Duration(days: 4))),
        ];
        final s = computeTaskStats(
          habit: _hab(
            frequencyMode: FrequencyMode.timesPerWeek,
            timesPerWeek: 3,
            createdAt: _now.subtract(const Duration(days: 30)),
          ),
          logs: logs,
          range: StatRange.week,
          now: _now,
        );
        expect(s.completionRate, 1.0);
        expect(s.scheduledCount, 3);
        expect(s.completedCount, 3);
      });

      test('overshooting the weekly target caps attainment at 1.0', () {
        final logs = [
          for (int i = 0; i < 5; i++) _log(_now.subtract(Duration(days: i))),
        ];
        final s = computeTaskStats(
          habit: _hab(
            frequencyMode: FrequencyMode.timesPerWeek,
            timesPerWeek: 3,
            createdAt: _now.subtract(const Duration(days: 30)),
          ),
          logs: logs,
          range: StatRange.week,
          now: _now,
        );
        expect(s.completionRate, 1.0);
      });

      test('a rest day does not count against the weekly target either', () {
        // 2 completions + 1 rest = target of 3 fully met (the rest is
        // neutral, not a missed session).
        final logs = [
          _log(_now.subtract(const Duration(days: 0))),
          _log(_now.subtract(const Duration(days: 2))),
          _log(_now.subtract(const Duration(days: 4)),
              completed: false, restDay: true),
        ];
        final s = computeTaskStats(
          habit: _hab(
            frequencyMode: FrequencyMode.timesPerWeek,
            timesPerWeek: 2,
            createdAt: _now.subtract(const Duration(days: 30)),
          ),
          logs: logs,
          range: StatRange.week,
          now: _now,
        );
        expect(s.completionRate, 1.0);
      });
    });
  });
}

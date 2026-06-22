import '../../shared/models/models.dart';

/// Walks backwards from yesterday, counting consecutive scheduled+completed days.
/// Non-scheduled days are skipped. A scheduled day with no completed log breaks the streak.
int calculateStreak(Habit habit, List<HabitLog> recentLogs) {
  int streak = 0;
  final now = DateTime.now();
  var check = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));

  for (int i = 0; i < 60; i++) {
    if (habit.daysOfWeek.contains(check.weekday)) {
      final ds =
          '${check.year}-${check.month.toString().padLeft(2, '0')}-${check.day.toString().padLeft(2, '0')}';
      final hit = recentLogs.any((l) => l.habitId == habit.id && l.date == ds && l.completed);
      if (hit) {
        streak++;
      } else {
        break;
      }
    }
    check = check.subtract(const Duration(days: 1));
  }

  return streak;
}

/// Canonical *daily-score* streak: consecutive days at/above [breakEven] score
/// (the leveling break-even, 50), walking back from [today].
///
/// - Days absent from [scoreByDate] — no scheduled tasks / no data — are
///   skipped: a rest day neither extends nor breaks the run (mirrors the
///   non-scheduled-day skip in [calculateStreak]).
/// - Today is allowed to be below break-even without breaking the streak (the
///   day is still in progress); it only *extends* the run once it clears
///   break-even.
///
/// Keys in [scoreByDate] must be date-only `DateTime(y, m, d)` values.
int dailyScoreStreak(
  Map<DateTime, int> scoreByDate, {
  DateTime? today,
  int breakEven = 50,
  int maxLookback = 400,
}) {
  final now = today ?? DateTime.now();
  var day = DateTime(now.year, now.month, now.day);
  int streak = 0;
  for (int i = 0; i < maxLookback; i++) {
    final score = scoreByDate[DateTime(day.year, day.month, day.day)];
    if (score == null) {
      // Rest / no-data day — skip without breaking.
    } else if (score >= breakEven) {
      streak++;
    } else if (i != 0) {
      // A past day below break-even ends the run. Today (i == 0) gets grace.
      break;
    }
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

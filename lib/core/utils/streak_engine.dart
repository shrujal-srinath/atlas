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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../core/utils/score_engine.dart';
import '../../../core/utils/streak_engine.dart';
import '../../habits/providers/habit_provider.dart';

// ── Data classes ───────────────────────────────────────────────

class DayScore {
  final DateTime date;
  final double score;
  const DayScore(this.date, this.score);
}

class HabitStreak {
  final Habit habit;
  final int streak;
  const HabitStreak(this.habit, this.streak);
}

class SectionStats {
  final HabitSection section;
  final int total;
  final int completed;
  final double rate;
  const SectionStats(this.section, this.total, this.completed, this.rate);
}

class HeatmapDay {
  final DateTime date;
  final int completed;
  final int total;
  const HeatmapDay(this.date, this.completed, this.total);
}

class AnalyticsData {
  final List<DayScore> weekScores;
  final List<DayScore> monthScores;
  final List<HabitStreak> streaks;
  final List<SectionStats> sections;
  final List<HeatmapDay> heatmap;
  final double weekAvg;
  final double prevWeekAvg;
  final int totalCompletions;
  final int perfectDays;

  const AnalyticsData({
    required this.weekScores,
    required this.monthScores,
    required this.streaks,
    required this.sections,
    required this.heatmap,
    required this.weekAvg,
    required this.prevWeekAvg,
    required this.totalCompletions,
    required this.perfectDays,
  });
}

// ── Provider ───────────────────────────────────────────────────

final analyticsProvider = FutureProvider.autoDispose<AnalyticsData>((ref) async {
  final habits = await ref.watch(habitsProvider.future);
  final recentLogs = await ref.watch(recentHabitLogsProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Helper: date string
  String ds(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Helper: score for a day
  double scoreFor(DateTime day) {
    final dayHabits = habitsForDate(habits, day);
    if (dayHabits.isEmpty) return 0;
    final dayLogs = recentLogs.where((l) => l.date == ds(day)).toList();
    return calculateDailyScore(dayHabits, dayLogs);
  }

  // 7-day scores (this week)
  final weekScores = List.generate(7, (i) {
    final day = DateTime(today.year, today.month, today.day - 6 + i);
    return DayScore(day, scoreFor(day));
  });

  // 28-day scores (month view for chart)
  final monthScores = List.generate(28, (i) {
    final day = DateTime(today.year, today.month, today.day - 27 + i);
    return DayScore(day, scoreFor(day));
  });

  // Week average
  final weekNonZero = weekScores.where((s) => s.score > 0);
  final weekAvg = weekNonZero.isEmpty
      ? 0.0
      : weekNonZero.map((s) => s.score).reduce((a, b) => a + b) / weekNonZero.length;

  // Previous week average
  final prevWeekScores = List.generate(7, (i) {
    final day = DateTime(today.year, today.month, today.day - 13 + i);
    return scoreFor(day);
  }).where((s) => s > 0);
  final prevWeekAvg = prevWeekScores.isEmpty
      ? 0.0
      : prevWeekScores.reduce((a, b) => a + b) / prevWeekScores.length;

  // Streaks — sorted descending
  final streaks = habits
      .map((h) => HabitStreak(h, calculateStreak(h, recentLogs)))
      .where((s) => s.streak > 0)
      .toList()
    ..sort((a, b) => b.streak.compareTo(a.streak));

  // Section stats (today)
  final todayHabits = habitsForDate(habits, today);
  final todayLogs = recentLogs.where((l) => l.date == ds(today)).toList();
  final sections = HabitSection.values.map((s) {
    final secHabits = todayHabits.where((h) => h.section == s).toList();
    final secDone = secHabits
        .where((h) => todayLogs.any((l) => l.habitId == h.id && l.completed))
        .length;
    return SectionStats(
      s,
      secHabits.length,
      secDone,
      secHabits.isEmpty ? 0.0 : secDone / secHabits.length,
    );
  }).toList();

  // 28-day heatmap
  final heatmap = List.generate(28, (i) {
    final day = DateTime(today.year, today.month, today.day - 27 + i);
    final dayHabits = habitsForDate(habits, day);
    final dayLogs = recentLogs.where((l) => l.date == ds(day)).toList();
    final done = dayHabits
        .where((h) => dayLogs.any((l) => l.habitId == h.id && l.completed))
        .length;
    return HeatmapDay(day, done, dayHabits.length);
  });

  // Total completions in last 28 days
  final totalCompletions = heatmap.fold<int>(0, (sum, d) => sum + d.completed);

  // Perfect days (100% score)
  final perfectDays = monthScores.where((s) => s.score >= 99.5).length;

  return AnalyticsData(
    weekScores: weekScores,
    monthScores: monthScores,
    streaks: streaks,
    sections: sections,
    heatmap: heatmap,
    weekAvg: weekAvg,
    prevWeekAvg: prevWeekAvg,
    totalCompletions: totalCompletions,
    perfectDays: perfectDays,
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../core/utils/streak_engine.dart';
import '../../habits/providers/habit_provider.dart';
import '../../home/providers/home_providers.dart';
import '../../journal/domain/journal_entry.dart';
import '../../journal/providers/journal_providers.dart';

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

/// Mean score for one weekday over the window (rest days excluded).
class WeekdayStat {
  final int weekday; // 1 = Mon … 7 = Sun (DateTime.weekday)
  final double avgScore;
  final int days;
  const WeekdayStat(this.weekday, this.avgScore, this.days);
}

/// Completion rate for one day-part over the window.
class PeriodStat {
  final String period; // 'MORNING' | 'AFTERNOON' | 'EVENING' | 'NIGHT'
  final int completed;
  final int scheduled;
  const PeriodStat(this.period, this.completed, this.scheduled);
  double get rate => scheduled == 0 ? 0.0 : completed / scheduled;
}

class AnalyticsData {
  final List<DayScore> weekScores;
  final List<DayScore> monthScores;
  final List<HabitStreak> streaks;
  final List<SectionStats> sections;
  final double weekAvg;
  final double prevWeekAvg;
  final int totalCompletions;
  final int perfectDays;
  /// This-week vs last-week mean section ratio (0..1), for the week-compare card.
  final Map<HabitSection, double> weekSectionAvg;
  final Map<HabitSection, double> prevWeekSectionAvg;
  /// Mean score by weekday (Mon→Sun) and completion rate by day-part.
  final List<WeekdayStat> weekdays;
  final List<PeriodStat> periods;

  const AnalyticsData({
    required this.weekScores,
    required this.monthScores,
    required this.streaks,
    required this.sections,
    required this.weekAvg,
    required this.prevWeekAvg,
    required this.totalCompletions,
    required this.perfectDays,
    required this.weekSectionAvg,
    required this.prevWeekSectionAvg,
    required this.weekdays,
    required this.periods,
  });
}

// ── Provider ───────────────────────────────────────────────────

/// All performance numbers derive from the *modern* score engine via
/// [homeScoreProvider] — the same source the Home and Score screens use, so
/// Trends never disagrees with the Score detail page. (The legacy
/// `calculateDailyScore` is retired.)
final analyticsProvider = FutureProvider.autoDispose<AnalyticsData>((ref) async {
  final habits = await ref.watch(habitsProvider.future);
  final recentLogs = await ref.watch(recentHabitLogsProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Helper: date string
  String ds(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Fetch the modern HomeScore for the 28-day window once; every aggregate
  // below reads from this map. Providers cache per-date, so Trends and Score
  // share the same computation.
  final monthDates = [
    for (int i = 27; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i)
  ];
  final monthHomeScores = await Future.wait(
    monthDates.map((d) => ref.watch(homeScoreProvider(d).future)),
  );
  final scoreByDate = <DateTime, HomeScore>{
    for (int i = 0; i < monthDates.length; i++) monthDates[i]: monthHomeScores[i]
  };

  int scoreFor(DateTime day) => scoreByDate[day]?.score ?? 0;

  // 28-day scores (month view for chart) + last 7 (this week).
  final monthScores = [
    for (final d in monthDates) DayScore(d, scoreFor(d).toDouble())
  ];
  final weekScores = monthScores.sublist(monthScores.length - 7);

  // Week average (non-zero days only — a rest day shouldn't drag the mean).
  final weekNonZero = weekScores.where((s) => s.score > 0);
  final weekAvg = weekNonZero.isEmpty
      ? 0.0
      : weekNonZero.map((s) => s.score).reduce((a, b) => a + b) /
          weekNonZero.length;

  // Previous week (days -13..-7).
  final prevWeekDays = monthDates.sublist(
      monthDates.length - 14, monthDates.length - 7);
  final prevWeekNonZero = prevWeekDays.map(scoreFor).where((s) => s > 0);
  final prevWeekAvg = prevWeekNonZero.isEmpty
      ? 0.0
      : prevWeekNonZero.reduce((a, b) => a + b) / prevWeekNonZero.length;

  // Per-section means for the week-over-week compare card. Uses the same
  // HomeScore.sectionPct (0..110) the Score screen renders, normalised to 0..1.
  Map<HabitSection, double> sectionAvg(List<DateTime> days) {
    final acc = {for (final s in HabitSection.values) s: <double>[]};
    for (final d in days) {
      final hs = scoreByDate[d];
      if (hs == null || hs.total == 0) continue; // skip rest days
      for (final s in HabitSection.values) {
        acc[s]!.add((hs.sectionPct[s] ?? 0) / 100.0);
      }
    }
    return {
      for (final s in HabitSection.values)
        s: acc[s]!.isEmpty
            ? 0.0
            : acc[s]!.reduce((a, b) => a + b) / acc[s]!.length,
    };
  }

  final weekSectionAvg = sectionAvg(monthDates.sublist(monthDates.length - 7));
  final prevWeekSectionAvg = sectionAvg(prevWeekDays);

  // Streaks — sorted descending (per-habit; powers the leaderboard).
  final streaks = habits
      .map((h) => HabitStreak(h, calculateStreak(h, recentLogs)))
      .where((s) => s.streak > 0)
      .toList()
    ..sort((a, b) => b.streak.compareTo(a.streak));

  // Section stats (today) — completion counts for the "TODAY'S SECTIONS" card.
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

  // One pass over the 28-day window for total completions + time-of-day
  // (day-part) completion stats. The heatmap grid renders from the shared
  // consistencyHeatmapProvider, which uses the same completion logic.
  int totalCompletions = 0;
  const periodOrder = ['MORNING', 'AFTERNOON', 'EVENING', 'NIGHT'];
  final periodDone = {for (final p in periodOrder) p: 0};
  final periodSched = {for (final p in periodOrder) p: 0};
  for (final day in monthDates) {
    final dayHabits = habitsForDate(habits, day);
    final dayLogs = recentLogs.where((l) => l.date == ds(day)).toList();
    for (final h in dayHabits) {
      final p = periodForHabit(h);
      periodSched[p] = (periodSched[p] ?? 0) + 1;
      if (dayLogs.any((l) => l.habitId == h.id && l.completed)) {
        periodDone[p] = (periodDone[p] ?? 0) + 1;
        totalCompletions++;
      }
    }
  }
  final periods = [
    for (final p in periodOrder) PeriodStat(p, periodDone[p]!, periodSched[p]!)
  ];

  // Mean score by weekday (Mon→Sun), rest days excluded.
  final wdScores = {for (int w = 1; w <= 7; w++) w: <int>[]};
  for (final d in monthDates) {
    final hs = scoreByDate[d];
    if (hs == null || hs.total == 0) continue;
    wdScores[d.weekday]!.add(hs.score);
  }
  final weekdays = [
    for (int w = 1; w <= 7; w++)
      WeekdayStat(
        w,
        wdScores[w]!.isEmpty
            ? 0.0
            : wdScores[w]!.reduce((a, b) => a + b) / wdScores[w]!.length,
        wdScores[w]!.length,
      )
  ];

  // Perfect days — a true 100 per the XP system (kPerfectDayXp), not >= 99.5.
  final perfectDays = monthScores.where((s) => s.score >= 100).length;

  return AnalyticsData(
    weekScores: weekScores,
    monthScores: monthScores,
    streaks: streaks,
    sections: sections,
    weekAvg: weekAvg,
    prevWeekAvg: prevWeekAvg,
    totalCompletions: totalCompletions,
    perfectDays: perfectDays,
    weekSectionAvg: weekSectionAvg,
    prevWeekSectionAvg: prevWeekSectionAvg,
    weekdays: weekdays,
    periods: periods,
  );
});

// ── Wellness × performance correlation ─────────────────────────

/// Avg score on "good" vs "low" days for one wellness metric.
class WellnessCorrelation {
  final String label;
  final double highAvgScore;
  final double lowAvgScore;
  final int highDays;
  final int lowDays;
  const WellnessCorrelation({
    required this.label,
    required this.highAvgScore,
    required this.lowAvgScore,
    required this.highDays,
    required this.lowDays,
  });

  double get delta => highAvgScore - lowAvgScore;
  /// Enough days on both sides to be worth showing.
  bool get hasData => highDays >= 2 && lowDays >= 2;
}

/// Pairs the last 30 days of wellness check-ins (energy / sleep / mood) with
/// that day's score and contrasts the mean score on good days vs low days —
/// "do you actually perform better when you sleep well?". Reads the unified
/// score via [analyticsProvider] so the numbers match the rest of Trends.
final wellnessVsScoreProvider =
    FutureProvider.autoDispose<List<WellnessCorrelation>>((ref) async {
  final entries = await ref.watch(journalLast30Provider.future);
  if (entries.isEmpty) return const [];
  final data = await ref.watch(analyticsProvider.future);

  final scoreByDate = <DateTime, int>{
    for (final d in data.monthScores)
      DateTime(d.date.year, d.date.month, d.date.day): d.score.round()
  };

  int? scoreFor(DateTime date) =>
      scoreByDate[DateTime(date.year, date.month, date.day)];

  /// Splits days into high/low buckets by [pick] and contrasts mean score.
  /// [isHigh]/[isLow] classify the raw metric value.
  WellnessCorrelation? corr(
    String label,
    num? Function(JournalEntry) pick,
    bool Function(num) isHigh,
    bool Function(num) isLow,
  ) {
    final high = <int>[];
    final low = <int>[];
    for (final e in entries) {
      final v = pick(e);
      if (v == null) continue;
      final s = scoreFor(e.date);
      if (s == null || s <= 0) continue; // only days with a real score
      if (isHigh(v)) high.add(s);
      if (isLow(v)) low.add(s);
    }
    if (high.isEmpty && low.isEmpty) return null;
    double avg(List<int> xs) =>
        xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;
    return WellnessCorrelation(
      label: label,
      highAvgScore: avg(high),
      lowAvgScore: avg(low),
      highDays: high.length,
      lowDays: low.length,
    );
  }

  final candidates = <WellnessCorrelation?>[
    // 1..5 scales: 4–5 is good, 1–2 is low.
    corr('Energy', (e) => e.energy, (v) => v >= 4, (v) => v <= 2),
    corr('Mood', (e) => e.mood, (v) => v >= 4, (v) => v <= 2),
    // Sleep hours: 7h+ is good, under 6h is low.
    corr('Sleep', (e) => e.sleepHours, (v) => v >= 7, (v) => v < 6),
  ];
  return [
    for (final c in candidates)
      if (c != null && c.hasData) c
  ];
});

// ── Section trends over time ───────────────────────────────────

/// Per-day section ratios (0..~1.1) across a look-back window, for the
/// multi-line Section Trends chart. Same `HomeScore.sectionPct` the Score
/// screen renders, so the lines agree with the rest of the app.
class SectionTrend {
  final List<DateTime> dates; // oldest → newest
  final Map<HabitSection, List<double>> series;
  const SectionTrend({required this.dates, required this.series});
  bool get isEmpty => dates.isEmpty;
}

/// [days] = 7 / 30 / 90. autoDispose so flipping the range frees the old window.
final sectionTrendProvider =
    FutureProvider.autoDispose.family<SectionTrend, int>((ref, days) async {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final dates = [
    for (int i = days - 1; i >= 0; i--) today.subtract(Duration(days: i))
  ];
  final scores = await Future.wait(
    dates.map((d) => ref.watch(homeScoreProvider(d).future)),
  );
  final series = {for (final s in HabitSection.values) s: <double>[]};
  for (final hs in scores) {
    for (final s in HabitSection.values) {
      series[s]!.add((hs.sectionPct[s] ?? 0) / 100.0);
    }
  }
  return SectionTrend(dates: dates, series: series);
});

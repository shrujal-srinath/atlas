import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../core/utils/day_quality.dart';
import '../../habits/providers/habit_provider.dart';
import '../../home/providers/home_providers.dart';
import '../../journal/domain/journal_entry.dart';
import '../../journal/providers/journal_providers.dart';
import '../../xp/leveling_providers.dart';

// ── Data classes ───────────────────────────────────────────────

class DayScore {
  final DateTime date;
  final double score;
  const DayScore(this.date, this.score);
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
  /// 28-day score series — consumed by the wellness × score correlation.
  final List<DayScore> monthScores;
  final double weekAvg;
  final double prevWeekAvg;
  /// This-week vs last-week mean section ratio (0..1), for the week-compare card.
  final Map<HabitSection, double> weekSectionAvg;
  final Map<HabitSection, double> prevWeekSectionAvg;
  /// Mean score by weekday (Mon→Sun) and completion rate by day-part.
  final List<WeekdayStat> weekdays;
  final List<PeriodStat> periods;

  const AnalyticsData({
    required this.monthScores,
    required this.weekAvg,
    required this.prevWeekAvg,
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

  // Helper: date string
  String ds(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // One batched score series for the 28-day window (2 queries total via
  // [dailyScoreSeriesProvider], not ~56 per-date fetches) — every aggregate
  // below reads from this map, and it shares [computeDayScore] with the Score
  // screen so the numbers always agree.
  final monthSeries = await ref.watch(dailyScoreSeriesProvider(28).future);
  final monthDates = [for (final p in monthSeries) p.date];
  final scoreByDate = <DateTime, ScoredDayPoint>{
    for (final p in monthSeries) p.date: p
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

  // One pass over the 28-day window for time-of-day (day-part) completion stats.
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

  return AnalyticsData(
    monthScores: monthScores,
    weekAvg: weekAvg,
    prevWeekAvg: prevWeekAvg,
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

/// [days] = 30 / 90. autoDispose so flipping the range frees the old window.
///
/// Plots a **7-day trailing moving average** of each section's daily ratio,
/// starting at the user's first active day. Raw daily section ratios are nearly
/// binary (0 or ~1), so an unsmoothed line whipsaws 0↔100 and reads as noise;
/// the rolling average turns it into a legible section-vs-section trend. No-data
/// days (nothing scheduled) are skipped inside the window, not counted as zero.
final sectionTrendProvider =
    FutureProvider.autoDispose.family<SectionTrend, int>((ref, days) async {
  final series = await ref.watch(dailyScoreSeriesProvider(days).future);
  // Real, in-the-past days that actually had scheduled habits — drop future
  // days and no-data days so the trend reflects performance, not empty calendar.
  final active = [for (final p in series) if (!p.isFuture && p.total > 0) p];
  if (active.length < 2) {
    return SectionTrend(dates: [for (final p in active) p.date], series: {
      for (final s in HabitSection.values)
        s: [for (final p in active) (p.sectionPct[s] ?? 0) / 100.0],
    });
  }

  final out = {
    for (final s in HabitSection.values)
      s: trailingMovingAverage(
          [for (final p in active) (p.sectionPct[s] ?? 0) / 100.0], 7),
  };
  return SectionTrend(dates: [for (final p in active) p.date], series: out);
});

/// Trailing moving average of [xs] over a window of [w] (partial at the start:
/// index i averages the up-to-[w] values ending at i). Pure — the smoothing
/// behind the Section Trends chart, extracted so it's unit-testable.
List<double> trailingMovingAverage(List<double> xs, int w) {
  final out = <double>[];
  for (int i = 0; i < xs.length; i++) {
    final lo = (i - w + 1) < 0 ? 0 : (i - w + 1);
    double sum = 0;
    for (int j = lo; j <= i; j++) {
      sum += xs[j];
    }
    out.add(sum / (i - lo + 1));
  }
  return out;
}

// ── Consistency streak (Duolingo-style hero) ───────────────────────────

enum DayWinState { win, miss, rest, future }

class DayWin {
  final DateTime date;
  final DayWinState state;
  const DayWin(this.date, this.state);
}

/// Everything the streak hero needs: the current run (from the canonical
/// [currentScoreStreakProvider], so it always matches the Overview badge), the
/// best-ever run, and the last-7-days win/miss/rest strip. A "win" is a day
/// scoring ≥ break-even (50); a rest day (nothing scheduled) is neutral.
class ScoreStreakSummary {
  final int current;
  final int best;
  final List<DayWin> week; // last 7 days, oldest → newest
  const ScoreStreakSummary(this.current, this.best, this.week);
}

final scoreStreakSummaryProvider =
    FutureProvider.autoDispose<ScoreStreakSummary>((ref) async {
  final current = await ref.watch(currentScoreStreakProvider.future);
  final series = await ref.watch(dailyScoreSeriesProvider(120).future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Win/rest map for the best-run computation (rest days skip, don't break).
  final byDay = <DateTime, bool?>{};
  final byDate = <DateTime, ScoredDayPoint>{};
  for (final p in series) {
    final k = DateTime(p.date.year, p.date.month, p.date.day);
    byDate[k] = p;
    if (p.isFuture) continue;
    byDay[k] = p.total == 0 ? null : p.score >= 50;
  }
  final best = streakSummary(byDay, today: today).best;

  final week = <DayWin>[
    for (int i = 6; i >= 0; i--)
      () {
        final d = today.subtract(Duration(days: i));
        final p = byDate[d];
        final st = d.isAfter(today)
            ? DayWinState.future
            : (p == null || p.total == 0)
                ? DayWinState.rest
                : (p.score >= 50 ? DayWinState.win : DayWinState.miss);
        return DayWin(d, st);
      }(),
  ];
  return ScoreStreakSummary(current, best, week);
});

// ── Consistency intensity (GitHub-style heatmap) ───────────────────────

/// Per-day completion rate (0..1) across all habits over the last [days], for
/// the intensity heatmap. Absent keys are rest days (nothing scheduled) — the
/// heatmap renders those faintest. One query via [statsLogsProvider].
final dayIntensityProvider =
    FutureProvider.autoDispose.family<Map<DateTime, double>, int>(
        (ref, days) async {
  final habits = await ref.watch(habitsProvider.future);
  final logs = await ref.watch(statsLogsProvider(days).future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final out = <DateTime, double>{};
  for (int i = 0; i < days; i++) {
    final d = today.subtract(Duration(days: i));
    final q = computeDayQuality(habits, logs, d);
    if (!q.isRestDay) out[DateTime(d.year, d.month, d.day)] = q.rate;
  }
  return out;
});

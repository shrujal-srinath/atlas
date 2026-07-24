import '../../shared/models/models.dart';
import 'streak_engine.dart';

/// The window a per-task stats view is showing.
enum StatRange { week, month, year }

extension StatRangeX on StatRange {
  String get label => switch (this) {
        StatRange.week => 'Week',
        StatRange.month => 'Month',
        StatRange.year => 'Year',
      };

  /// Trailing days used for the headline rate, weekday split, and the
  /// performance/effort series.
  int get windowDays => switch (this) {
        StatRange.week => 7,
        StatRange.month => 30,
        StatRange.year => 365,
      };
}

/// One bar in the completion-rate trend.
class TrendBucket {
  final String label;
  final double rate; // 0..1
  final bool active; // had any scheduled day (false → render as a rest/empty bar)
  const TrendBucket({required this.label, required this.rate, this.active = true});
}

/// Completion on a given weekday across the range.
class WeekdayStat {
  final int weekday; // 1=Mon .. 7=Sun
  final int completed;
  final int scheduled;
  const WeekdayStat({
    required this.weekday,
    required this.completed,
    required this.scheduled,
  });
  double get rate => scheduled == 0 ? 0 : (completed / scheduled).clamp(0, 1);
}

/// A dated numeric sample — a logged actual value or an effort rating.
class ValuePoint {
  final DateTime date;
  final double value;
  const ValuePoint(this.date, this.value);
}

/// Everything the per-task stats screen renders for one [StatRange].
class TaskStats {
  final int currentStreak;
  final int bestStreak;
  final double completionRate; // 0..1 over the range window
  final int scheduledCount;
  final int completedCount;
  final List<TrendBucket> rateTrend;
  final List<WeekdayStat> weekday;
  final List<ValuePoint> performance; // logged actual values (goal-bearing tasks)
  final double? goalValue; // target line for the performance chart
  final List<ValuePoint> effort; // 1..5 ratings (effort-rated tasks)
  const TaskStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.completionRate,
    required this.scheduledCount,
    required this.completedCount,
    required this.rateTrend,
    required this.weekday,
    required this.performance,
    required this.goalValue,
    required this.effort,
  });
}

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _monthAbbr = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Pure derivation of a task's stats for [range]. No I/O — fully unit-testable.
/// Scheduled days follow the same `daysOfWeek` rule the rest of the app uses
/// (see `habitsForDate` / `calculateStreak`).
TaskStats computeTaskStats({
  required Habit habit,
  required List<HabitLog> logs,
  required StatRange range,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());

  // Sets/maps keyed by date string for O(1) lookups.
  final doneDates = <String>{
    for (final l in logs)
      if (l.completed) l.date,
  };
  final restDates = <String>{
    for (final l in logs)
      if (l.restDay) l.date,
  };
  // Days before the habit existed aren't "scheduled" — they must not dilute the
  // completion rate or blank out streak bars as if the habit were missed then.
  bool scheduledOn(DateTime d) =>
      habit.existedOn(d) && habit.daysOfWeek.contains(d.weekday);
  // A deliberate rest day is neutral — HABITS_AUDIT §3.2: it must not count
  // against the rate/best-streak/weekday split any more than it breaks the
  // *current* streak (`calculateStreak` already skips it the same way).
  bool countsOn(DateTime d) => scheduledOn(d) && !restDates.contains(_ds(d));

  // Flexible "X / week" habits store `daysOfWeek` as all-7 (any day is a
  // valid day to do them), so a per-day denominator reads a perfectly-run
  // 3x/week habit as ~43% (HABITS_AUDIT §3.3). Their headline instead
  // averages weekly attainment (`completedInWeek / timesPerWeek`, capped at
  // 1.0 per week) across the weeks the habit existed in.
  final isFlexible = habit.frequencyMode == FrequencyMode.timesPerWeek &&
      (habit.timesPerWeek ?? 0) > 0;

  // ── Headline rate + weekday split over the trailing window ──────────
  final windowDays = range.windowDays;
  int scheduled = 0, completed = 0;
  final wkCompleted = List<int>.filled(8, 0); // index by weekday 1..7
  final wkScheduled = List<int>.filled(8, 0);
  for (int i = 0; i < windowDays; i++) {
    final d = today.subtract(Duration(days: i));
    if (!countsOn(d)) continue;
    scheduled++;
    wkScheduled[d.weekday]++;
    if (doneDates.contains(_ds(d))) {
      completed++;
      wkCompleted[d.weekday]++;
    }
  }

  double rate;
  if (isFlexible) {
    final weeks =
        _weeklyAttainment(habit, doneDates, restDates, today, windowDays);
    final counted = weeks.where((w) => w.target > 0).toList();
    rate = counted.isEmpty
        ? 0.0
        : counted.map((w) => w.attainment).reduce((a, b) => a + b) /
            counted.length;
    completed = counted.fold(0, (acc, w) => acc + w.completed);
    scheduled = counted.fold(0, (acc, w) => acc + w.target);
  } else {
    rate = scheduled == 0 ? 0.0 : completed / scheduled;
  }

  final weekday = [
    for (int w = 1; w <= 7; w++)
      WeekdayStat(weekday: w, completed: wkCompleted[w], scheduled: wkScheduled[w]),
  ];

  // ── Streaks ─────────────────────────────────────────────────────────
  final current = calculateStreak(habit, logs, now: today);
  int best = 0, run = 0;
  for (int i = 0; i < 366; i++) {
    final d = today.subtract(Duration(days: i));
    if (!countsOn(d)) continue;
    if (doneDates.contains(_ds(d))) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }

  // ── Rate trend buckets (shape depends on range) ─────────────────────
  final trend = switch (range) {
    StatRange.week => _dailyBuckets(countsOn, doneDates, today),
    StatRange.month => _weeklyBuckets(countsOn, doneDates, today),
    StatRange.year => _monthlyBuckets(countsOn, doneDates, today),
  };

  // ── Performance + effort series within the window ───────────────────
  final windowStart = today.subtract(Duration(days: windowDays - 1));
  bool inWindow(HabitLog l) {
    final d = DateTime.tryParse(l.date);
    return d != null && !_dateOnly(d).isBefore(windowStart);
  }

  final performance = <ValuePoint>[
    for (final l in logs)
      if (inWindow(l) && l.actualValue != null && l.actualValue! > 0)
        ValuePoint(DateTime.parse(l.date), l.actualValue!),
  ]..sort((a, b) => a.date.compareTo(b.date));

  final effort = <ValuePoint>[
    for (final l in logs)
      if (inWindow(l) && l.effortRating != null && l.effortRating! > 0)
        ValuePoint(DateTime.parse(l.date), l.effortRating!.toDouble()),
  ]..sort((a, b) => a.date.compareTo(b.date));

  return TaskStats(
    currentStreak: current,
    bestStreak: best,
    completionRate: rate,
    scheduledCount: scheduled,
    completedCount: completed,
    rateTrend: trend,
    weekday: weekday,
    performance: performance,
    goalValue: habit.goalValue,
    effort: effort,
  );
}

/// 7 daily bars (oldest → today). A day reads as done (1.0) or not (0.0);
/// rest days carry `active: false` so the UI can render them muted.
List<TrendBucket> _dailyBuckets(
  bool Function(DateTime) scheduledOn,
  Set<String> doneDates,
  DateTime today,
) {
  final out = <TrendBucket>[];
  for (int i = 6; i >= 0; i--) {
    final d = today.subtract(Duration(days: i));
    final done = doneDates.contains(_ds(d));
    out.add(TrendBucket(
      label: _weekdayLetters[d.weekday - 1],
      rate: done ? 1.0 : 0.0,
      active: scheduledOn(d),
    ));
  }
  return out;
}

/// 5 trailing weekly buckets (W1 oldest → W5 = this week), each a 7-day window.
List<TrendBucket> _weeklyBuckets(
  bool Function(DateTime) scheduledOn,
  Set<String> doneDates,
  DateTime today,
) {
  final out = <TrendBucket>[];
  for (int w = 4; w >= 0; w--) {
    final weekEnd = today.subtract(Duration(days: w * 7));
    int sched = 0, done = 0;
    for (int i = 0; i < 7; i++) {
      final d = weekEnd.subtract(Duration(days: i));
      if (!scheduledOn(d)) continue;
      sched++;
      if (doneDates.contains(_ds(d))) done++;
    }
    out.add(TrendBucket(
      label: 'W${5 - w}',
      rate: sched == 0 ? 0 : done / sched,
      active: sched > 0,
    ));
  }
  return out;
}

/// One trailing 7-day bucket's attainment for a flexible "X / week" habit.
class _WeekAttainment {
  final int completed; // raw completed days this week that count (not rest)
  final int target;    // habit.timesPerWeek, or 0 if it didn't exist that week
  const _WeekAttainment(this.completed, this.target);
  double get attainment => target == 0 ? 0.0 : (completed / target).clamp(0, 1);
}

/// Buckets [windowDays] into trailing non-overlapping 7-day weeks (same
/// construction as [_weeklyBuckets]) and scores each against
/// `habit.timesPerWeek` — the headline number for flexible habits (§3.3).
List<_WeekAttainment> _weeklyAttainment(
  Habit habit,
  Set<String> doneDates,
  Set<String> restDates,
  DateTime today,
  int windowDays,
) {
  final target = habit.timesPerWeek ?? 0;
  final bucketCount = (windowDays / 7).ceil();
  final out = <_WeekAttainment>[];
  for (int w = bucketCount - 1; w >= 0; w--) {
    final weekEnd = today.subtract(Duration(days: w * 7));
    var existedAnyDay = false;
    var completed = 0;
    for (int i = 0; i < 7; i++) {
      final d = weekEnd.subtract(Duration(days: i));
      if (!habit.existedOn(d)) continue;
      existedAnyDay = true;
      final ds = _ds(d);
      if (restDates.contains(ds)) continue; // neutral, not a miss
      if (doneDates.contains(ds)) completed++;
    }
    out.add(_WeekAttainment(completed, existedAnyDay ? target : 0));
  }
  return out;
}

/// 12 trailing calendar-month buckets (oldest → current month).
List<TrendBucket> _monthlyBuckets(
  bool Function(DateTime) scheduledOn,
  Set<String> doneDates,
  DateTime today,
) {
  final out = <TrendBucket>[];
  for (int m = 11; m >= 0; m--) {
    final monthStart = DateTime(today.year, today.month - m, 1);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    int sched = 0, done = 0;
    var d = monthStart;
    while (!d.isAfter(monthEnd) && !d.isAfter(today)) {
      if (scheduledOn(d)) {
        sched++;
        if (doneDates.contains(_ds(d))) done++;
      }
      d = d.add(const Duration(days: 1));
    }
    out.add(TrendBucket(
      label: _monthAbbr[monthStart.month],
      rate: sched == 0 ? 0 : done / sched,
      active: sched > 0,
    ));
  }
  return out;
}

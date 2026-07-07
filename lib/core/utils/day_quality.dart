import '../../shared/models/models.dart';

/// How a single day went across *all* habits — the basis for the Stats-hub
/// calendar's "good day" streak.
///
/// A **good day** = no negative-habit slips AND ≥85% of scheduled positive/todo
/// habits done. Negatives are **clean by default** — a slip is only a logged
/// "broke" mark (`completed == false`) that day (mirrors `taskRatio`). Days with
/// nothing scheduled are rest days — neutral, they neither extend nor break a
/// streak.
class DayQuality {
  final int posScheduled;
  final int posDone;
  final int negScheduled;
  final int negSlips;
  const DayQuality({
    required this.posScheduled,
    required this.posDone,
    required this.negScheduled,
    required this.negSlips,
  });

  static const empty =
      DayQuality(posScheduled: 0, posDone: 0, negScheduled: 0, negSlips: 0);

  int get totalScheduled => posScheduled + negScheduled;
  bool get isRestDay => totalScheduled == 0;

  /// Overall completion in `[0,1]` (positives done + negatives maintained),
  /// for the intensity shade. Rest days read 0.
  double get rate {
    if (totalScheduled == 0) return 0;
    final maintained = negScheduled - negSlips;
    return ((posDone + maintained) / totalScheduled).clamp(0.0, 1.0);
  }

  /// Completion of just the positive/todo side (what "performance %" shows).
  double get positiveRate =>
      posScheduled == 0 ? 1.0 : (posDone / posScheduled).clamp(0.0, 1.0);

  bool get isGoodDay =>
      !isRestDay && negSlips == 0 && (posScheduled == 0 || positiveRate >= 0.85);
}

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Quality of [day] across [habits], given that day's [logs]. Pure — no I/O.
DayQuality computeDayQuality(
  List<Habit> habits,
  List<HabitLog> logs,
  DateTime day,
) {
  final key = _ds(day);
  final dow = day.weekday;
  final doneByHabit = <String, bool>{
    for (final l in logs)
      if (l.date == key) l.habitId: l.completed,
  };
  // Deliberate rest days are neutral — excluded from the day's scheduled set so
  // they neither extend nor break the good-day streak (mirrors the score).
  final restedHabits = <String>{
    for (final l in logs)
      if (l.date == key && l.restDay) l.habitId,
  };

  int posScheduled = 0, posDone = 0, negScheduled = 0, negSlips = 0;
  for (final h in habits) {
    // Skip days before the habit existed — it can't have been "missed" then.
    if (h.isArchived || !h.existedOn(day) || !h.daysOfWeek.contains(dow)) {
      continue;
    }
    if (restedHabits.contains(h.id)) continue;
    if (h.type == HabitType.negative) {
      negScheduled++;
      // Clean by default — only an explicit "broke" log (completed:false) slips.
      if (doneByHabit[h.id] == false) negSlips++;
    } else {
      posScheduled++;
      if (doneByHabit[h.id] == true) posDone++;
    }
  }
  return DayQuality(
    posScheduled: posScheduled,
    posDone: posDone,
    negScheduled: negScheduled,
    negSlips: negSlips,
  );
}

/// Current + best streak over a date→state map: `true` = a win day (extends),
/// `false` = a miss (breaks), `null` = rest/no-data (skipped). Mirrors
/// [dailyScoreStreak]: rest days skip without breaking, and *today* gets grace
/// (a today-miss doesn't break the current run, it just doesn't extend it).
///
/// Keys must be date-only `DateTime(y,m,d)`.
({int current, int best}) streakSummary(
  Map<DateTime, bool?> byDay, {
  DateTime? today,
  int maxLookback = 420,
}) {
  final now = today ?? DateTime.now();
  final start = DateTime(now.year, now.month, now.day);

  // Current: walk back from today.
  int current = 0;
  for (int i = 0; i < maxLookback; i++) {
    final d = start.subtract(Duration(days: i));
    final state = byDay[DateTime(d.year, d.month, d.day)];
    if (state == null) {
      continue; // rest / no data — skip
    } else if (state) {
      current++;
    } else if (i != 0) {
      break; // a past miss ends the run
    }
    // today-miss (i == 0, state == false): grace, neither extends nor breaks
  }

  // Best: longest win-run over the looked-back window (rest days skip).
  int best = 0, run = 0;
  for (int i = maxLookback - 1; i >= 0; i--) {
    final d = start.subtract(Duration(days: i));
    final state = byDay[DateTime(d.year, d.month, d.day)];
    if (state == null) continue;
    if (state) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }
  if (current > best) best = current;

  return (current: current, best: best);
}

/// Per-date run length (consecutive wins ending there, rest days skipped) and
/// the set of dates belonging to the *current* run ending today (today-miss
/// gets grace, so the run ending yesterday still counts). Feeds the calendar
/// ribbon's milestone flames and current-run glow. Keys are date-only.
({Map<DateTime, int> runLength, Set<DateTime> current}) streakRuns(
  Map<DateTime, bool?> byDay, {
  DateTime? today,
  int maxLookback = 420,
}) {
  final now = today ?? DateTime.now();
  final start = DateTime(now.year, now.month, now.day);

  final runLength = <DateTime, int>{};
  int run = 0;
  for (int i = maxLookback - 1; i >= 0; i--) {
    final d = start.subtract(Duration(days: i));
    final key = DateTime(d.year, d.month, d.day);
    final s = byDay[key];
    if (s == null) continue;
    if (s) {
      run++;
      runLength[key] = run;
    } else {
      run = 0;
    }
  }

  final current = <DateTime>{};
  for (int i = 0; i < maxLookback; i++) {
    final d = start.subtract(Duration(days: i));
    final key = DateTime(d.year, d.month, d.day);
    final s = byDay[key];
    if (s == null) continue;
    if (s) {
      current.add(key);
    } else if (i == 0) {
      continue; // today-miss grace: keep collecting the prior run
    } else {
      break;
    }
  }

  return (runLength: runLength, current: current);
}

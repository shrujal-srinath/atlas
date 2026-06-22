/// Home-screen data layer. Every home widget reads from a provider here so
/// the week-strip switch genuinely re-scopes score + tasks + (today) fuel.
/// Section weighting and priority multipliers from [PriorityWeights] are
/// applied centrally — the UI never does its own math.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/streak_engine.dart';
import '../../../shared/models/models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../food/providers/food_providers.dart';
import '../../habits/providers/habit_provider.dart';
import '../scoring/score_engine.dart';

// ────────────────────────────────────────────────────────────────────
// PUBLIC MODELS — what the UI consumes.
// ────────────────────────────────────────────────────────────────────

class HomeWeekDay {
  final DateTime date;
  final String dowLabel;       // 'W', 'T', 'F' …
  final int dayNum;            // 1–31
  final int score;             // 0–100
  final int done;
  final int total;
  final Map<HabitSection, int> sectionPct;
  final bool isToday;
  final bool isFuture;
  const HomeWeekDay({
    required this.date,
    required this.dowLabel,
    required this.dayNum,
    required this.score,
    required this.done,
    required this.total,
    required this.sectionPct,
    required this.isToday,
    required this.isFuture,
  });
}

class HomeScore {
  final int score;
  final int done;
  final int total;
  final Map<HabitSection, int> sectionPct;
  final int projectedScore;    // if remaining tasks get completed
  /// Per-task contributions, sorted highest-impact first. Drives the
  /// "where your score comes from" list on the score detail page.
  final List<TaskContribution> perTaskContrib;
  const HomeScore({
    required this.score,
    required this.done,
    required this.total,
    required this.sectionPct,
    required this.projectedScore,
    this.perTaskContrib = const [],
  });
}

class HomeTask {
  final Habit habit;
  final HabitLog? log;
  final String period;          // 'MORNING' | 'AFTERNOON' | 'EVENING' | 'NIGHT'
  final String time;            // 'HH:mm', '' if none
  /// Completion ratio in `[0, kOvershootCap]`. Computed by [taskRatio] from
  /// the habit's goal + log's actualValue. For binary habits this is 0 or 1.
  final double ratio;
  /// Consecutive scheduled+completed days walking back from yesterday.
  /// Powered by [calculateStreak]; non-scheduled days are skipped.
  final int streak;
  const HomeTask({
    required this.habit,
    this.log,
    required this.period,
    required this.time,
    required this.ratio,
    this.streak = 0,
  });

  /// Back-compat boolean — true when the task has reached its goal.
  bool get isCompleted => ratio >= 1.0;
}

// ────────────────────────────────────────────────────────────────────
// HELPERS
// ────────────────────────────────────────────────────────────────────

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dowLabel(int weekday) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][(weekday - 1).clamp(0, 6)];

/// The day-part a habit belongs to ('MORNING' | 'AFTERNOON' | 'EVENING' |
/// 'NIGHT'), from its [Habit.timePeriod] or scheduled time. Public so the
/// Trends time-of-day breakdown can bucket completions the same way the home
/// task list groups them.
String periodForHabit(Habit h) {
  final tp = h.timePeriod;
  if (tp != null) {
    return switch (tp) {
      TimePeriod.morning => 'MORNING',
      TimePeriod.afternoon => 'AFTERNOON',
      TimePeriod.evening => 'EVENING',
    };
  }
  final t = h.scheduledTime;
  if (t != null && t.contains(':')) {
    final hr = int.tryParse(t.split(':').first) ?? 8;
    if (hr < 12) return 'MORNING';
    if (hr < 17) return 'AFTERNOON';
    if (hr < 22) return 'EVENING';
    return 'NIGHT';
  }
  return 'MORNING';
}

bool _appliesOn(Habit h, DateTime date) {
  if (h.isArchived) return false;
  if (h.type == HabitType.todo) {
    if (h.dueDate == null) return true;
    final dd = h.dueDate!;
    return dd.year == date.year && dd.month == date.month && dd.day == date.day;
  }
  switch (h.frequencyMode) {
    case FrequencyMode.everyDay:
      return true;
    case FrequencyMode.specificDays:
      return h.daysOfWeek.contains(date.weekday);
    case FrequencyMode.timesPerWeek:
      return true; // always show, user picks which days
  }
}

// ────────────────────────────────────────────────────────────────────
// PROVIDERS
// ────────────────────────────────────────────────────────────────────

/// Per-user section weights, normalized to fractions summing to ~1.0.
/// Falls back to [kDefaultSectionWeights] (40/30/30) when the user profile
/// has no override.
final sectionWeightsProvider = Provider<Map<HabitSection, double>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return normalizeSectionWeights(user?.sectionWeightsJson);
});

/// All HomeTasks for [date] — applicable habits joined with that day's logs.
/// Sorted by period then scheduled time.
final homeTasksProvider =
    FutureProvider.family<List<HomeTask>, DateTime>((ref, date) async {
  final habits = await ref.watch(habitsProvider.future);
  final logs = await ref.watch(habitLogsForDateProvider(_dateKey(date)).future);
  final logByHabit = {for (final l in logs) l.habitId: l};

  // Recent (60-day) logs power the per-task streak chip. The provider already
  // exists; we only need it grouped by habitId so calculateStreak runs in O(N)
  // instead of scanning the whole list per habit.
  final recent = await ref.watch(recentHabitLogsProvider.future);
  final recentByHabit = <String, List<HabitLog>>{};
  for (final l in recent) {
    (recentByHabit[l.habitId] ??= []).add(l);
  }

  final tasks = <HomeTask>[];
  for (final h in habits) {
    if (!_appliesOn(h, date)) continue;
    final l = logByHabit[h.id];
    tasks.add(HomeTask(
      habit: h,
      log: l,
      period: periodForHabit(h),
      time: h.scheduledTime ?? '',
      ratio: taskRatio(h, l),
      streak: calculateStreak(h, recentByHabit[h.id] ?? const []),
    ));
  }
  tasks.sort((a, b) {
    final pa = _periodOrder(a.period);
    final pb = _periodOrder(b.period);
    if (pa != pb) return pa.compareTo(pb);
    return a.time.compareTo(b.time);
  });
  return tasks;
});

int _periodOrder(String p) => switch (p) {
      'MORNING' => 0,
      'AFTERNOON' => 1,
      'EVENING' => 2,
      'NIGHT' => 3,
      _ => 4,
    };

/// How much of the body section is driven by nutrition vs. habits. 50/50.
/// Tunable: bump up to give nutrition more weight in the body score.
const double kNutritionBodyWeight = 0.5;

/// Weighted score for [date]. Delegates the math to the pure [computeScore]
/// engine — this provider is a thin adapter that fetches inputs, looks up
/// section weights, and re-wraps the result as a [HomeScore] for UI consumers.
///
/// Today and past dates blend the body section 50/50 with that day's
/// nutrition adherence ratio (calorie + protein, phase-aware) — today via the
/// live [todayNutritionRatioProvider], past days via the per-date
/// [nutritionRatioForDateProvider]. Future dates stay habit-only (no food
/// logged yet). This keeps the score the snapshot writer persists consistent
/// with what the score screen shows when browsing history.
final homeScoreProvider =
    FutureProvider.family<HomeScore, DateTime>((ref, date) async {
  final tasks = await ref.watch(homeTasksProvider(date).future);
  final weights = ref.watch(sectionWeightsProvider);
  if (tasks.isEmpty) {
    return const HomeScore(
      score: 0,
      done: 0,
      total: 0,
      sectionPct: {
        HabitSection.athletic: 0,
        HabitSection.mind: 0,
        HabitSection.body: 0,
      },
      projectedScore: 0,
    );
  }
  final b = computeScore(
    tasks: [for (final t in tasks) ScoredTaskInput(t.habit, t.log)],
    sectionWeights: weights,
  );

  // Blend nutrition into the body section for today (live) and past days
  // (time-travel). Future days have no food logged yet → habit-only.
  final now = DateTime.now();
  final dateOnly = DateTime(date.year, date.month, date.day);
  final todayOnly = DateTime(now.year, now.month, now.day);
  final isToday = dateOnly == todayOnly;
  final isFuture = dateOnly.isAfter(todayOnly);
  double? nutritionRatio;
  if (isToday) {
    // Live, invalidation-wired ratio — must stay pinned to today.
    nutritionRatio = ref.watch(todayNutritionRatioProvider);
  } else if (!isFuture) {
    nutritionRatio =
        await ref.watch(nutritionRatioForDateProvider(dateOnly).future);
  }

  double bodyRatio = b.sectionRatio[HabitSection.body] ?? 0;
  double bodyProjected = b.sectionPotential[HabitSection.body] ?? 0;
  if (nutritionRatio != null) {
    bodyRatio = bodyRatio * (1 - kNutritionBodyWeight) +
        nutritionRatio * kNutritionBodyWeight;
    // Projected assumes nutrition reaches 1.0.
    bodyProjected = bodyProjected * (1 - kNutritionBodyWeight) +
        1.0 * kNutritionBodyWeight;
  }

  // Re-derive the final score with the blended body ratio.
  final athRatio = b.sectionRatio[HabitSection.athletic] ?? 0;
  final mindRatio = b.sectionRatio[HabitSection.mind] ?? 0;
  final wAth = weights[HabitSection.athletic] ?? 0;
  final wMind = weights[HabitSection.mind] ?? 0;
  final wBody = weights[HabitSection.body] ?? 0;
  final blendedScore =
      ((athRatio * wAth + mindRatio * wMind + bodyRatio * wBody) * 100)
          .round()
          .clamp(0, 100);
  final blendedProjected = ((athRatio * wAth +
              mindRatio * wMind +
              bodyProjected * wBody) *
          100)
      .round()
      .clamp(0, 100);

  final sectionPct = <HabitSection, int>{
    HabitSection.athletic:
        ((b.sectionRatio[HabitSection.athletic] ?? 0) * 100).round().clamp(0, 110),
    HabitSection.mind:
        ((b.sectionRatio[HabitSection.mind] ?? 0) * 100).round().clamp(0, 110),
    HabitSection.body: (bodyRatio * 100).round().clamp(0, 110),
  };

  return HomeScore(
    score: blendedScore,
    done: b.doneCount,
    total: b.totalCount,
    sectionPct: sectionPct,
    projectedScore: blendedProjected,
    perTaskContrib: b.perTaskContrib,
  );
});

/// 7-day window centred on [anchor] (3 before, anchor, 3 after).
final homeWeekProvider =
    FutureProvider.family<List<HomeWeekDay>, DateTime>((ref, anchor) async {
  final today = DateTime.now();
  final todayKey = _dateKey(today);
  final out = <HomeWeekDay>[];
  for (int i = -3; i <= 3; i++) {
    final d = DateTime(anchor.year, anchor.month, anchor.day).add(Duration(days: i));
    final score = await ref.watch(homeScoreProvider(d).future);
    final isToday = _dateKey(d) == todayKey;
    final isFuture = d.isAfter(today);
    out.add(HomeWeekDay(
      date: d,
      dowLabel: _dowLabel(d.weekday),
      dayNum: d.day,
      score: score.score,
      done: score.done,
      total: score.total,
      sectionPct: score.sectionPct,
      isToday: isToday,
      isFuture: isFuture,
    ));
  }
  return out;
});

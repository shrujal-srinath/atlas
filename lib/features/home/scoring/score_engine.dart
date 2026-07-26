/// Pure scoring engine — no Riverpod, Supabase, or BuildContext dependencies.
///
/// Designed so it can be unit-tested in isolation and re-used by the future
/// leveling/XP system. Every function here is deterministic given its inputs.
library;

import '../../../shared/models/models.dart';
import '../../xp/priority_weights.dart';

/// A single task may contribute up to 110% of its weight (10% overshoot bonus).
/// The final 0–100 score is still clamped — overshoot helps a section bar feel
/// rewarding for stretch effort without letting one habit dominate the day.
const double kOvershootCap = 1.10;

/// Ratios below this don't earn XP — prevents "tap +1 once" XP farming.
const double kMinRatioForXp = 0.05;

/// A negative ("avoid") habit is **clean by default** — it earns full credit
/// every day unless the user logs a slip. A slip (`completed == false`) drags
/// the day *below* baseline by contributing this negative ratio, so breaking a
/// quit-habit actively costs score/XP (not merely zero). Tunable.
const double kNegativeSlipRatio = -1.0;

/// Returns a task's completion ratio.
///
/// - **Negative habits**: clean by default → `+1.0` when there's no log or a
///   "stayed clean" log; a slip (`completed == false`) → [kNegativeSlipRatio].
/// - `log == null` (non-negative) → 0.0
/// - Todos → binary on `log.completed`
/// - Positive habits without a numeric goal → binary on `log.completed`
/// - Numeric positive habits → `(actualValue ?? (completed ? goalValue : 0)) / goalValue`,
///   clamped to `[0, kOvershootCap]`. Legacy logs (no `actualValue`, `completed = true`)
///   resolve to exactly `1.0`.
double taskRatio(Habit habit, HabitLog? log) {
  if (habit.type == HabitType.negative) {
    // Clean unless explicitly logged as a slip.
    if (log == null) return 1.0;
    return log.completed ? 1.0 : kNegativeSlipRatio;
  }
  if (log == null) return 0.0;
  if (habit.type == HabitType.todo) {
    return log.completed ? 1.0 : 0.0;
  }
  final goal = habit.goalValue;
  if (habit.goalType == null || goal == null || goal <= 0) {
    return log.completed ? 1.0 : 0.0;
  }
  final actual = log.actualValue ?? (log.completed ? goal : 0.0);
  final raw = actual / goal;
  if (raw <= 0) return 0.0;
  if (raw >= kOvershootCap) return kOvershootCap;
  return raw;
}

/// Input row for [computeScore]. Pairing a habit with its (optional) log avoids
/// passing the full [HomeTask] type and keeps the engine independent of the
/// home providers.
class ScoredTaskInput {
  final Habit habit;
  final HabitLog? log;
  const ScoredTaskInput(this.habit, this.log);
}

/// One row in the score-page contribution list.
class TaskContribution {
  final Habit habit;
  final HabitLog? log;
  final double ratio;
  /// Current contribution to the displayed 0–100 final score.
  final double contributedPts;
  /// Maximum contribution if the task were completed exactly (ratio = 1.0).
  final double potentialPts;
  const TaskContribution({
    required this.habit,
    required this.log,
    required this.ratio,
    required this.contributedPts,
    required this.potentialPts,
  });

  double get remainingPts {
    final r = potentialPts - contributedPts;
    return r < 0 ? 0.0 : r;
  }

  bool get isCompleted => ratio >= 1.0;
}

class ScoreBreakdown {
  final int score;
  final int projectedScore;
  /// Per-section completion ratio in `[0, kOvershootCap]`.
  final Map<HabitSection, double> sectionRatio;
  /// Per-section ceiling (1.0 if section has any tasks, 0.0 otherwise).
  final Map<HabitSection, double> sectionPotential;
  final int doneCount;
  final int totalCount;
  /// Highest-contribution first.
  final List<TaskContribution> perTaskContrib;

  const ScoreBreakdown({
    required this.score,
    required this.projectedScore,
    required this.sectionRatio,
    required this.sectionPotential,
    required this.doneCount,
    required this.totalCount,
    required this.perTaskContrib,
  });

  static const ScoreBreakdown empty = ScoreBreakdown(
    score: 0,
    projectedScore: 0,
    sectionRatio: {
      HabitSection.athletic: 0.0,
      HabitSection.mind: 0.0,
      HabitSection.body: 0.0,
    },
    sectionPotential: {
      HabitSection.athletic: 0.0,
      HabitSection.mind: 0.0,
      HabitSection.body: 0.0,
    },
    doneCount: 0,
    totalCount: 0,
    perTaskContrib: [],
  );
}

/// Computes the full breakdown for the given task set.
///
/// [sectionWeights] should be pre-normalized so its values sum to ~1.0 across
/// the three sections (see [normalizeSectionWeights]). The default 40/30/30
/// becomes {0.4, 0.3, 0.3}.
ScoreBreakdown computeScore({
  required List<ScoredTaskInput> tasks,
  required Map<HabitSection, double> sectionWeights,
}) {
  if (tasks.isEmpty) return ScoreBreakdown.empty;

  // Group + per-section denominators.
  final perSectionDenom = <HabitSection, double>{
    for (final s in HabitSection.values) s: 0.0,
  };
  final perSectionTasks = <HabitSection, List<ScoredTaskInput>>{
    for (final s in HabitSection.values) s: <ScoredTaskInput>[],
  };
  for (final t in tasks) {
    final w = weightsFor(t.habit.priority).score;
    final sec = t.habit.sectionId.toSectionEnum();
    perSectionDenom[sec] = perSectionDenom[sec]! + w;
    perSectionTasks[sec]!.add(t);
  }

  // Per-task ratio + contribution; per-section accumulators.
  final contribs = <TaskContribution>[];
  int doneCount = 0;
  final perSectionRatio = <HabitSection, double>{};
  final perSectionPotential = <HabitSection, double>{};

  for (final s in HabitSection.values) {
    final denom = perSectionDenom[s]!;
    if (denom == 0) {
      perSectionRatio[s] = 0.0;
      perSectionPotential[s] = 0.0;
      continue;
    }
    final sectionW = sectionWeights[s] ?? 0.0;
    double weightedRatio = 0;
    for (final t in perSectionTasks[s]!) {
      final r = taskRatio(t.habit, t.log);
      final prioW = weightsFor(t.habit.priority).score;
      weightedRatio += r * prioW;
      if (r >= 1.0) doneCount++;
      final contribPts = (r * prioW / denom) * sectionW * 100;
      final potPts = (prioW / denom) * sectionW * 100;
      contribs.add(TaskContribution(
        habit: t.habit,
        log: t.log,
        ratio: r,
        contributedPts: contribPts,
        potentialPts: potPts,
      ));
    }
    final secRatio = weightedRatio / denom;
    perSectionRatio[s] = secRatio > kOvershootCap ? kOvershootCap : secRatio;
    perSectionPotential[s] = 1.0;
  }

  // Final scores.
  double weighted = 0;
  double weightedProj = 0;
  for (final s in HabitSection.values) {
    final secW = sectionWeights[s] ?? 0.0;
    weighted += perSectionRatio[s]! * secW * 100;
    weightedProj += perSectionPotential[s]! * secW * 100;
  }
  int score = weighted.round();
  int projectedScore = weightedProj.round();
  if (score < 0) score = 0;
  if (score > 100) score = 100;
  if (projectedScore < 0) projectedScore = 0;
  if (projectedScore > 100) projectedScore = 100;

  contribs.sort((a, b) => b.contributedPts.compareTo(a.contributedPts));

  return ScoreBreakdown(
    score: score,
    projectedScore: projectedScore,
    sectionRatio: perSectionRatio,
    sectionPotential: perSectionPotential,
    doneCount: doneCount,
    totalCount: tasks.length,
    perTaskContrib: contribs,
  );
}

/// Default fractions used when the user hasn't set `users.section_weights`.
const Map<HabitSection, double> kDefaultSectionWeights = {
  HabitSection.athletic: 0.4,
  HabitSection.mind: 0.3,
  HabitSection.body: 0.3,
};

// ════════════════════════════════════════════════════════════════════
// Full day score (habits + nutrition blend)
// ════════════════════════════════════════════════════════════════════

/// Default share of the body section driven by nutrition adherence (the rest
/// is body habits). Lives here so the live home score and the stats series
/// blend the body section identically — one source of truth, no drift.
const double kDefaultNutritionWeight = 0.5;

/// A fully-computed day score: the section-weighted, priority-weighted habit
/// score with the body section optionally blended with that day's nutrition
/// adherence. Produced by [computeDayScore].
class ScoredDay {
  final int score; // 0..100
  final int projectedScore; // 0..100, if remaining tasks complete
  final Map<HabitSection, int> sectionPct; // 0..110 per section
  final int done;
  final int total;
  final List<TaskContribution> perTaskContrib;
  const ScoredDay({
    required this.score,
    required this.projectedScore,
    required this.sectionPct,
    required this.done,
    required this.total,
    required this.perTaskContrib,
  });

  static const ScoredDay empty = ScoredDay(
    score: 0,
    projectedScore: 0,
    sectionPct: {
      HabitSection.athletic: 0,
      HabitSection.mind: 0,
      HabitSection.body: 0,
    },
    done: 0,
    total: 0,
    perTaskContrib: [],
  );
}

/// Runs [computeScore] then blends the body section with [nutritionRatio]
/// (0..1; `null` = habit-only, e.g. future days). [nutritionWeight] is the
/// fraction of the body section that nutrition occupies. Pure + deterministic.
ScoredDay computeDayScore({
  required List<ScoredTaskInput> tasks,
  required Map<HabitSection, double> sectionWeights,
  double? nutritionRatio,
  double nutritionWeight = kDefaultNutritionWeight,
}) {
  if (tasks.isEmpty) return ScoredDay.empty;
  final b = computeScore(tasks: tasks, sectionWeights: sectionWeights);

  double bodyRatio = b.sectionRatio[HabitSection.body] ?? 0;
  double bodyProjected = b.sectionPotential[HabitSection.body] ?? 0;
  if (nutritionRatio != null) {
    bodyRatio =
        bodyRatio * (1 - nutritionWeight) + nutritionRatio * nutritionWeight;
    bodyProjected =
        bodyProjected * (1 - nutritionWeight) + 1.0 * nutritionWeight;
  }

  final athRatio = b.sectionRatio[HabitSection.athletic] ?? 0;
  final mindRatio = b.sectionRatio[HabitSection.mind] ?? 0;
  final wAth = sectionWeights[HabitSection.athletic] ?? 0;
  final wMind = sectionWeights[HabitSection.mind] ?? 0;
  final wBody = sectionWeights[HabitSection.body] ?? 0;

  final score =
      ((athRatio * wAth + mindRatio * wMind + bodyRatio * wBody) * 100)
          .round()
          .clamp(0, 100);
  final projected =
      ((athRatio * wAth + mindRatio * wMind + bodyProjected * wBody) * 100)
          .round()
          .clamp(0, 100);

  return ScoredDay(
    score: score,
    projectedScore: projected,
    sectionPct: {
      HabitSection.athletic: ((b.sectionRatio[HabitSection.athletic] ?? 0) * 100)
          .round()
          .clamp(0, 110),
      HabitSection.mind:
          ((b.sectionRatio[HabitSection.mind] ?? 0) * 100).round().clamp(0, 110),
      HabitSection.body: (bodyRatio * 100).round().clamp(0, 110),
    },
    done: b.doneCount,
    total: b.totalCount,
    perTaskContrib: b.perTaskContrib,
  );
}

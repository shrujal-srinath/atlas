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

/// Returns a task's completion ratio in `[0, kOvershootCap]`.
///
/// - `log == null` → 0.0
/// - Negative habits and todos → binary on `log.completed`
/// - Positive habits without a numeric goal → binary on `log.completed`
/// - Numeric positive habits → `(actualValue ?? (completed ? goalValue : 0)) / goalValue`,
///   clamped to `[0, kOvershootCap]`. Legacy logs (no `actualValue`, `completed = true`)
///   resolve to exactly `1.0`.
double taskRatio(Habit habit, HabitLog? log) {
  if (log == null) return 0.0;
  if (habit.type == HabitType.negative || habit.type == HabitType.todo) {
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
    perSectionDenom[t.habit.section] = perSectionDenom[t.habit.section]! + w;
    perSectionTasks[t.habit.section]!.add(t);
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

/// Normalizes a raw Supabase map (e.g. `{athletic: 40, mind: 30, body: 30}`)
/// into fractions that sum to 1.0. Falls back to [kDefaultSectionWeights] if
/// the input is null, empty, or sums to zero.
Map<HabitSection, double> normalizeSectionWeights(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) return kDefaultSectionWeights;
  double pick(String k, double dflt) => (raw[k] as num?)?.toDouble() ?? dflt;
  final a = pick('athletic', 0);
  final m = pick('mind', 0);
  final b = pick('body', 0);
  final sum = a + m + b;
  if (sum <= 0) return kDefaultSectionWeights;
  return {
    HabitSection.athletic: a / sum,
    HabitSection.mind: m / sum,
    HabitSection.body: b / sum,
  };
}

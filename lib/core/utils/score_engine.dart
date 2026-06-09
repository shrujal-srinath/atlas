import '../../features/phase/phase_config.dart';
import '../../shared/models/models.dart';

/// Legacy weighted daily score using fixed weights (Athletic 50 / Breaking 30
/// / Building 20). Empty sections redistribute their weight proportionally.
///
/// Kept for back-compat with callers that haven't been wired to phase weights
/// yet. New code should call [calculateDailyScoreV2].
double calculateDailyScore(List<Habit> scheduledHabits, List<HabitLog> logs) {
  return calculateDailyScoreV2(
    scheduledHabits: scheduledHabits,
    logs: logs,
    weights: const PhaseWeights(
      athletic: 0.50,
      breaking: 0.30,
      building: 0.20,
      nutrition: 0.0,
    ),
    nutritionPct: null,
  );
}

/// Phase-aware daily score.
///
/// - [weights] determines the relative contribution of each lens.
/// - [nutritionPct] is the user's calorie-hit ratio for today (0.0–1.0).
///   Pass `null` if you don't want nutrition to factor in (e.g. when food
///   data isn't loaded). When `null`, the nutrition weight is dropped and
///   the remaining weights are renormalised.
/// - Sections with zero scheduled habits drop their weight and the rest
///   renormalise, so the score never gets diluted by empty slots.
double calculateDailyScoreV2({
  required List<Habit> scheduledHabits,
  required List<HabitLog> logs,
  required PhaseWeights weights,
  required double? nutritionPct,
}) {
  final bySection = {
    for (final s in HabitSection.values)
      s: scheduledHabits.where((h) => h.section == s).toList(),
  };

  double sectionWeight(HabitSection s) => switch (s) {
        HabitSection.athletic => weights.athletic,
        HabitSection.body => weights.breaking,
        HabitSection.mind => weights.building,
      };

  final lensWeights = <String, double>{};
  final lensRates = <String, double>{};

  for (final s in HabitSection.values) {
    final habits = bySection[s]!;
    if (habits.isEmpty) continue;
    final done = habits
        .where((h) => logs.any((l) => l.habitId == h.id && l.completed))
        .length;
    lensWeights[s.name] = sectionWeight(s);
    lensRates[s.name] = done / habits.length;
  }

  if (nutritionPct != null && weights.nutrition > 0) {
    lensWeights['nutrition'] = weights.nutrition;
    lensRates['nutrition'] = nutritionPct.clamp(0.0, 1.0);
  }

  final total = lensWeights.values.fold(0.0, (a, b) => a + b);
  if (total == 0) return 0.0;

  double score = 0;
  for (final key in lensWeights.keys) {
    score += (lensWeights[key]! / total) * lensRates[key]!;
  }
  return score * 100;
}

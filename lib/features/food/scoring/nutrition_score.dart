/// Pure phase-aware nutrition adherence scoring.
///
/// No Riverpod, Supabase, or BuildContext dependencies. Mirrors the pure-
/// function pattern of `lib/features/home/scoring/score_engine.dart` so the
/// body section can blend nutrition adherence with habit completion using
/// the same `[0, kOvershootCap]` ratio semantics.
library;

import '../../home/scoring/score_engine.dart' show kOvershootCap;

/// User's current body-composition goal — drives the calorie adherence curve.
/// Maps from the existing `AppUser.bodyWeightGoal` string field.
enum BodyPhase { bulk, cut, maintain }

BodyPhase phaseFromGoalString(String? s) {
  switch ((s ?? 'maintain').toLowerCase()) {
    case 'gain':
    case 'bulk':
      return BodyPhase.bulk;
    case 'lose':
    case 'cut':
    case 'deficit':
      return BodyPhase.cut;
    default:
      return BodyPhase.maintain;
  }
}

/// Calorie adherence ratio in `[0, kOvershootCap]`, phase-aware.
///
/// - **bulk:** reward proportional to `current / target`. Caps at 1.10 above
///   target (matching the score engine's overshoot bonus). Below 80% of
///   target: ratio = (current/target) * 0.625 (so 0% intake → 0, 80% → 0.5).
/// - **cut:** full credit when at-or-under target. Linear penalty between
///   100% and 110% (1.0 → 0). Hard zero above 110%.
/// - **maintain:** bell curve centered on target. Within ±5% → 1.0. Falls
///   linearly to 0.5 at ±20%. Zero beyond ±35%.
double calorieAdherence({
  required double currentKcal,
  required double targetKcal,
  required BodyPhase phase,
}) {
  if (targetKcal <= 0) return 0.0;
  if (currentKcal < 0) currentKcal = 0;
  final r = currentKcal / targetKcal;

  switch (phase) {
    case BodyPhase.bulk:
      if (r >= kOvershootCap) return kOvershootCap;
      if (r >= 1.0) return r;
      if (r >= 0.8) return r;        // 0.8 → 0.8, 1.0 → 1.0 (linear)
      return r * 0.625;              // 0 → 0, 0.8 → 0.5 (steeper penalty)

    case BodyPhase.cut:
      if (r <= 1.0) return r >= 0.5 ? 1.0 : r * 2; // ≤target full; below 50% scaled
      if (r >= 1.10) return 0.0;
      return 1.0 - ((r - 1.0) / 0.10); // 1.00 → 1.0, 1.10 → 0

    case BodyPhase.maintain:
      final delta = (r - 1.0).abs();
      const eps = 1e-9; // FP safety on the boundary checks
      if (delta <= 0.05 + eps) return 1.0;
      if (delta >= 0.35 - eps) return 0.0;
      if (delta <= 0.20 + eps) {
        // 0.05 → 1.0, 0.20 → 0.5 (linear)
        return 1.0 - ((delta - 0.05) / 0.15) * 0.5;
      }
      // 0.20 → 0.5, 0.35 → 0 (linear)
      return 0.5 - ((delta - 0.20) / 0.15) * 0.5;
  }
}

/// Protein adherence in `[0, kOvershootCap]`. Easier curve than calories —
/// hitting 80% counts as a win; small overshoot rewarded up to 10%; capped.
double proteinAdherence({
  required double currentG,
  required double targetG,
}) {
  if (targetG <= 0) return 0.0;
  if (currentG < 0) currentG = 0;
  final r = currentG / targetG;
  if (r >= kOvershootCap) return kOvershootCap;
  if (r >= 0.8) return 1.0 + (r - 0.8) * 0.5; // 0.8 → 1.0, 1.0 → 1.1
  return r / 0.8;                              // 0 → 0, 0.8 → 1.0
}

const double _kCalorieWeight = 0.6;
const double _kProteinWeight = 0.4;

/// Combined nutrition day score (0..kOvershootCap). 60% calorie + 40% protein.
double nutritionDayScore({
  required double currentKcal,
  required double targetKcal,
  required double currentProteinG,
  required double targetProteinG,
  required BodyPhase phase,
}) {
  final cal = calorieAdherence(
    currentKcal: currentKcal,
    targetKcal: targetKcal,
    phase: phase,
  );
  final prot = proteinAdherence(
    currentG: currentProteinG,
    targetG: targetProteinG,
  );
  final blended = cal * _kCalorieWeight + prot * _kProteinWeight;
  if (blended < 0) return 0.0;
  if (blended > kOvershootCap) return kOvershootCap;
  return blended;
}

/// Threshold below which nutrition contributes no XP — prevents spam-logging
/// a single coffee from awarding XP. Mirrors `kMinRatioForXp` in score_engine.
const double kMinNutritionRatioForXp = 0.05;

/// Threshold above which the nutrition XP burst fires (once per day).
const double kNutritionXpThreshold = 0.80;

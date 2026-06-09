import 'food.dart';
import 'meal_entry.dart';
import 'targets.dart';

/// Pure health-score heuristics. Two surfaces:
///   - per-meal: from the raw entries in one slot
///   - per-day:  from full-day totals vs targets
///
/// Both return 0–100. Scoring bands map to a label + colour upstream:
///   ≥85 EXCELLENT, 70–84 WELL FUELED, 50–69 OK, <50 OFF TRACK
class HealthScore {
  final int value;
  final String label;
  const HealthScore(this.value, this.label);

  static const empty = HealthScore(0, '—');

  static String labelFor(int v) {
    if (v >= 85) return 'EXCELLENT';
    if (v >= 70) return 'WELL FUELED';
    if (v >= 50) return 'OK';
    return 'OFF TRACK';
  }
}

/// Score a single meal's nutrition. Heuristic, not clinical:
///   + protein density (g per 100 kcal): athlete-tuned, peak at 10 g/100kcal
///   + fiber presence: +bonus if any fiber per 100 kcal
///   - saturated fat: penalty above 5 g
///   - sugar: penalty above 15 g
///   - sodium: penalty above 800 mg per meal
HealthScore mealHealthScore(List<MealEntry> entries) {
  if (entries.isEmpty) return HealthScore.empty;
  double kcal = 0, protein = 0, fiber = 0, satFat = 0, sugar = 0, sodium = 0;
  for (final e in entries) {
    kcal    += e.totals.kcal;
    protein += e.totals.proteinG;
    fiber   += e.totals.fiberG;
    satFat  += e.totals.satFatG;
    sugar   += e.totals.sugarG;
    sodium  += e.totals.sodiumMg;
  }
  if (kcal <= 0) return HealthScore.empty;

  // Start from 70, push up or down.
  double score = 70;

  final proteinPer100 = protein * 100 / kcal;
  score += ((proteinPer100 / 10).clamp(0, 1)) * 20; // up to +20 for protein density
  if (fiber > 0) score += (fiber / 8).clamp(0, 1) * 10; // up to +10 fiber

  if (satFat > 5)    score -= (satFat - 5).clamp(0, 15) * 1.5;
  if (sugar > 15)    score -= (sugar - 15).clamp(0, 25) * 0.6;
  if (sodium > 800)  score -= ((sodium - 800) / 100).clamp(0, 12) * 1.2;

  final v = score.clamp(0, 100).round();
  return HealthScore(v, HealthScore.labelFor(v));
}

/// Score a full day vs targets. Five components, weighted:
///   - calorie adherence (±15% of target) — 30 pts
///   - protein adherence (≥90% of target) — 25 pts
///   - fiber adherence (≥80% of target)   — 15 pts
///   - sat-fat / sugar / sodium under upper bound — 20 pts
///   - distribution: at least 3 meal slots logged — 10 pts
HealthScore dayHealthScore(
  Nutrients totals,
  DailyTargets targets, {
  int loggedSlotCount = 0,
}) {
  if (totals.kcal <= 0 && loggedSlotCount == 0) return HealthScore.empty;

  double s = 0;

  // Calories: peak inside ±15%, zero outside ±40%.
  if (targets.kcal > 0) {
    final ratio = totals.kcal / targets.kcal;
    final dev = (ratio - 1).abs();
    if (dev <= 0.15) {
      s += 30;
    } else if (dev <= 0.40) {
      s += 30 * (1 - (dev - 0.15) / 0.25);
    }
  }

  if (targets.proteinG > 0) {
    final r = (totals.proteinG / targets.proteinG).clamp(0, 1.2);
    s += (r / 0.9).clamp(0, 1) * 25;
  }

  if (targets.micros.fiberG > 0) {
    final r = (totals.fiberG / targets.micros.fiberG).clamp(0, 1.2);
    s += (r / 0.8).clamp(0, 1) * 15;
  }

  // Upper bounds — 20 pts total split across satFat, sugar, sodium.
  double upper = 0;
  if (targets.micros.satFatG > 0 && totals.satFatG <= targets.micros.satFatG) upper += 7;
  if (targets.micros.sugarG  > 0 && totals.sugarG  <= targets.micros.sugarG)  upper += 6;
  if (targets.micros.sodiumMg > 0 && totals.sodiumMg <= targets.micros.sodiumMg) upper += 7;
  s += upper;

  if (loggedSlotCount >= 3) {
    s += 10;
  } else if (loggedSlotCount > 0) {
    s += loggedSlotCount * 3.0;
  }

  final v = s.clamp(0, 100).round();
  return HealthScore(v, HealthScore.labelFor(v));
}

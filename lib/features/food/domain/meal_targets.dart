import '../../../shared/models/models.dart';
import 'meal_plan.dart';
import 'targets.dart';

/// Per-meal target for a single slot — calories **and** macros, so a meal's
/// goals tell the same story as the day. `kcal == null` marks a disabled meal
/// (not part of the schedule).
class MealMacroTargets {
  final int? kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  const MealMacroTargets({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });

  bool get hasGoal => kcal != null;
  bool get hasMacros => proteinG > 0 || carbsG > 0 || fatG > 0;
}

/// Per-meal calorie goals from the user's [MealPlan]: enabled meals get their
/// resolved calories (Fixed or Auto-share), disabled meals resolve to `null`.
Map<MealTimeSlot, int?> resolveMealTargets({
  required int dailyKcal,
  required MealPlan plan,
}) {
  final kcalBySlot = plan.resolveKcal(dailyKcal);
  return {for (final s in MealTimeSlot.values) s: kcalBySlot[s]};
}

/// Full per-meal targets — calories + every macro. Macros are distributed
/// across the enabled meals in proportion to each meal's calorie share, so a
/// meal's macros track its calories and the per-meal sums equal the day exactly.
Map<MealTimeSlot, MealMacroTargets> resolveMealMacroTargets({
  required DailyTargets daily,
  required MealPlan plan,
}) {
  final kcalBySlot = plan.resolveKcal(daily.kcal.round());
  final weights = <MealTimeSlot, double>{
    for (final e in kcalBySlot.entries) e.key: e.value.toDouble(),
  };
  final p = distributeByWeight(daily.proteinG.round(), weights);
  final cb = distributeByWeight(daily.carbsG.round(), weights);
  final ft = distributeByWeight(daily.fatG.round(), weights);
  final fb = distributeByWeight(daily.micros.fiberG.round(), weights);
  return {
    for (final slot in MealTimeSlot.values)
      slot: MealMacroTargets(
        kcal: kcalBySlot[slot],
        proteinG: p[slot] ?? 0,
        carbsG: cb[slot] ?? 0,
        fatG: ft[slot] ?? 0,
        fiberG: fb[slot] ?? 0,
      ),
  };
}

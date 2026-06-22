import '../../../shared/models/models.dart';
import 'meal_entry.dart';

/// Default share of the daily calorie target each meal slot carries when the
/// user hasn't set a manual per-meal goal. Main meals split the day; the two
/// workout slots are optional (no fixed goal — they show `X kcal`, no `of Y`).
const _defaultMealWeights = <MealTimeSlot, double>{
  MealTimeSlot.breakfast: 0.25,
  MealTimeSlot.lunch: 0.30,
  MealTimeSlot.dinner: 0.30,
  MealTimeSlot.snack: 0.15,
  MealTimeSlot.preWorkout: 0, // optional → null target
  MealTimeSlot.postWorkout: 0, // optional → null target
};

/// Resolve the per-meal calorie goals shown on the diary.
///
/// A manual [overrides] value (keyed by slot `dbValue`) wins for that slot;
/// otherwise the slot falls back to `weight × dailyKcal` rounded to the nearest
/// 10. Slots with a zero default weight and no override resolve to `null`,
/// which the UI renders as `X kcal` (no `of Y`).
Map<MealTimeSlot, int?> resolveMealTargets({
  required int dailyKcal,
  Map<String, dynamic>? overrides,
}) {
  final out = <MealTimeSlot, int?>{};
  for (final slot in MealTimeSlot.values) {
    final override = _readOverride(overrides, slot);
    if (override != null) {
      out[slot] = override;
      continue;
    }
    final weight = _defaultMealWeights[slot] ?? 0;
    out[slot] = weight <= 0 ? null : _roundTo10(weight * dailyKcal);
  }
  return out;
}

/// The auto-split value for a slot, ignoring any manual override — used to
/// pre-fill the per-meal fields in the goals editor.
int autoSplitFor(MealTimeSlot slot, int dailyKcal) {
  final weight = _defaultMealWeights[slot] ?? 0;
  return weight <= 0 ? 0 : _roundTo10(weight * dailyKcal);
}

int? _readOverride(Map<String, dynamic>? overrides, MealTimeSlot slot) {
  if (overrides == null) return null;
  final raw = overrides[slot.dbValue];
  if (raw is num) {
    final v = raw.toInt();
    return v > 0 ? v : null;
  }
  return null;
}

int _roundTo10(double v) => (v / 10).round() * 10;

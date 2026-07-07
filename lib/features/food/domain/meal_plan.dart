import 'dart:math' as math;
import '../../../shared/models/models.dart';
import 'meal_entry.dart';

/// Default % share of the daily calorie goal a slot takes when it's enabled and
/// on Auto. Used to split whatever calories aren't pinned to a Fixed meal.
const Map<MealTimeSlot, double> kSlotShare = {
  MealTimeSlot.breakfast: 0.25,
  MealTimeSlot.lunch: 0.30,
  MealTimeSlot.dinner: 0.30,
  MealTimeSlot.snack: 0.15,
  MealTimeSlot.preWorkout: 0.10,
  MealTimeSlot.postWorkout: 0.10,
};

/// One meal in the user's daily schedule. Calories are either Auto (a share of
/// the daily goal, `fixedKcal == null`) or Fixed.
class MealPlanEntry {
  final MealTimeSlot slot;
  final bool enabled;
  final String? customName;
  final int? fixedKcal;
  final String? time; // "HH:mm" or null (no reminder)

  const MealPlanEntry({
    required this.slot,
    required this.enabled,
    this.customName,
    this.fixedKcal,
    this.time,
  });

  String get name => (customName != null && customName!.trim().isNotEmpty)
      ? customName!.trim()
      : slot.label;

  bool get isAuto => fixedKcal == null;

  MealPlanEntry copyWith({
    bool? enabled,
    String? customName,
    bool clearName = false,
    int? fixedKcal,
    bool clearFixed = false,
    String? time,
    bool clearTime = false,
  }) =>
      MealPlanEntry(
        slot: slot,
        enabled: enabled ?? this.enabled,
        customName: clearName ? null : (customName ?? this.customName),
        fixedKcal: clearFixed ? null : (fixedKcal ?? this.fixedKcal),
        time: clearTime ? null : (time ?? this.time),
      );
}

/// The user's full daily meal schedule (all six slots, configurable).
///
/// Single source for which meals exist, their names, calorie targets and
/// on/off. Times are mirrored from the notification meal-reminder prefs so a
/// meal's time and its reminder are the same thing.
class MealPlan {
  final Map<MealTimeSlot, MealPlanEntry> entries;
  const MealPlan(this.entries);

  List<MealPlanEntry> get ordered =>
      [for (final s in kDiarySlotOrder) entries[s]!];

  List<MealPlanEntry> get enabledMeals =>
      ordered.where((e) => e.enabled).toList();

  MealPlanEntry forSlot(MealTimeSlot s) => entries[s]!;

  MealPlan withEntry(MealPlanEntry e) =>
      MealPlan({...entries, e.slot: e});

  /// Which slots are enabled by default for a body goal. Cutting keeps it
  /// tight (3 meals); bulking spreads calories across more meals.
  static Set<MealTimeSlot> enabledSlotsForGoal(String goal) =>
      switch (goal.toLowerCase()) {
        'lose' => {
            MealTimeSlot.breakfast,
            MealTimeSlot.lunch,
            MealTimeSlot.dinner,
          },
        'gain' => {
            MealTimeSlot.breakfast,
            MealTimeSlot.snack,
            MealTimeSlot.lunch,
            MealTimeSlot.postWorkout,
            MealTimeSlot.dinner,
          },
        _ => {
            MealTimeSlot.breakfast,
            MealTimeSlot.lunch,
            MealTimeSlot.snack,
            MealTimeSlot.dinner,
          },
      };

  /// A fresh plan seeded from a body goal — all Auto, default reminder times
  /// for the main meals.
  factory MealPlan.forGoal(String goal, {Map<MealTimeSlot, String?>? times}) {
    final on = enabledSlotsForGoal(goal);
    return MealPlan({
      for (final s in MealTimeSlot.values)
        s: MealPlanEntry(
          slot: s,
          enabled: on.contains(s),
          time: times?[s] ?? _defaultTime(s),
        ),
    });
  }

  static String? _defaultTime(MealTimeSlot s) => switch (s) {
        MealTimeSlot.breakfast => '08:00',
        MealTimeSlot.lunch => '13:00',
        MealTimeSlot.dinner => '20:00',
        _ => null,
      };

  /// Parse the stored plan. [mealTargets] is the `meal_calorie_targets` blob,
  /// which may be the legacy `{slot: kcal}` shape or the richer
  /// `{slot: {on, name, kcal}}` shape. [times] comes from notification prefs.
  factory MealPlan.fromStorage({
    Map<String, dynamic>? mealTargets,
    Map<MealTimeSlot, String?>? times,
    required String goal,
  }) {
    // No stored plan at all → goal defaults.
    if (mealTargets == null || mealTargets.isEmpty) {
      return MealPlan.forGoal(goal, times: times);
    }
    final defaultsOn = enabledSlotsForGoal(goal);
    return MealPlan({
      for (final s in MealTimeSlot.values)
        s: _entryFromRaw(s, mealTargets[s.dbValue], times?[s], defaultsOn.contains(s)),
    });
  }

  static MealPlanEntry _entryFromRaw(
      MealTimeSlot slot, dynamic raw, String? time, bool defaultOn) {
    if (raw is num) {
      // Legacy: a bare kcal value means an enabled, fixed meal.
      final v = raw.toInt();
      return MealPlanEntry(
          slot: slot, enabled: v > 0, fixedKcal: v > 0 ? v : null, time: time);
    }
    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      final kcal = (m['kcal'] as num?)?.toInt();
      return MealPlanEntry(
        slot: slot,
        enabled: m['on'] as bool? ?? true,
        customName: (m['name'] as String?)?.trim().isNotEmpty == true
            ? (m['name'] as String).trim()
            : null,
        fixedKcal: (kcal != null && kcal > 0) ? kcal : null,
        time: time,
      );
    }
    // No entry for this slot → fall back to the goal default on/off, Auto.
    return MealPlanEntry(slot: slot, enabled: defaultOn, time: time);
  }

  /// Serialize to the `meal_calorie_targets` blob (names + on/off + fixed kcal).
  /// Times are persisted separately via the notification meal prefs.
  Map<String, dynamic> toMealTargetsJson() => {
        for (final e in ordered)
          e.slot.dbValue: {
            'on': e.enabled,
            if (e.customName != null && e.customName!.trim().isNotEmpty)
              'name': e.customName!.trim(),
            if (e.fixedKcal != null && e.fixedKcal! > 0) 'kcal': e.fixedKcal,
          },
      };

  /// Resolve calories per **enabled** meal for [dailyGoal]: Fixed meals keep
  /// their value; Auto meals split whatever's left, by share, summing exactly.
  Map<MealTimeSlot, int> resolveKcal(int dailyGoal) {
    final en = enabledMeals;
    final fixedSum =
        en.where((e) => !e.isAuto).fold<int>(0, (a, e) => a + e.fixedKcal!);
    final remainder = math.max(0, dailyGoal - fixedSum);
    final autos = en.where((e) => e.isAuto).toList();
    final shares = {for (final e in autos) e.slot: kSlotShare[e.slot] ?? 0.15};
    final autoKcal = distributeByWeight(remainder, shares);
    return {
      for (final e in en)
        e.slot: e.isAuto ? (autoKcal[e.slot] ?? 0) : e.fixedKcal!,
    };
  }

  /// Total calories the plan assigns for [dailyGoal] (Auto fill the rest, so
  /// this equals the goal unless Fixed meals already exceed it).
  int assignedTotal(int dailyGoal) {
    final en = enabledMeals;
    final fixedSum =
        en.where((e) => !e.isAuto).fold<int>(0, (a, e) => a + e.fixedKcal!);
    final hasAuto = en.any((e) => e.isAuto);
    // Auto meals absorb the remainder, so the total is the goal (clamped up to
    // the fixed sum when fixed already overshoots).
    return hasAuto ? math.max(dailyGoal, fixedSum) : fixedSum;
  }
}

/// Distribute an integer [total] across [weights] so the parts are proportional
/// and sum back to [total] exactly (largest-remainder / Hamilton). Zero/absent
/// weights get 0. Generic so the meal split and macro split share one method.
Map<T, int> distributeByWeight<T>(int total, Map<T, double> weights) {
  final sumW = weights.values.fold<double>(0, (a, b) => a + b);
  if (sumW <= 0 || total <= 0) {
    return {for (final k in weights.keys) k: 0};
  }
  final exact = <T, double>{
    for (final e in weights.entries) e.key: total * e.value / sumW,
  };
  final parts = <T, int>{
    for (final e in exact.entries) e.key: e.value.floor(),
  };
  var remaining = total - parts.values.fold<int>(0, (a, b) => a + b);
  final order = exact.keys.where((k) => (weights[k] ?? 0) > 0).toList()
    ..sort((a, b) => (exact[b]! - parts[b]!).compareTo(exact[a]! - parts[a]!));
  for (final k in order) {
    if (remaining <= 0) break;
    parts[k] = parts[k]! + 1;
    remaining--;
  }
  return parts;
}

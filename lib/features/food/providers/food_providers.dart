import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dev/dev_mode.dart';
import '../../../shared/providers/today_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/models.dart';
import '../data/food_repository.dart';
import '../data/meal_bundle_repository.dart';
import '../domain/food.dart';
import '../domain/meal_bundle.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_targets.dart';
import '../domain/nutrition_engine.dart';
import '../domain/targets.dart';
import '../scoring/nutrition_score.dart';
import '../../notifications/providers/notification_prefs_provider.dart';

final foodRepositoryProvider = Provider<FoodRepository>((_) => FoodRepository());

/// Liters from ml, shown accurately (no misleading rounding): 250→"0.25",
/// 500→"0.5", 1000→"1", 1250→"1.25", 3500→"3.5".
String fmtLiters(int ml) {
  var s = (ml / 1000.0).toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// Currently-viewed diary date. Date-only (no time component).
final diaryDateProvider = StateProvider<DateTime>((_) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

/// All entries for the selected date. In dev mode, returns a realistic
/// bulking-day diary at ~75% of target so the UI demos with non-zero values.
final diaryEntriesProvider = FutureProvider.autoDispose<List<MealEntry>>((ref) async {
  final date = ref.watch(diaryDateProvider);
  if (ref.watch(devModeProvider)) return generateMockFoodEntries(date);
  final repo = ref.watch(foodRepositoryProvider);
  return repo.entriesForDate(date);
});

/// Totals for the day — kcal + macros + micros.
final diaryTotalsProvider = Provider.autoDispose<Nutrients>((ref) {
  final entries = ref.watch(diaryEntriesProvider).valueOrNull ?? const <MealEntry>[];
  return entries.fold<Nutrients>(Nutrients.zero, (acc, e) => acc + e.totals);
});

/// Daily targets derived from the user profile.
// ── Nutrition engine wiring (profile → live, correlated targets) ─────
// Profile→enum mappers + default-target helper live in the engine
// (domain) so onboarding, the goal screen, and this provider all agree.

/// Default timeline (days) to reach [targetKg] at a sustainable pace (loss
/// 0.5%/wk, gain 0.25%/wk) — used until an explicit timeline is captured.
int _defaultDurationDays(double currentKg, double targetKg) {
  final delta = (targetKg - currentKg).abs();
  if (delta < 0.5 || currentKg <= 0) return 0; // maintain
  final ratePerWeek = (targetKg > currentKg ? 0.0025 : 0.005) * currentKg;
  if (ratePerWeek <= 0) return 0;
  return (delta / ratePerWeek * 7).round().clamp(14, 730);
}

/// Engine plan from the profile, or null when it lacks the required stats.
/// Honours stored `nutrition_prefs` (timeline, macro presets/custom values,
/// manual kcal override) over the goal-derived defaults.
NutritionPlan? nutritionPlanForUser(AppUser u) {
  final h = u.heightCm, w = u.weightKg, age = u.age;
  if (h == null || w == null || age == null || h <= 0 || w <= 0) return null;
  final target = (u.targetBodyWeight != null && u.targetBodyWeight! > 0)
      ? u.targetBodyWeight!
      : defaultTargetKg(w, u.bodyWeightGoal);

  final prefs = u.nutritionPrefsRaw;
  // Pace source of truth: the signed weekly rate captured from the slider.
  // Legacy profiles only stored a timeline — fall back to that (then to a
  // sustainable default) so their targets stay stable until they re-save.
  final weeklyRate = u.weeklyRateKg;
  final storedTimeline = u.timelineDays;
  final duration = (storedTimeline != null && storedTimeline > 0)
      ? storedTimeline
      : _defaultDurationDays(w, target);

  final proteinPlan = proteinPlanFromName(prefs?['protein_plan'] as String?) ??
      proteinPlanForGoalKey(u.bodyWeightGoal);
  final fatPlan = fatPlanFromName(prefs?['fat_plan'] as String?) ?? FatPlan.balanced;
  final proteinPerKg = proteinPlan == ProteinPlan.custom
      ? (prefs?['protein_per_kg'] as num?)?.toDouble()
      : null;
  final fatPct =
      fatPlan == FatPlan.custom ? (prefs?['fat_pct'] as num?)?.toDouble() : null;

  return NutritionEngine.compute(
    sex: bioSexFromKey(u.gender),
    age: age,
    heightCm: h,
    currentKg: w,
    targetKg: target,
    activity: activityFromKey(u.activityLevel),
    durationDays: duration,
    weeklyRateKgOverride: weeklyRate,
    proteinPlan: proteinPlan,
    proteinPerKgOverride: proteinPerKg,
    fatPlan: fatPlan,
    fatPctOverride: fatPct,
    kcalOverride: u.kcalOverride,
  );
}

/// Daily targets — computed live by the [NutritionEngine] from the profile so
/// macros + micros stay correlated (protein tracks bodyweight, carbs flex with
/// calories, micros are demographic). Falls back to the legacy stored-target
/// split when the profile lacks the engine's required stats.
final dailyTargetsProvider = Provider.autoDispose<DailyTargets>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user != null) {
    final plan = nutritionPlanForUser(user);
    if (plan != null) return DailyTargets.fromPlan(plan);
  }
  return DailyTargets.fromProfile(
    kcalTarget: user?.dailyCalorieTarget ?? 3000,
    proteinTarget: user?.dailyProteinTarget ?? 180,
    carbsTarget: user?.dailyCarbsTarget,
    fatTarget: user?.dailyFatTarget,
    fiberTarget: user?.dailyFiberTarget,
    bodyWeightKg: user?.weightKg ?? user?.targetBodyWeight,
  );
});

/// Per-meal calorie goals shown in the diary headers and the meal picker.
/// Calories come from the live [dailyTargetsProvider] (engine-correlated, not
/// the stale stored value); manual overrides win per slot. A `null` value means
/// a disabled meal (not on the schedule).
final mealTargetsProvider = Provider.autoDispose<Map<MealTimeSlot, int?>>((ref) {
  final daily = ref.watch(dailyTargetsProvider);
  return resolveMealTargets(
    dailyKcal: daily.kcal.round(),
    plan: ref.watch(mealPlanProvider),
  );
});

/// Full per-meal targets — calories **and** every macro, each distributed so
/// the per-meal values sum to the daily total exactly (largest-remainder).
/// Drives the per-meal macro goals shown in the diary headers and picker.
final mealMacroTargetsProvider =
    Provider.autoDispose<Map<MealTimeSlot, MealMacroTargets>>((ref) {
  final daily = ref.watch(dailyTargetsProvider);
  return resolveMealMacroTargets(
    daily: daily,
    plan: ref.watch(mealPlanProvider),
  );
});

/// The user's daily meal schedule — single source for which meals exist, their
/// names, on/off and calorie mode. Names + on/off + fixed kcal come from
/// `meal_calorie_targets`; reminder times from the notification prefs; the goal
/// seeds sensible defaults.
final mealPlanProvider = Provider.autoDispose<MealPlan>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  final times = ref.watch(notificationPrefsProvider).meals.slots;
  return MealPlan.fromStorage(
    mealTargets: user?.mealCalorieTargetsJson,
    times: times,
    goal: user?.bodyWeightGoal ?? 'maintain',
  );
});

/// Active food-search query (debounced in the UI).
final foodSearchQueryProvider = StateProvider<String>((_) => '');

/// The user's frequently-logged foods (last 90 days, with counts), cached for
/// the session. Drives personalised search ranking. Empty in dev mode.
final frequentFoodsProvider =
    FutureProvider.autoDispose<List<FrequentFood>>((ref) async {
  if (ref.watch(devModeProvider)) return const [];
  final repo = ref.watch(foodRepositoryProvider);
  try {
    return await repo.frequentFoods();
  } catch (_) {
    return const [];
  }
});

/// Primary search results — instant: catalog + the user's own foods,
/// personalised so frequently-logged matches pin to the top. A plain
/// FutureProvider (stable across hot reloads); branded OFF results load
/// separately via [brandedSearchResultsProvider] and are appended in the UI.
final foodSearchResultsProvider =
    FutureProvider.autoDispose<List<Food>>((ref) async {
  final q = ref.watch(foodSearchQueryProvider);
  if (q.trim().length < 2) return const [];
  // Debounce: 180 ms of stability before touching the network.
  await Future<void>.delayed(const Duration(milliseconds: 180));
  if (q != ref.read(foodSearchQueryProvider)) return const [];

  final repo = ref.watch(foodRepositoryProvider);
  final frequents = await ref.watch(frequentFoodsProvider.future);
  List<Food> core;
  try {
    core = await repo.searchCatalog(q);
  } catch (e, s) {
    if (kDebugMode) debugPrint('search error: $e\n$s');
    core = const [];
  }
  return _personalise(q, frequents, core);
});

/// Branded / packaged items from Open Food Facts — slower, loaded on its own
/// so it never blocks the primary results; the UI appends these underneath.
final brandedSearchResultsProvider =
    FutureProvider.autoDispose<List<Food>>((ref) async {
  final q = ref.watch(foodSearchQueryProvider);
  if (q.trim().length < 2) return const [];
  await Future<void>.delayed(const Duration(milliseconds: 240));
  if (q != ref.read(foodSearchQueryProvider)) return const [];
  final repo = ref.watch(foodRepositoryProvider);
  try {
    return await repo.searchBranded(q);
  } catch (_) {
    return const [];
  }
});

/// Pins the user's frequently-logged foods that match [q] to the top
/// (most-logged first), ahead of the generic catalog results.
List<Food> _personalise(String q, List<FrequentFood> frequents, List<Food> core) {
  if (frequents.isEmpty) return core;
  final nq = q.toLowerCase().trim();
  final tokens = nq.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
  final pinned = frequents.where((fr) {
    final n = fr.food.name.toLowerCase();
    return n.contains(nq) || tokens.any(n.contains);
  }).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  if (pinned.isEmpty) return core;
  return _mergeDedup([...pinned.map((p) => p.food), ...core]);
}

List<Food> _mergeDedup(List<Food> foods) {
  final seen = <String>{};
  final out = <Food>[];
  for (final f in foods) {
    if (seen.add('${f.brand ?? ''}|${f.name.toLowerCase()}')) out.add(f);
  }
  return out;
}

final recentFoodsProvider = FutureProvider.autoDispose<List<Food>>((ref) async {
  final repo = ref.watch(foodRepositoryProvider);
  return repo.recents();
});

final favoriteFoodsProvider = FutureProvider.autoDispose<List<Food>>((ref) async {
  final repo = ref.watch(foodRepositoryProvider);
  return repo.favorites();
});

/// Saved meal bundles ("My Meals") — named combos that log in one tap.
final mealBundleRepositoryProvider =
    Provider<MealBundleRepository>((_) => MealBundleRepository());

final savedMealBundlesProvider =
    FutureProvider.autoDispose<List<MealBundle>>((ref) async {
  final repo = ref.watch(mealBundleRepositoryProvider);
  return repo.list();
});

/// Demo-only in-memory water total (ml). Dev mode has no Supabase session to
/// persist to, so the centralized [addWaterIntake]/[removeWaterIntake] actions
/// mutate this instead and [waterIntakeProvider] serves it.
final devWaterMlProvider = StateProvider<int>((_) => 0);

/// Water intake for the current diary date (ml).
final waterIntakeProvider = FutureProvider.autoDispose<int>((ref) async {
  if (ref.watch(devModeProvider)) return ref.watch(devWaterMlProvider);
  final date = ref.watch(diaryDateProvider);
  final repo = ref.watch(foodRepositoryProvider);
  return repo.waterForDate(date);
});

/// Single entry point for adding water, so dev-mode, persistence, and the
/// read-provider refresh are handled in ONE place (every call site goes through
/// here). [ml] should be > 0.
Future<void> addWaterIntake(WidgetRef ref, int ml) async {
  if (ref.read(devModeProvider)) {
    ref.read(devWaterMlProvider.notifier).update((v) => v + ml);
    return; // read provider watches devWaterMlProvider → UI updates
  }
  final repo = ref.read(foodRepositoryProvider);
  final date = ref.read(diaryDateProvider);
  await repo.addWater(ml, date);
  ref.invalidate(waterIntakeProvider);
}

/// Removes the most recent water entry (≈250 ml) for the current mode.
Future<void> removeWaterIntake(WidgetRef ref) async {
  if (ref.read(devModeProvider)) {
    ref.read(devWaterMlProvider.notifier).update((v) => (v - 250).clamp(0, 1 << 30));
    return;
  }
  final repo = ref.read(foodRepositoryProvider);
  final date = ref.read(diaryDateProvider);
  await repo.removeLastWater(date);
  ref.invalidate(waterIntakeProvider);
}

/// Water target — computed live by the engine (so it tracks weight + activity
/// like every other target), falling back to the stored column then a default
/// when the profile lacks the engine's required stats.
final waterTargetProvider = Provider.autoDispose<int>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  // A manual water goal wins over the engine recommendation.
  final override = user?.waterOverrideMl;
  if (override != null && override > 0) return override;
  final plan = user == null ? null : nutritionPlanForUser(user);
  return plan?.waterMl ?? user?.waterTargetMl ?? 3500;
});

/// Current body-composition phase, derived from the user's stored goal.
final bodyPhaseProvider = Provider<BodyPhase>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return phaseFromGoalString(user?.bodyWeightGoal);
});

/// Today's nutrition adherence ratio in `[0, kOvershootCap]`. Phase-aware:
/// rewards a calorie surplus when bulking, a deficit when cutting, and
/// proximity to target when maintaining. Protein is a separate weighted
/// component (60 % cal / 40 % protein). Drives the body-section blend in
/// `homeScoreProvider` and the nutrition XP trigger.
final nutritionRatioProvider = Provider<double>((ref) {
  final totals = ref.watch(diaryTotalsProvider);
  final targets = ref.watch(dailyTargetsProvider);
  final phase = ref.watch(bodyPhaseProvider);
  return nutritionDayScore(
    currentKcal: totals.kcal,
    targetKcal: targets.kcal,
    currentProteinG: totals.proteinG,
    targetProteinG: targets.proteinG,
    phase: phase,
  );
});

/// Today's entries, fetched independently of the diary's selected date. Only
/// consulted when the diary is browsing another day — see
/// [todayNutritionRatioProvider].
final _todayEntriesProvider =
    FutureProvider.autoDispose<List<MealEntry>>((ref) async {
  final today = ref.watch(todayDateProvider);
  if (ref.watch(devModeProvider)) return generateMockFoodEntries(today);
  final repo = ref.watch(foodRepositoryProvider);
  return repo.entriesForDate(today);
});

/// Nutrition adherence for *today*, regardless of which date the food diary
/// is currently browsing. This is what the home score blend, the nutrition
/// XP listener, and milestone derivations must read — [nutritionRatioProvider]
/// follows [diaryDateProvider] and would leak a browsed past date into
/// today's score.
///
/// When the diary *is* on today it delegates to [nutritionRatioProvider], so
/// every existing `ref.invalidate(diaryEntriesProvider)` after a food log
/// keeps the ratio live. While browsing another date no entry can be added
/// to today, so the independent fetch can't go stale.
final todayNutritionRatioProvider = Provider<double>((ref) {
  if (ref.watch(diaryDateProvider) == ref.watch(todayDateProvider)) {
    return ref.watch(nutritionRatioProvider);
  }
  final entries =
      ref.watch(_todayEntriesProvider).valueOrNull ?? const <MealEntry>[];
  final totals =
      entries.fold<Nutrients>(Nutrients.zero, (acc, e) => acc + e.totals);
  final targets = ref.watch(dailyTargetsProvider);
  final phase = ref.watch(bodyPhaseProvider);
  return nutritionDayScore(
    currentKcal: totals.kcal,
    targetKcal: targets.kcal,
    currentProteinG: totals.proteinG,
    targetProteinG: targets.proteinG,
    phase: phase,
  );
});

/// Nutrition adherence ratio for an *arbitrary* past [date] — keyed by an
/// explicit date, so (unlike [nutritionRatioProvider]) it never leaks the
/// diary's browsed date into another day's score. Powers the body-section
/// blend in `homeScoreProvider` for time-travel; today must keep using
/// [todayNutritionRatioProvider] (live + invalidation-wired). 0.0 when nothing
/// was logged, matching the snapshot writer's `_nutritionRatioFor`.
/// Nutrition adherence ratio for every day in the last [days] days, from a
/// SINGLE range query (vs the per-date [nutritionRatioForDateProvider] N+1).
/// Powers the stats score series. Key = date-only midnight; a day with no food
/// logged is simply absent (treat as 0.0).
final nutritionRatiosForRangeProvider =
    FutureProvider.autoDispose.family<Map<DateTime, double>, int>((ref, days) async {
  final targets = ref.watch(dailyTargetsProvider);
  final phase = ref.watch(bodyPhaseProvider);
  final today = ref.watch(todayDateProvider);
  final start = today.subtract(Duration(days: days - 1));

  Map<DateTime, List<MealEntry>> byDate;
  if (ref.watch(devModeProvider)) {
    byDate = {
      for (int i = 0; i < days; i++)
        DateTime(today.year, today.month, today.day - i):
            generateMockFoodEntries(DateTime(today.year, today.month, today.day - i)),
    };
  } else {
    byDate = await ref.watch(foodRepositoryProvider).entriesForRange(start, today);
  }

  final out = <DateTime, double>{};
  byDate.forEach((d, entries) {
    if (entries.isEmpty) return;
    final totals = entries.fold<Nutrients>(Nutrients.zero, (a, e) => a + e.totals);
    out[DateTime(d.year, d.month, d.day)] = nutritionDayScore(
      currentKcal: totals.kcal,
      targetKcal: targets.kcal,
      currentProteinG: totals.proteinG,
      targetProteinG: targets.proteinG,
      phase: phase,
    );
  });
  return out;
});

final nutritionRatioForDateProvider =
    FutureProvider.autoDispose.family<double, DateTime>((ref, date) async {
  final targets = ref.watch(dailyTargetsProvider);
  final phase = ref.watch(bodyPhaseProvider);
  List<MealEntry> entries;
  if (ref.watch(devModeProvider)) {
    entries = generateMockFoodEntries(date);
  } else {
    final repo = ref.watch(foodRepositoryProvider);
    entries = await repo.entriesForDate(date);
  }
  if (entries.isEmpty) return 0.0;
  final totals =
      entries.fold<Nutrients>(Nutrients.zero, (acc, e) => acc + e.totals);
  return nutritionDayScore(
    currentKcal: totals.kcal,
    targetKcal: targets.kcal,
    currentProteinG: totals.proteinG,
    targetProteinG: targets.proteinG,
    phase: phase,
  );
});

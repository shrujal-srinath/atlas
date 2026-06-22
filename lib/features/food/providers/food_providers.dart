import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dev/dev_mode.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/models/models.dart';
import '../data/food_repository.dart';
import '../data/meal_bundle_repository.dart';
import '../domain/food.dart';
import '../domain/meal_bundle.dart';
import '../domain/meal_entry.dart';
import '../domain/meal_targets.dart';
import '../domain/targets.dart';
import '../scoring/nutrition_score.dart';

final foodRepositoryProvider = Provider<FoodRepository>((_) => FoodRepository());

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
final dailyTargetsProvider = Provider.autoDispose<DailyTargets>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
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
/// Manual overrides (from the goals screen) win per slot; everything else
/// falls back to an auto-split of the daily calorie target. A `null` value
/// means "no fixed goal" (the optional workout slots) — render as `X kcal`.
final mealTargetsProvider = Provider.autoDispose<Map<MealTimeSlot, int?>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return resolveMealTargets(
    dailyKcal: user?.dailyCalorieTarget ?? 3000,
    overrides: user?.mealCalorieTargetsJson,
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

/// Water intake for the current diary date (ml).
final waterIntakeProvider = FutureProvider.autoDispose<int>((ref) async {
  final date = ref.watch(diaryDateProvider);
  final repo = ref.watch(foodRepositoryProvider);
  return repo.waterForDate(date);
});

/// Water target from user profile.
final waterTargetProvider = Provider.autoDispose<int>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return user?.waterTargetMl ?? 3500;
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

DateTime _todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Today's entries, fetched independently of the diary's selected date. Only
/// consulted when the diary is browsing another day — see
/// [todayNutritionRatioProvider].
final _todayEntriesProvider =
    FutureProvider.autoDispose<List<MealEntry>>((ref) async {
  final today = _todayDate();
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
  if (ref.watch(diaryDateProvider) == _todayDate()) {
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

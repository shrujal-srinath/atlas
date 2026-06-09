import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dev/dev_mode.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/food_repository.dart';
import '../domain/food.dart';
import '../domain/meal_entry.dart';
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

/// Active food-search query (debounced in the UI).
final foodSearchQueryProvider = StateProvider<String>((_) => '');

final foodSearchResultsProvider = FutureProvider.autoDispose<List<Food>>((ref) async {
  final q = ref.watch(foodSearchQueryProvider);
  if (q.trim().length < 2) return const [];
  // Cheap debounce: 200ms of stability.
  await Future<void>.delayed(const Duration(milliseconds: 200));
  if (q != ref.read(foodSearchQueryProvider)) return const [];
  final repo = ref.watch(foodRepositoryProvider);
  try {
    return await repo.search(q);
  } catch (e, s) {
    if (kDebugMode) debugPrint('search error: $e\n$s');
    return const [];
  }
});

final recentFoodsProvider = FutureProvider.autoDispose<List<Food>>((ref) async {
  final repo = ref.watch(foodRepositoryProvider);
  return repo.recents();
});

final favoriteFoodsProvider = FutureProvider.autoDispose<List<Food>>((ref) async {
  final repo = ref.watch(foodRepositoryProvider);
  return repo.favorites();
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

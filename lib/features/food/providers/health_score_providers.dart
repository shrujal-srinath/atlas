import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../domain/health_score.dart';
import '../domain/meal_entry.dart';
import 'food_providers.dart';

/// Score across all meals logged today vs targets.
final dayHealthScoreProvider = Provider.autoDispose<HealthScore>((ref) {
  final entries = ref.watch(diaryEntriesProvider).valueOrNull ?? const <MealEntry>[];
  final totals = ref.watch(diaryTotalsProvider);
  final targets = ref.watch(dailyTargetsProvider);
  final loggedSlots = entries.map((e) => e.slot).toSet().length;
  return dayHealthScore(totals, targets, loggedSlotCount: loggedSlots);
});

/// Score for one meal slot today.
final mealHealthScoreProvider =
    Provider.autoDispose.family<HealthScore, MealTimeSlot>((ref, slot) {
  final entries = ref.watch(diaryEntriesProvider).valueOrNull ?? const <MealEntry>[];
  return mealHealthScore(entries.where((e) => e.slot == slot).toList());
});

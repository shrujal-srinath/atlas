import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../data/food_repository.dart';
import 'food_providers.dart';

/// Top-N most-logged foods in a meal slot over the last 30 days, with the
/// latest portion snapshot — used to render the quick-log chip row.
final slotHistoryProvider = FutureProvider.autoDispose
    .family<List<SlotHistoryItem>, MealTimeSlot>((ref, slot) async {
  final repo = ref.watch(foodRepositoryProvider);
  ref.watch(diaryDateProvider); // refresh after log
  return repo.slotHistory(slot, limit: 3);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../domain/food.dart';
import '../domain/meal_entry.dart';
import 'food_providers.dart';

/// One day's roll-up used by the Insights surface.
class DayTotals {
  final DateTime date;
  final Nutrients totals;
  final Set<MealTimeSlot> loggedSlots;
  DayTotals({required this.date, required this.totals, required this.loggedSlots});

  bool get hasLogs => totals.kcal > 0 || loggedSlots.isNotEmpty;
}

/// Selected Insights look-back window, in days (7 / 30 / 90).
final insightsRangeProvider = StateProvider<int>((_) => 7);

/// Daily roll-ups over the [insightsRangeProvider] window, oldest → newest.
final rangeTotalsProvider =
    FutureProvider.autoDispose<List<DayTotals>>((ref) async {
  final days = ref.watch(insightsRangeProvider);
  final repo = ref.watch(foodRepositoryProvider);
  ref.watch(diaryDateProvider);

  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final start = today.subtract(Duration(days: days - 1));
  final bucketed = await repo.entriesForRange(start, today);

  final out = <DayTotals>[];
  for (int i = 0; i < days; i++) {
    final d = start.add(Duration(days: i));
    final entries = bucketed[d] ?? const <MealEntry>[];
    final totals = entries.fold<Nutrients>(
        Nutrients.zero, (a, e) => a + e.totals);
    final slots = entries.map((e) => e.slot).toSet();
    out.add(DayTotals(date: d, totals: totals, loggedSlots: slots));
  }
  return out;
});

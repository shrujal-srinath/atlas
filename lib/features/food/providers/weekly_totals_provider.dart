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

/// Last 7 days bucketed by date-only, oldest → newest.
final weeklyTotalsProvider =
    FutureProvider.autoDispose<List<DayTotals>>((ref) async {
  final repo = ref.watch(foodRepositoryProvider);
  ref.watch(diaryDateProvider);

  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final start = today.subtract(const Duration(days: 6));
  final bucketed = await repo.entriesForRange(start, today);

  final out = <DayTotals>[];
  for (int i = 0; i < 7; i++) {
    final d = start.add(Duration(days: i));
    final entries = bucketed[d] ?? const <MealEntry>[];
    final totals = entries.fold<Nutrients>(
        Nutrients.zero, (a, e) => a + e.totals);
    final slots = entries.map((e) => e.slot).toSet();
    out.add(DayTotals(date: d, totals: totals, loggedSlots: slots));
  }
  return out;
});

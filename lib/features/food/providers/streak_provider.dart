import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/meal_entry.dart';
import 'food_providers.dart';

/// State of one day in the streak strip.
enum DayLogState { hit, partial, empty, future }

class DayLog {
  final DateTime date; // date-only
  final DayLogState state;
  final double kcal;
  final double targetKcal;
  const DayLog({
    required this.date,
    required this.state,
    required this.kcal,
    required this.targetKcal,
  });

  bool get isToday {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }
}

/// Last 7 days of streak data (oldest → newest). Filled = hit ≥80% of kcal target.
final streakProvider = FutureProvider.autoDispose<List<DayLog>>((ref) async {
  final repo = ref.watch(foodRepositoryProvider);
  final targets = ref.watch(dailyTargetsProvider);
  // Watch diary date so the strip recomputes after logs land on today.
  ref.watch(diaryDateProvider);

  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final start = today.subtract(const Duration(days: 6));
  final bucketed = await repo.entriesForRange(start, today);

  final out = <DayLog>[];
  for (int i = 0; i < 7; i++) {
    final d = start.add(Duration(days: i));
    final entries = bucketed[d] ?? const <MealEntry>[];
    final kcal = entries.fold<double>(0, (a, e) => a + e.totals.kcal);
    final state = _classify(kcal, targets.kcal, entries.isNotEmpty);
    out.add(DayLog(date: d, state: state, kcal: kcal, targetKcal: targets.kcal));
  }
  return out;
});

DayLogState _classify(double kcal, double target, bool hasEntries) {
  if (!hasEntries) return DayLogState.empty;
  if (target <= 0) return DayLogState.partial;
  final r = kcal / target;
  if (r >= 0.80 && r <= 1.15) return DayLogState.hit;
  return DayLogState.partial;
}

/// Total kcal consumed for each day of [month] (keyed by day-of-month 1..31),
/// for the Fueling Calendar heatmap. Days with no log are simply absent from
/// the map. Keyed by a normalised first-of-month so the family caches per
/// month. Re-watches [diaryDateProvider] so it refreshes after today's logs.
final monthCaloriesProvider =
    FutureProvider.autoDispose.family<Map<int, double>, DateTime>(
        (ref, month) async {
  final repo = ref.watch(foodRepositoryProvider);
  ref.watch(diaryDateProvider);
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  final bucketed = await repo.entriesForRange(first, last);
  final out = <int, double>{};
  bucketed.forEach((d, entries) {
    out[d.day] = entries.fold<double>(0, (a, e) => a + e.totals.kcal);
  });
  return out;
});

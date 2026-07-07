import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dev/dev_mode.dart';
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

  // Demo/dev: no Supabase session, so fabricate a believable week so the strip
  // and fueling calendar look alive instead of empty.
  if (ref.watch(devModeProvider)) {
    const ratios = [0.92, 1.04, 0.7, 1.0, 0.0, 0.96, 0.62]; // oldest → today
    final t = targets.kcal;
    return [
      for (int i = 0; i < 7; i++)
        DayLog(
          date: start.add(Duration(days: i)),
          state: _classify(ratios[i] * t, t, ratios[i] > 0),
          kcal: ratios[i] * t,
          targetKcal: t,
        ),
    ];
  }

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

  // Demo/dev: fabricate a believable month of intake around target.
  if (ref.watch(devModeProvider)) {
    final t = ref.watch(dailyTargetsProvider).kcal;
    final n = DateTime.now();
    final isCurrentMonth = month.year == n.year && month.month == n.month;
    final upto = isCurrentMonth ? n.day : last.day;
    final out = <int, double>{};
    for (int day = 1; day <= upto; day++) {
      if (day % 6 == 0) continue; // a few un-logged days for realism
      final r = 0.6 + ((day * 37) % 55) / 100.0; // deterministic 0.6..1.15
      out[day] = r * t;
    }
    return out;
  }

  final bucketed = await repo.entriesForRange(first, last);
  final out = <int, double>{};
  bucketed.forEach((d, entries) {
    out[d.day] = entries.fold<double>(0, (a, e) => a + e.totals.kcal);
  });
  return out;
});

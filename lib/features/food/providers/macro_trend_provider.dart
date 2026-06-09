import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/meal_entry.dart';
import 'food_providers.dart';

enum MacroKind { kcal, protein, carbs, fat, fiber }

class MacroTrend {
  /// Per-day totals for the macro, oldest → newest (length == days).
  final List<double> values;
  final double target;
  const MacroTrend({required this.values, required this.target});
}

/// Last [days] days of one macro, for sparklines. Includes today.
final macroTrendProvider =
    FutureProvider.autoDispose.family<MacroTrend, _MacroTrendKey>((ref, key) async {
  final repo = ref.watch(foodRepositoryProvider);
  final targets = ref.watch(dailyTargetsProvider);
  ref.watch(diaryDateProvider); // refresh when date or logs change

  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final start = today.subtract(Duration(days: key.days - 1));
  final bucketed = await repo.entriesForRange(start, today);

  double targetFor() {
    switch (key.kind) {
      case MacroKind.kcal:    return targets.kcal;
      case MacroKind.protein: return targets.proteinG;
      case MacroKind.carbs:   return targets.carbsG;
      case MacroKind.fat:     return targets.fatG;
      case MacroKind.fiber:   return targets.micros.fiberG;
    }
  }

  double valueFor(List<MealEntry> entries) {
    switch (key.kind) {
      case MacroKind.kcal:    return entries.fold(0.0, (a, e) => a + e.totals.kcal);
      case MacroKind.protein: return entries.fold(0.0, (a, e) => a + e.totals.proteinG);
      case MacroKind.carbs:   return entries.fold(0.0, (a, e) => a + e.totals.carbsG);
      case MacroKind.fat:     return entries.fold(0.0, (a, e) => a + e.totals.fatG);
      case MacroKind.fiber:   return entries.fold(0.0, (a, e) => a + e.totals.fiberG);
    }
  }

  final values = <double>[];
  for (int i = 0; i < key.days; i++) {
    final d = start.add(Duration(days: i));
    values.add(valueFor(bucketed[d] ?? const []));
  }
  return MacroTrend(values: values, target: targetFor());
});

class _MacroTrendKey {
  final MacroKind kind;
  final int days;
  const _MacroTrendKey(this.kind, this.days);

  @override
  bool operator ==(Object other) =>
      other is _MacroTrendKey && other.kind == kind && other.days == days;
  @override
  int get hashCode => Object.hash(kind, days);
}

/// Convenience constructor: `ref.watch(macroTrend(MacroKind.protein, 7))`.
AutoDisposeFutureProvider<MacroTrend> macroTrend(MacroKind k, int days) =>
    macroTrendProvider(_MacroTrendKey(k, days));

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/providers/habit_provider.dart';
import '../widgets/consistency_heatmap.dart';

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Last [days] days of completion cells (oldest → newest, today last) for the
/// shared [ConsistencyHeatmap]. Single source of truth consumed by both the
/// Glance and Trends screens. Derived from the same `habitsForDate` +
/// `recentHabitLogsProvider` (60-day window) the rest of the app uses, so a
/// day's completion count is identical everywhere it appears.
final consistencyHeatmapProvider =
    FutureProvider.family<List<HeatmapCell>, int>((ref, days) async {
  final habits = await ref.watch(habitsProvider.future);
  final logs = await ref.watch(recentHabitLogsProvider.future);
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);

  final cells = <HeatmapCell>[];
  for (int i = days - 1; i >= 0; i--) {
    final d = today.subtract(Duration(days: i));
    final key = _ds(d);
    final dayHabits = habitsForDate(habits, d);
    final done = dayHabits
        .where((h) =>
            logs.any((l) => l.habitId == h.id && l.date == key && l.completed))
        .length;
    cells.add(HeatmapCell(date: d, completed: done, scheduled: dayHabits.length));
  }
  return cells;
});

/// One [HeatmapCell] per calendar day of [month] (day 1 → last day), for the
/// monthly calendar heatmap on the Stats hub. Derived exactly like
/// [consistencyHeatmapProvider] so a day's shading is identical wherever it
/// appears. Days older than the log-cache window (≈60 days) read as empty.
/// Keyed by a normalised first-of-month so the family caches per month.
final monthHeatmapProvider =
    FutureProvider.family<List<HeatmapCell>, DateTime>((ref, month) async {
  final habits = await ref.watch(habitsProvider.future);
  final logs = await ref.watch(recentHabitLogsProvider.future);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

  final cells = <HeatmapCell>[];
  for (int day = 1; day <= daysInMonth; day++) {
    final d = DateTime(month.year, month.month, day);
    final key = _ds(d);
    final dayHabits = habitsForDate(habits, d);
    final done = dayHabits
        .where((h) =>
            logs.any((l) => l.habitId == h.id && l.date == key && l.completed))
        .length;
    cells.add(HeatmapCell(date: d, completed: done, scheduled: dayHabits.length));
  }
  return cells;
});

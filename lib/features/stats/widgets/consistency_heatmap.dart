import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// One day in a consistency heatmap: how many scheduled habits were completed.
/// Single source of truth for the grid — both Glance and Trends render from
/// these so the colour ramp can never diverge between the two screens.
class HeatmapCell {
  final DateTime date;
  final int completed;
  final int scheduled;
  const HeatmapCell({
    required this.date,
    required this.completed,
    required this.scheduled,
  });

  /// Completion ratio in `[0, 1]`. A rest day (nothing scheduled) reads 0 but
  /// is distinguished by [isRestDay] so it renders neutrally, not as a "miss".
  double get rate =>
      scheduled == 0 ? 0.0 : (completed / scheduled).clamp(0.0, 1.0);
  bool get isRestDay => scheduled == 0;
}

/// Shared completion-rate → colour ramp. Rest days and zero-completion days
/// render as the elevated surface; everything else ramps the accent alpha.
Color consistencyCellColor(BuildContext context, HeatmapCell cell) {
  final c = context.c;
  if (cell.isRestDay) return c.surfaceElevated;
  final r = cell.rate;
  if (r >= 0.95) return c.accent;
  if (r >= 0.70) return c.accent.withValues(alpha: 0.60);
  if (r >= 0.40) return c.accent.withValues(alpha: 0.30);
  if (r > 0) return c.accent.withValues(alpha: 0.12);
  return c.surfaceElevated;
}

/// A 7-column consistency grid. Used by Glance (5 weeks, no labels) and Trends
/// (28 days, day numbers + today marker).
class ConsistencyHeatmap extends StatelessWidget {
  final List<HeatmapCell> cells;
  final int columns;
  final double spacing;
  final bool showDayNumbers;
  final bool markToday;
  const ConsistencyHeatmap({
    super.key,
    required this.cells,
    this.columns = 7,
    this.spacing = 4,
    this.showDayNumbers = false,
    this.markToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1.0,
      ),
      itemCount: cells.length,
      itemBuilder: (_, i) {
        final cell = cells[i];
        final isToday = markToday &&
            DateTime(cell.date.year, cell.date.month, cell.date.day) ==
                todayKey;
        return Container(
          decoration: BoxDecoration(
            color: consistencyCellColor(context, cell),
            borderRadius: BorderRadius.circular(4),
            border:
                isToday ? Border.all(color: c.accent, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: showDayNumbers
              ? Text(
                  '${cell.date.day}',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: cell.rate >= 0.70 ? c.onAccent : c.textDim,
                  ),
                )
              : null,
        );
      },
    );
  }
}

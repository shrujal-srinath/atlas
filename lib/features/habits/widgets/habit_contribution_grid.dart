import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
const _mon = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// GitHub-style contribution grid for a single habit — weeks as columns
/// (oldest → newest), weekdays as rows. The single most motivating consistency
/// view: a glance shows momentum, gaps, and density. Cell intensity reflects
/// completion (full = done, faint = a scheduled miss, near-empty = a rest day).
/// On open, columns reveal left → right for a satisfying fill-in.
class HabitContributionGrid extends StatefulWidget {
  final Habit habit;
  final List<HabitLog> logs;
  final Color accent;
  final int weeks;
  const HabitContributionGrid({
    super.key,
    required this.habit,
    required this.logs,
    required this.accent,
    this.weeks = 17,
  });

  @override
  State<HabitContributionGrid> createState() => _HabitContributionGridState();
}

class _HabitContributionGridState extends State<HabitContributionGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Reveal amount (0..1) for column [col] — earlier columns lead.
  double _colReveal(int col, int weeks) {
    final span = weeks <= 1 ? 1 : (weeks - 1);
    final start = (col / span) * 0.55;
    return Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOut)
        .transform(_ctrl.value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final weeks = widget.weeks;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final gridStart = startOfWeek.subtract(Duration(days: (weeks - 1) * 7));

    final done = <String>{};
    final partial = <String>{};
    for (final l in widget.logs) {
      if (l.completed) {
        done.add(l.date);
      } else if ((l.actualValue ?? 0) > 0) {
        partial.add(l.date);
      }
    }
    bool scheduledOn(DateTime d) =>
        widget.habit.existedOn(d) && widget.habit.daysOfWeek.contains(d.weekday);

    Color cellColor(DateTime d) {
      if (d.isAfter(today)) return Colors.transparent;
      final key = _ds(d);
      if (done.contains(key)) return widget.accent;
      if (partial.contains(key)) return widget.accent.withValues(alpha: 0.45);
      if (scheduledOn(d)) return c.surfaceElevated; // a miss
      return c.surfaceElevated.withValues(alpha: 0.35); // rest day
    }

    return LayoutBuilder(builder: (context, box) {
      const gap = 3.0;
      final cell = ((box.maxWidth - gap * (weeks - 1)) / weeks).clamp(8.0, 18.0);
      final colW = cell + gap;

      return AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final monthLabels = <Widget>[];
          int? lastMonth;
          for (int col = 0; col < weeks; col++) {
            final weekStart = gridStart.add(Duration(days: col * 7));
            final m = weekStart.month;
            final isNew = m != lastMonth;
            lastMonth = m;
            monthLabels.add(SizedBox(
              width: colW,
              child: isNew
                  ? Opacity(
                      opacity: _colReveal(col, weeks),
                      child: Text(_mon[m],
                          style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 9,
                              color: c.textDim)),
                    )
                  : const SizedBox.shrink(),
            ));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: monthLabels),
              const SizedBox(height: 4),
              for (int row = 0; row < 7; row++)
                Padding(
                  padding: EdgeInsets.only(bottom: row == 6 ? 0 : gap),
                  child: Row(
                    children: [
                      for (int col = 0; col < weeks; col++)
                        Padding(
                          padding:
                              EdgeInsets.only(right: col == weeks - 1 ? 0 : gap),
                          child: () {
                            final day =
                                gridStart.add(Duration(days: col * 7 + row));
                            final t = _colReveal(col, weeks);
                            return Opacity(
                              opacity: t,
                              child: Transform.scale(
                                scale: 0.7 + 0.3 * t,
                                child: Container(
                                  width: cell,
                                  height: cell,
                                  decoration: BoxDecoration(
                                    color: cellColor(day),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          }(),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Opacity(
                opacity: _ctrl.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Less',
                        style: TextStyle(
                            fontFamily: 'Inter', fontSize: 10, color: c.textDim)),
                    const SizedBox(width: 6),
                    _legendCell(c.surfaceElevated),
                    _legendCell(widget.accent.withValues(alpha: 0.45)),
                    _legendCell(widget.accent),
                    const SizedBox(width: 6),
                    Text('More',
                        style: TextStyle(
                            fontFamily: 'Inter', fontSize: 10, color: c.textDim)),
                  ],
                ),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _legendCell(Color color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
}

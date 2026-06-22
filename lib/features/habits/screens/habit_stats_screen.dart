import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/task_stats.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../providers/habit_provider.dart';
import '../widgets/habit_month_heatmap.dart';

/// Deep per-task analytics: streaks, completion-rate trend, performance
/// progression, day-of-week & effort patterns, and a month heatmap — switchable
/// across Week / Month / Year. Opened from the task detail screen.
class HabitStatsScreen extends ConsumerStatefulWidget {
  final String habitId;
  const HabitStatsScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitStatsScreen> createState() => _HabitStatsScreenState();
}

class _HabitStatsScreenState extends ConsumerState<HabitStatsScreen> {
  StatRange _range = StatRange.month;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final habitsAsync = ref.watch(allHabitsProvider);
    final logsAsync = ref.watch(habitLogHistoryProvider(widget.habitId));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(),
        title: Text('Task stats', style: t.h2),
      ),
      body: habitsAsync.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: c.accent, strokeWidth: 2)),
        error: (e, _) => Center(
            child: Text(friendlyError(e),
                style: TextStyle(color: c.negative, fontSize: 13))),
        data: (habits) {
          final habit = habits.where((h) => h.id == widget.habitId).firstOrNull;
          if (habit == null) {
            return Center(
                child: Text('Not found',
                    style: t.body.copyWith(color: c.textMuted)));
          }
          final accent = _accent(context, habit);
          final logs = logsAsync.valueOrNull ?? const <HabitLog>[];
          final stats =
              computeTaskStats(habit: habit, logs: logs, range: _range);
          final goalBearing = habit.goalType != null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screenH, 12, AppSpace.screenH, 40),
            children: [
              _Header(habit: habit, accent: accent),
              const SizedBox(height: 16),
              _RangeToggle(
                value: _range,
                accent: accent,
                onChanged: (r) => setState(() => _range = r),
              ),
              const SizedBox(height: 16),
              _KpiRow(stats: stats, accent: accent),
              const SizedBox(height: 14),
              _ChartCard(
                title: 'COMPLETION RATE',
                child: _RateTrendChart(stats: stats, accent: accent),
              ),
              if (goalBearing) ...[
                const SizedBox(height: 14),
                _ChartCard(
                  title: 'PERFORMANCE',
                  subtitle: _goalLabel(habit),
                  child: _PerformanceChart(stats: stats, accent: accent),
                ),
              ],
              const SizedBox(height: 14),
              _ChartCard(
                title: 'BY WEEKDAY',
                child: _WeekdayChart(stats: stats, accent: accent),
              ),
              if (habit.effortRatingEnabled) ...[
                const SizedBox(height: 14),
                _ChartCard(
                  title: 'EFFORT',
                  child: _EffortChart(stats: stats, accent: accent),
                ),
              ],
              const SizedBox(height: 14),
              HabitMonthHeatmap(habit: habit, logs: logs, accent: accent),
            ],
          );
        },
      ),
    );
  }

  Color _accent(BuildContext context, Habit habit) {
    if (habit.colorKey != null && kHabitColorSwatch[habit.colorKey] != null) {
      return Color(kHabitColorSwatch[habit.colorKey]!);
    }
    return habit.section.color(context.c);
  }

  String _goalLabel(Habit habit) {
    final unit = switch (habit.goalType!) {
      GoalType.reps => 'reps',
      GoalType.durationMin => 'min',
      GoalType.distanceKm => 'km',
      GoalType.litres => 'L',
      GoalType.custom => 'units',
    };
    final g = habit.goalValue;
    return g == null ? unit : 'Goal · ${g.toStringAsFixed(0)} $unit';
  }
}

// ── Header ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Habit habit;
  final Color accent;
  const _Header({required this.habit, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Icon(habitIcon(habit.icon), size: 22, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(habit.name, style: t.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                habit.section.name[0].toUpperCase() + habit.section.name.substring(1),
                style: t.meta,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Range toggle ───────────────────────────────────────────────────────

class _RangeToggle extends StatelessWidget {
  final StatRange value;
  final Color accent;
  final ValueChanged<StatRange> onChanged;
  const _RangeToggle({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.button + 4),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          for (final r in StatRange.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(r);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: r == value ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    border: r == value
                        ? Border.all(color: accent.withValues(alpha: 0.45))
                        : null,
                    boxShadow: r == value
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    r.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: r == value ? FontWeight.w700 : FontWeight.w600,
                      color: r == value ? accent : c.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── KPI tiles ──────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final TaskStats stats;
  final Color accent;
  const _KpiRow({required this.stats, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            label: 'CURRENT',
            value: '${stats.currentStreak}',
            suffix: 'days',
            icon: LucideIcons.flame,
            color: c.amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiTile(
            label: 'BEST',
            value: '${stats.bestStreak}',
            suffix: 'days',
            icon: LucideIcons.trophy,
            color: accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiTile(
            label: 'RATE',
            value: '${(stats.completionRate * 100).round()}',
            suffix: '%',
            icon: LucideIcons.activity,
            color: c.positive,
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final Color color;
  const _KpiTile({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 22,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              Text(suffix, style: t.meta.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: t.label.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Card wrapper ─────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _ChartCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppType.overline.copyWith(color: c.textMuted)),
              if (subtitle != null) ...[
                const Spacer(),
                Text(subtitle!,
                    style: AppType.meta.copyWith(color: c.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String text;
  const _EmptyChart(this.text);
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 150,
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: AppType.meta.copyWith(color: c.textMuted)),
      ),
    );
  }
}

// ── Completion-rate trend (bars) ────────────────────────────────────────

class _RateTrendChart extends StatelessWidget {
  final TaskStats stats;
  final Color accent;
  const _RateTrendChart({required this.stats, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final buckets = stats.rateTrend;
    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: 1.0,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.5,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 0.5,
                getTitlesWidget: (v, _) => Text('${(v * 100).round()}',
                    style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 10,
                        color: c.textDim)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(buckets[i].label,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: c.textDim)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.surfaceElevated,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${(rod.toY * 100).round()}%',
                TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary),
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < buckets.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: buckets[i].active ? buckets[i].rate : 0,
                    color: buckets[i].active
                        ? accent.withValues(alpha: 0.85)
                        : c.borderStrong,
                    width: buckets.length > 7 ? 10 : 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 1.0,
                      color: c.surfaceElevated,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Performance progression (line + goal) ───────────────────────────────

class _PerformanceChart extends StatelessWidget {
  final TaskStats stats;
  final Color accent;
  const _PerformanceChart({required this.stats, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pts = stats.performance;
    if (pts.length < 2) {
      return const _EmptyChart(
          'Log a number (reps / minutes / km) when you complete this to see your progression.');
    }
    final goal = stats.goalValue ?? 0;
    final maxVal = [
      ...pts.map((p) => p.value),
      if (goal > 0) goal,
    ].reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal * 1.15).ceilToDouble();

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY,
          minX: 0,
          maxX: (pts.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 10,
                        color: c.textDim)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: ((pts.length - 1) / 4).clamp(1, double.infinity),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${pts[i].date.day}/${pts[i].date.month}',
                        style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 9,
                            color: c.textDim)),
                  );
                },
              ),
            ),
          ),
          extraLinesData: goal > 0
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: goal,
                    color: c.positive.withValues(alpha: 0.7),
                    strokeWidth: 1.5,
                    dashArray: [5, 4],
                  ),
                ])
              : const ExtraLinesData(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surfaceElevated,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        s.y.toStringAsFixed(s.y == s.y.roundToDouble() ? 0 : 1),
                        TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < pts.length; i++)
                  FlSpot(i.toDouble(), pts[i].value),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              color: accent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: pts.length <= 20,
                getDotPainter: (s, _, b, _) => FlDotCirclePainter(
                    radius: 3, color: accent, strokeWidth: 2, strokeColor: c.surface),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.18),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── By-weekday (bars) ────────────────────────────────────────────────────

class _WeekdayChart extends StatelessWidget {
  final TaskStats stats;
  final Color accent;
  const _WeekdayChart({required this.stats, required this.accent});

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = stats.weekday; // 7 entries, Mon..Sun
    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          maxY: 1.0,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= 7) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_letters[i],
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.textDim)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.surfaceElevated,
              getTooltipItem: (group, _, rod, _) {
                final stat = w[group.x];
                return BarTooltipItem(
                  '${stat.completed}/${stat.scheduled}',
                  TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary),
                );
              },
            ),
          ),
          barGroups: [
            for (int i = 0; i < 7; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: w[i].scheduled == 0 ? 0 : w[i].rate,
                    color: w[i].scheduled == 0
                        ? c.borderStrong
                        : accent.withValues(alpha: 0.85),
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 1.0,
                      color: c.surfaceElevated,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Effort trend (line) ──────────────────────────────────────────────────

class _EffortChart extends StatelessWidget {
  final TaskStats stats;
  final Color accent;
  const _EffortChart({required this.stats, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pts = stats.effort;
    if (pts.length < 2) {
      return const _EmptyChart('Rate effort when you log this to see the trend.');
    }
    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 5,
          minX: 0,
          maxX: (pts.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 10,
                        color: c.textDim)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surfaceElevated,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        s.y.toStringAsFixed(s.y == s.y.roundToDouble() ? 0 : 1),
                        TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < pts.length; i++)
                  FlSpot(i.toDouble(), pts[i].value),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              color: c.amber,
              barWidth: 2.5,
              dotData: FlDotData(
                show: pts.length <= 20,
                getDotPainter: (s, _, b, _) => FlDotCirclePainter(
                    radius: 3, color: c.amber, strokeWidth: 2, strokeColor: c.surface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

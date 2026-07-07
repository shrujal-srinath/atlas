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
import '../../home/scoring/section_def.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../providers/habit_provider.dart';
import '../widgets/habit_contribution_grid.dart';

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
          final totalCompletions = logs.where((l) => l.completed).length;
          final week = _currentWeekMarks(logs);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screenH, 14, AppSpace.screenH, 40),
            children: [
              _StatHero(
                habit: habit,
                accent: accent,
                stats: stats,
                totalCompletions: totalCompletions,
                week: week,
              ),
              const SizedBox(height: 16),
              _RangeToggle(
                value: _range,
                accent: accent,
                onChanged: (r) => setState(() => _range = r),
              ),
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
              _ChartCard(
                title: 'CONSISTENCY',
                subtitle: 'Last 4 months',
                child: HabitContributionGrid(
                    habit: habit, logs: logs, accent: accent),
              ),
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
    return habit.sectionId.sectionColor(context.c);
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

  /// Completion status for each day of the current week (Mon→Sun).
  List<_DayMark> _currentWeekMarks(List<HabitLog> logs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final done = <String>{for (final l in logs) if (l.completed) l.date};
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = monday.add(Duration(days: i));
          if (d.isAfter(today)) return _DayMark.future;
          return done.contains(ymd(d)) ? _DayMark.done : _DayMark.missed;
        }(),
    ];
  }
}

enum _DayMark { done, missed, future }

// ── Header ─────────────────────────────────────────────────────────────

/// The hero: a completion ring with the habit icon + streak flame, the three
/// headline stats (Best · All-time % · Completions), and the current-week rings.
class _StatHero extends StatelessWidget {
  final Habit habit;
  final Color accent;
  final TaskStats stats;
  final int totalCompletions;
  final List<_DayMark> week;
  const _StatHero({
    required this.habit,
    required this.accent,
    required this.stats,
    required this.totalCompletions,
    required this.week,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _HeroRing(
                progress: stats.completionRate.clamp(0, 1).toDouble(),
                accent: accent,
                icon: habitIcon(habit.icon),
                streak: stats.currentStreak,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name,
                        style: t.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.flame, size: 14, color: c.amber),
                        const SizedBox(width: 5),
                        Text(
                          stats.currentStreak > 0
                              ? '${stats.currentStreak}-day streak'
                              : habit.sectionId.sectionName,
                          style: t.meta.copyWith(
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroStat(
                  value: '${stats.bestStreak}', label: 'BEST STREAK'),
              _HeroDivider(),
              _HeroStat(
                  value: '${(stats.completionRate * 100).round()}%',
                  label: 'ALL-TIME'),
              _HeroDivider(),
              _HeroStat(
                  value: '$totalCompletions', label: 'COMPLETIONS'),
            ],
          ),
          const SizedBox(height: 16),
          _WeekRings(week: week, accent: accent),
        ],
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  final double progress; // 0..1
  final Color accent;
  final IconData icon;
  final int streak;
  const _HeroRing({
    required this.progress,
    required this.accent,
    required this.icon,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(
              size: const Size(84, 84),
              painter: _RingPainter(
                  progress: v, color: accent, track: c.border),
            ),
          ),
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: accent),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  const _RingPainter(
      {required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, base);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // start at top (-90°)
      6.2832 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 24,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(label,
              style: t.label.copyWith(
                  fontSize: 9.5, color: c.textMuted, letterSpacing: 0.6),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.5, height: 30, color: context.c.border);
}

/// The current week as Mon→Sun day rings, filled when completed.
class _WeekRings extends StatelessWidget {
  final List<_DayMark> week;
  final Color accent;
  const _WeekRings({required this.week, required this.accent});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Column(
            children: [
              _DayRing(mark: week[i], accent: accent),
              const SizedBox(height: 5),
              Text(_labels[i],
                  style: t.meta.copyWith(
                      color: c.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
      ],
    );
  }
}

class _DayRing extends StatelessWidget {
  final _DayMark mark;
  final Color accent;
  const _DayRing({required this.mark, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return switch (mark) {
      _DayMark.done => Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: Icon(LucideIcons.check, size: 16, color: c.onAccent),
        ),
      _DayMark.missed => Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.border, width: 2),
          ),
        ),
      _DayMark.future => Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: c.border.withValues(alpha: 0.5), width: 1.5),
          ),
        ),
    };
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
              fitInsideHorizontally: true,
              fitInsideVertically: true,
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
          clipData: const FlClipData.all(),
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
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 2, bottom: 2),
                      style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: c.positive),
                      labelResolver: (_) => 'Goal',
                    ),
                  ),
                ])
              : const ExtraLinesData(),
          lineTouchData: LineTouchData(
            getTouchedSpotIndicator: (barData, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(
                    color: (barData.color ?? c.accent).withValues(alpha: 0.30),
                    strokeWidth: 1.5,
                  ),
                  FlDotData(
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 3.5,
                      color: b.color ?? c.accent,
                      strokeWidth: 2,
                      strokeColor: c.surface,
                    ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surfaceElevated,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
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
              preventCurveOverShooting: true,
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
              fitInsideHorizontally: true,
              fitInsideVertically: true,
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
          clipData: const FlClipData.all(),
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
            getTouchedSpotIndicator: (barData, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(
                    color: (barData.color ?? c.accent).withValues(alpha: 0.30),
                    strokeWidth: 1.5,
                  ),
                  FlDotData(
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 3.5,
                      color: b.color ?? c.accent,
                      strokeWidth: 2,
                      strokeColor: c.surface,
                    ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surfaceElevated,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
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
              preventCurveOverShooting: true,
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

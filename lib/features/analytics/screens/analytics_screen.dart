import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../journal/widgets/wellness_trend_section.dart';
import '../providers/analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final dataAsync = ref.watch(analyticsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: dataAsync.when(
          data: (data) => CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.screenH, 16, AppSpace.screenH, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ANALYTICS',
                          style: AppType.overline.copyWith(color: c.textMuted)),
                      const SizedBox(height: 6),
                      Text('Performance Insights', style: t.h1),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Summary cards row
              SliverToBoxAdapter(child: _SummaryRow(data: data)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Score trend chart
              SliverToBoxAdapter(child: _ScoreTrendChart(data: data)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Section breakdown
              SliverToBoxAdapter(child: _SectionBreakdown(sections: data.sections)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Heatmap
              SliverToBoxAdapter(child: _CompletionHeatmap(heatmap: data.heatmap)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Streak leaderboard
              if (data.streaks.isNotEmpty)
                SliverToBoxAdapter(
                    child: _StreakLeaderboard(streaks: data.streaks)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Wellness trends (mood/energy/sleep — last 30 days).
              const SliverToBoxAdapter(child: WellnessTrendSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 118)),
            ],
          ),
          loading: () => Center(
            child: CircularProgressIndicator(color: c.accent, strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Text(e.toString(),
                style: TextStyle(color: c.negative, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

// ── Summary cards ──────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final AnalyticsData data;
  const _SummaryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final delta = data.weekAvg - data.prevWeekAvg;
    final deltaSign = delta >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'WEEK AVG',
              value: '${data.weekAvg.round()}%',
              sub: '$deltaSign${delta.round()}% vs last week',
              subColor: delta >= 0 ? c.positive : c.negative,
              icon: LucideIcons.trendingUp,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'COMPLETED',
              value: '${data.totalCompletions}',
              sub: 'last 28 days',
              subColor: c.textMuted,
              icon: LucideIcons.checkCheck,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'PERFECT',
              value: '${data.perfectDays}',
              sub: 'days this month',
              subColor: data.perfectDays > 0 ? c.amber : c.textMuted,
              icon: LucideIcons.crown,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color subColor;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
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
          Icon(icon, size: 14, color: c.textMuted),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppType.numLg.copyWith(fontSize: 22, color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: subColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Score trend chart ──────────────────────────────────────────

class _ScoreTrendChart extends StatefulWidget {
  final AnalyticsData data;
  const _ScoreTrendChart({required this.data});

  @override
  State<_ScoreTrendChart> createState() => _ScoreTrendChartState();
}

class _ScoreTrendChartState extends State<_ScoreTrendChart> {
  bool _showMonth = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final scores = _showMonth ? widget.data.monthScores : widget.data.weekScores;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Text('SCORE TREND',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              _ChipToggle(
                labels: const ['7D', '28D'],
                selected: _showMonth ? 1 : 0,
                onChanged: (i) => setState(() => _showMonth = i == 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: c.border,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 10,
                          color: c.textDim,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: _showMonth ? 7 : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= scores.length) return const SizedBox();
                        final day = scores[idx].date;
                        return Text(
                          '${day.day}',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 10,
                            color: c.textDim,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles()),
                  rightTitles: const AxisTitles(sideTitles: SideTitles()),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      scores.length,
                      (i) => FlSpot(i.toDouble(), scores[i].score),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: c.accent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: !_showMonth,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: c.accent,
                        strokeWidth: 2,
                        strokeColor: c.surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.accent.withValues(alpha: 0.2),
                          c.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => c.surfaceElevated,
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.round()}%',
                        TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      );
                    }).toList(),
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

// ── Chip toggle ────────────────────────────────────────────────

class _ChipToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const _ChipToggle({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? c.accent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: active
                    ? Border.all(color: c.accent.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? c.accent : c.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Section breakdown ──────────────────────────────────────────

class _SectionBreakdown extends StatelessWidget {
  final List<SectionStats> sections;
  const _SectionBreakdown({required this.sections});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY\'S SECTIONS',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 14),
          for (final s in sections) ...[
            _SectionBar(stats: s),
            if (s != sections.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  final SectionStats stats;
  const _SectionBar({required this.stats});

  Color _sectionColor(AppPalette c) => switch (stats.section) {
        HabitSection.athletic => c.athletic,
        HabitSection.body => c.body,
        HabitSection.mind => c.mind,
      };

  String get _label => switch (stats.section) {
        HabitSection.athletic => 'Athletic',
        HabitSection.body => 'Breaking',
        HabitSection.mind => 'Building',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = _sectionColor(c);
    final pct = (stats.rate * 100).round();

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${stats.completed}/${stats.total}',
              style: AppType.numMd.copyWith(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              style: AppType.numMd.copyWith(
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: c.surfaceElevated),
                FractionallySizedBox(
                  widthFactor: stats.rate.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Completion heatmap ─────────────────────────────────────────

class _CompletionHeatmap extends StatelessWidget {
  final List<HeatmapDay> heatmap;
  const _CompletionHeatmap({required this.heatmap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('28-DAY CONSISTENCY',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              // Legend
              _LegendDot(color: c.surfaceElevated, label: '0%'),
              const SizedBox(width: 8),
              _LegendDot(color: c.accent.withValues(alpha: 0.3), label: '50%'),
              const SizedBox(width: 8),
              _LegendDot(color: c.accent, label: '100%'),
            ],
          ),
          const SizedBox(height: 14),
          // 4 rows × 7 columns grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 28,
            itemBuilder: (context, index) {
              final day = heatmap[index];
              final rate = day.total == 0 ? 0.0 : day.completed / day.total;

              final Color cellColor;
              if (day.total == 0) {
                cellColor = c.surfaceElevated;
              } else if (rate >= 0.95) {
                cellColor = c.accent;
              } else if (rate >= 0.7) {
                cellColor = c.accent.withValues(alpha: 0.6);
              } else if (rate >= 0.4) {
                cellColor = c.accent.withValues(alpha: 0.3);
              } else if (rate > 0) {
                cellColor = c.accent.withValues(alpha: 0.12);
              } else {
                cellColor = c.surfaceElevated;
              }

              final isToday = index == 27;
              return Container(
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(4),
                  border: isToday
                      ? Border.all(color: c.accent, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${day.date.day}',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: rate >= 0.7
                          ? c.onAccent
                          : c.textDim,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            color: c.textDim,
          ),
        ),
      ],
    );
  }
}

// ── Streak leaderboard ─────────────────────────────────────────

class _StreakLeaderboard extends StatelessWidget {
  final List<HabitStreak> streaks;
  const _StreakLeaderboard({required this.streaks});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final top = streaks.take(8).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACTIVE STREAKS',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 12),
          for (int i = 0; i < top.length; i++) ...[
            _StreakRow(
              rank: i + 1,
              streak: top[i],
              maxStreak: top.first.streak,
            ),
            if (i < top.length - 1)
              Divider(height: 16, color: c.border.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final int rank;
  final HabitStreak streak;
  final int maxStreak;
  const _StreakRow({
    required this.rank,
    required this.streak,
    required this.maxStreak,
  });

  Color _sectionColor(AppPalette c) => switch (streak.habit.section) {
        HabitSection.athletic => c.athletic,
        HabitSection.body => c.body,
        HabitSection.mind => c.mind,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final secColor = _sectionColor(c);
    final barFraction = maxStreak > 0 ? streak.streak / maxStreak : 0.0;

    return Row(
      children: [
        // Rank
        SizedBox(
          width: 20,
          child: Text(
            '$rank',
            style: AppType.numMd.copyWith(
              color: rank <= 3 ? c.amber : c.textDim,
              fontSize: 13,
            ),
          ),
        ),
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: secColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Center(
            child: Icon(
              habitIcon(streak.habit.icon),
              size: 16,
              color: secColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Name + bar
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                streak.habit.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      Container(color: c.surfaceElevated),
                      FractionallySizedBox(
                        widthFactor: barFraction.clamp(0.0, 1.0),
                        child: Container(color: secColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Streak value
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.flame, size: 12, color: c.amber),
            const SizedBox(width: 3),
            Text(
              '${streak.streak}d',
              style: AppType.numMd.copyWith(
                color: c.amber,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

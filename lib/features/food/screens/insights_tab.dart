import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';
import '../providers/weekly_totals_provider.dart';
import '../../../shared/widgets/atlas_error.dart';
import '../../../shared/widgets/atlas_skeleton.dart';

/// Insights surface: 7-day kcal columns, macro distribution donut, slot
/// heatmap, micro flag list, adherence ring. Pure-read over food_logs.
class InsightsTab extends ConsumerWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final days = ref.watch(insightsRangeProvider);
    final weekAsync = ref.watch(rangeTotalsProvider);
    final targets = ref.watch(dailyTargetsProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screenH, 12, AppSpace.screenH, 4),
            child: _RangeToggle(
              value: days,
              onChange: (d) =>
                  ref.read(insightsRangeProvider.notifier).state = d,
            ),
          ),
          Expanded(
            child: weekAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 10, AppSpace.screenH, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    AtlasSkeleton.card(cardHeight: 120),
                    SizedBox(height: 12),
                    AtlasSkeleton.card(cardHeight: 180),
                    SizedBox(height: 12),
                    AtlasSkeleton.card(cardHeight: 140),
                  ],
                ),
              ),
              error: (e, _) => AtlasError(
                error: e,
                title: 'Couldn\'t load insights',
                onRetry: () => ref.invalidate(rangeTotalsProvider),
              ),
              data: (week) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.screenH, 10, AppSpace.screenH, 118),
                  children: [
                    _KeyTakeawaysCard(week: week, targets: targets, days: days),
                    const SizedBox(height: 12),
                    _AdherenceCard(week: week, target: targets.kcal, days: days),
                    const SizedBox(height: 12),
                    _CalorieColumnsCard(week: week, target: targets.kcal),
                    const SizedBox(height: 12),
                    _ProteinCard(week: week, target: targets.proteinG),
                    const SizedBox(height: 12),
                    _MacroDonutCard(week: week),
                    const SizedBox(height: 12),
                    _SlotHeatmapCard(week: week),
                    const SizedBox(height: 12),
                    _MicroFlagsCard(week: week, targets: targets),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 7 / 30 / 90-day segmented selector for the Insights window.
class _RangeToggle extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChange;
  const _RangeToggle({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final d in const [7, 30, 90])
            Expanded(
              child: GestureDetector(
                onTap: () => onChange(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == d ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${d}D',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: value == d ? c.onAccent : c.textMuted,
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

// ── Adherence ring ──────────────────────────────────────────────

class _AdherenceCard extends StatelessWidget {
  final List<DayTotals> week;
  final double target;
  final int days;
  const _AdherenceCard(
      {required this.week, required this.target, required this.days});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final logged = week.where((d) => d.hasLogs).toList();
    int hits = 0;
    for (final d in logged) {
      if (target <= 0) continue;
      final r = d.totals.kcal / target;
      if (r >= 0.85 && r <= 1.15) hits++;
    }
    final loggedCount = logged.length;
    final pct = loggedCount == 0 ? 0.0 : hits / loggedCount;

    return _Card(
      title: 'ADHERENCE · LAST $days DAYS',
      child: Row(
        children: [
          SizedBox(
            width: 88, height: 88,
            child: CustomPaint(
              painter: _RingPainter(
                progress: pct,
                tint: pct >= 0.7 ? c.positive : (pct >= 0.4 ? c.amber : c.negative),
                track: c.surfaceElevated,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(pct * 100).round()}%',
                        style: AppType.numLg.copyWith(color: c.textPrimary, fontSize: 22)),
                    Text('on target',
                        style: AppType.meta.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, 'Days logged', '$loggedCount / $days'),
                const SizedBox(height: 6),
                _kv(context, 'Within ±15% kcal', '$hits days'),
                const SizedBox(height: 6),
                _kv(context, 'Skipped', '${days - loggedCount} days'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext ctx, String k, String v) {
    final c = ctx.c;
    return Row(
      children: [
        Expanded(child: Text(k, style: ctx.t.body.copyWith(color: c.textMuted))),
        Text(v, style: AppType.numMd.copyWith(color: c.textPrimary)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color tint, track;
  _RingPainter({required this.progress, required this.tint, required this.track});
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final r = (size.shortestSide - stroke) / 2;
    final ctr = size.center(Offset.zero);
    canvas.drawCircle(ctr, r,
        Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: ctr, radius: r),
      -math.pi / 2,
      progress.clamp(0, 1) * 2 * math.pi,
      false,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.tint != tint;
}

// ── Calorie columns ─────────────────────────────────────────────

class _CalorieColumnsCard extends StatelessWidget {
  final List<DayTotals> week;
  final double target;
  const _CalorieColumnsCard({required this.week, required this.target});

  @override
  Widget build(BuildContext context) {
    // Bars read well up to two weeks; beyond that switch to a trend line.
    if (week.length > 14) {
      return _CalorieTrendCard(week: week, target: target);
    }
    final c = context.c;
    final maxV = math.max(
        target,
        week.fold<double>(0, (a, d) => math.max(a, d.totals.kcal))) *
        1.15;

    return _Card(
      title: 'CALORIES · LAST ${week.length} DAYS',
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxV <= 0 ? 100 : maxV,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => c.surfaceElevated,
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                getTooltipItem: (group, _, rod, _) {
                  final d = week[group.x];
                  return BarTooltipItem(
                    '${rod.toY.round()} kcal\n',
                    TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: DateFormat('EEE d MMM').format(d.date),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 18,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= week.length) return const SizedBox.shrink();
                    final dow = DateFormat('E').format(week[i].date)[0];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(dow,
                          style: AppType.overline.copyWith(color: c.textMuted)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(horizontalLines: [
              if (target > 0)
                HorizontalLine(
                  y: target,
                  color: c.accent.withValues(alpha: 0.7),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
            ]),
            barGroups: [
              for (int i = 0; i < week.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: week[i].totals.kcal,
                    width: 16,
                    borderRadius: BorderRadius.circular(3),
                    color: _barColor(c, week[i].totals.kcal, target),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Color _barColor(AppPalette c, double v, double t) {
    if (t <= 0 || v <= 0) return c.surfaceElevated;
    final r = v / t;
    if (r > 1.15) return c.negative;
    if (r >= 0.85) return c.accent;
    return c.amber;
  }
}

// ── Calorie trend line (long ranges) ────────────────────────────

class _CalorieTrendCard extends StatelessWidget {
  final List<DayTotals> week;
  final double target;
  const _CalorieTrendCard({required this.week, required this.target});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Plot only logged days so skipped days don't drag the line to zero.
    final spots = <FlSpot>[
      for (int i = 0; i < week.length; i++)
        if (week[i].totals.kcal > 0)
          FlSpot(i.toDouble(), week[i].totals.kcal),
    ];
    final maxV = math.max(
            target, week.fold<double>(0, (a, d) => math.max(a, d.totals.kcal))) *
        1.15;
    final avg = spots.isEmpty
        ? 0.0
        : spots.fold<double>(0, (a, s) => a + s.y) / spots.length;

    return _Card(
      title: 'CALORIE TREND · LAST ${week.length} DAYS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${avg.round()}',
                  style: AppType.numLg.copyWith(color: c.textPrimary, fontSize: 24)),
              const SizedBox(width: 4),
              Text('kcal avg/logged day',
                  style: AppType.meta.copyWith(color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: spots.isEmpty
                ? Center(
                    child: Text('No logs in this window',
                        style: context.t.body.copyWith(color: c.textMuted)))
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (week.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxV <= 0 ? 100 : maxV,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => c.surfaceElevated,
                          getTooltipItems: (spots) => spots.map((s) {
                            final d = week[s.x.toInt()];
                            return LineTooltipItem(
                              '${s.y.round()} kcal\n',
                              TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                              children: [
                                TextSpan(
                                  text: DateFormat('d MMM').format(d.date),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            interval: ((week.length - 1) / 4)
                                .clamp(1, double.infinity),
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= week.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat('d/M').format(week[i].date),
                                  style: AppType.overline
                                      .copyWith(color: c.textMuted, fontSize: 9),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        if (target > 0)
                          HorizontalLine(
                            y: target,
                            color: c.accent.withValues(alpha: 0.6),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                      ]),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.2,
                          color: c.accent,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: c.accent.withValues(alpha: 0.10),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Macro distribution donut ────────────────────────────────────

class _MacroDonutCard extends StatelessWidget {
  final List<DayTotals> week;
  const _MacroDonutCard({required this.week});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    double p = 0, ca = 0, f = 0;
    for (final d in week) {
      p  += d.totals.proteinG;
      ca += d.totals.carbsG;
      f  += d.totals.fatG;
    }
    final pKcal = p * 4, cKcal = ca * 4, fKcal = f * 9;
    final total = pKcal + cKcal + fKcal;
    final pPct = total <= 0 ? 0.0 : pKcal / total;
    final cPct = total <= 0 ? 0.0 : cKcal / total;
    final fPct = total <= 0 ? 0.0 : fKcal / total;
    // Average per *logged* day so skipped days don't deflate the figures.
    final loggedDays = math.max(1, week.where((d) => d.hasLogs).length);

    return _Card(
      title: 'MACRO MIX · AVG / LOGGED DAY',
      child: Row(
        children: [
          SizedBox(
            width: 110, height: 110,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                startDegreeOffset: -90,
                sections: [
                  PieChartSectionData(
                    value: total <= 0 ? 1 : pKcal,
                    color: total <= 0 ? c.surfaceElevated : c.athletic,
                    radius: 22, showTitle: false,
                  ),
                  PieChartSectionData(
                    value: total <= 0 ? 0 : cKcal,
                    color: c.amber,
                    radius: 22, showTitle: false,
                  ),
                  PieChartSectionData(
                    value: total <= 0 ? 0 : fKcal,
                    color: c.mind,
                    radius: 22, showTitle: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(context, 'Protein', pPct, p / loggedDays, c.athletic),
                const SizedBox(height: 8),
                _row(context, 'Carbs', cPct, ca / loggedDays, c.amber),
                const SizedBox(height: 8),
                _row(context, 'Fat', fPct, f / loggedDays, c.mind),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext ctx, String label, double pct, double avgG, Color tint) {
    return Row(
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: ctx.t.bodyStrong)),
        Text('${(pct * 100).round()}%',
            style: AppType.numMd.copyWith(color: tint)),
        const SizedBox(width: 10),
        Text('${avgG.round()}g/d',
            style: AppType.numMd.copyWith(color: ctx.c.textMuted, fontSize: 12)),
      ],
    );
  }
}

// ── Slot heatmap ────────────────────────────────────────────────

class _SlotHeatmapCard extends StatelessWidget {
  final List<DayTotals> week;
  const _SlotHeatmapCard({required this.week});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // A day-by-day grid only stays legible up to ~2 weeks. For longer windows
    // collapse to a per-slot consistency bar.
    if (week.length > 14) {
      return _Card(
        title: 'MEAL CONSISTENCY · WHICH SLOTS YOU LOG',
        child: Column(
          children: [
            for (final slot in kDiarySlotOrder)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(slot.label.toUpperCase(),
                          style:
                              AppType.overline.copyWith(color: c.textMuted)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Stack(
                          children: [
                            Container(height: 7, color: c.surfaceElevated),
                            FractionallySizedBox(
                              widthFactor: week.isEmpty
                                  ? 0.0
                                  : week
                                          .where((d) =>
                                              d.loggedSlots.contains(slot))
                                          .length /
                                      week.length,
                              child: Container(
                                  height: 7,
                                  color: c.accent.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${week.where((d) => d.loggedSlots.contains(slot)).length}/${week.length}',
                        textAlign: TextAlign.right,
                        style: AppType.numMd
                            .copyWith(color: c.textPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return _Card(
      title: 'MEAL ADHERENCE · WHICH SLOTS YOU LOG',
      child: Column(
        children: [
          for (final slot in kDiarySlotOrder)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(slot.label.toUpperCase(),
                        style: AppType.overline.copyWith(color: c.textMuted)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        for (final day in week) ...[
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: day.loggedSlots.contains(slot)
                                      ? c.accent.withValues(alpha: 0.85)
                                      : c.surfaceElevated,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${week.where((d) => d.loggedSlots.contains(slot)).length}',
                      textAlign: TextAlign.right,
                      style: AppType.numMd.copyWith(color: c.textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Micro flags ─────────────────────────────────────────────────

class _MicroFlagsCard extends ConsumerWidget {
  final List<DayTotals> week;
  final dynamic targets; // DailyTargets
  const _MicroFlagsCard({required this.week, required this.targets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final loggedDays = math.max(1, week.where((d) => d.hasLogs).length);
    final flags = _computeFlags(loggedDays);
    return _Card(
      title: 'MICRO FLAGS · LAST ${week.length} DAYS',
      child: flags.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.check, size: 16, color: c.positive),
                  const SizedBox(width: 8),
                  Text('No flags — micros tracking on target.',
                      style: context.t.body.copyWith(color: c.textSecondary)),
                ],
              ),
            )
          : Column(
              children: [
                for (final f in flags)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          f.over ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                          size: 14,
                          color: f.over ? c.negative : c.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${f.label} ${f.over ? 'high' : 'low'}',
                            style: context.t.body,
                          ),
                        ),
                        Text('${f.daysAffected}/$loggedDays days',
                            style: AppType.numMd.copyWith(
                                color: c.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  List<_Flag> _computeFlags(int loggedDays) {
    // Flag a pattern when it affects ~40% of logged days (min 2).
    final threshold = math.max(2, (loggedDays * 0.4).ceil());
    final out = <_Flag>[];
    int sodiumHi = 0, fiberLo = 0, sugarHi = 0, satFatHi = 0;
    int proteinLo = 0;
    for (final d in week) {
      if (!d.hasLogs) continue;
      if (d.totals.sodiumMg > targets.micros.sodiumMg) {
        sodiumHi++;
      }
      if (targets.micros.fiberG > 0 &&
          d.totals.fiberG < targets.micros.fiberG * 0.7) {
        fiberLo++;
      }
      if (d.totals.sugarG > targets.micros.sugarG) {
        sugarHi++;
      }
      if (d.totals.satFatG > targets.micros.satFatG) {
        satFatHi++;
      }
      if (targets.proteinG > 0 &&
          d.totals.proteinG < targets.proteinG * 0.7) {
        proteinLo++;
      }
    }
    if (sodiumHi  >= threshold) out.add(_Flag('Sodium',   true,  sodiumHi));
    if (sugarHi   >= threshold) out.add(_Flag('Sugar',    true,  sugarHi));
    if (satFatHi  >= threshold) out.add(_Flag('Sat fat',  true,  satFatHi));
    if (fiberLo   >= threshold) out.add(_Flag('Fiber',    false, fiberLo));
    if (proteinLo >= threshold) out.add(_Flag('Protein',  false, proteinLo));
    return out;
  }
}

class _Flag {
  final String label;
  final bool over;
  final int daysAffected;
  _Flag(this.label, this.over, this.daysAffected);
}

// ── Key takeaways (narrative insight summary) ───────────────────

class _KeyTakeawaysCard extends StatelessWidget {
  final List<DayTotals> week;
  final dynamic targets; // DailyTargets
  final int days;
  const _KeyTakeawaysCard(
      {required this.week, required this.targets, required this.days});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final logged = week.where((d) => d.hasLogs).toList();
    final n = logged.length;

    if (n == 0) {
      return _Card(
        title: 'KEY TAKEAWAYS',
        child: Row(
          children: [
            Icon(LucideIcons.calendarDays, size: 16, color: c.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Log a few days to unlock your insights.',
                  style: context.t.body.copyWith(color: c.textMuted)),
            ),
          ],
        ),
      );
    }

    final kcalTarget = (targets.kcal as num).toDouble();
    final proteinTarget = (targets.proteinG as num).toDouble();
    final avgKcal =
        logged.fold<double>(0, (a, d) => a + d.totals.kcal) / n;
    final avgProtein =
        logged.fold<double>(0, (a, d) => a + d.totals.proteinG) / n;

    final rows = <Widget>[];

    // 1) Calorie pace.
    final diff = (avgKcal - kcalTarget).round();
    final closeness = kcalTarget <= 0 ? 0.0 : avgKcal / kcalTarget;
    rows.add(_TakeawayRow(
      icon: LucideIcons.flame,
      tone: (closeness >= 0.9 && closeness <= 1.15) ? c.positive : c.amber,
      headline: '${avgKcal.round()} kcal/day on average',
      sub: kcalTarget <= 0
          ? 'Set a calorie target to compare'
          : diff.abs() < 60
              ? 'Right on your ${kcalTarget.round()} kcal target'
              : '${diff.abs()} kcal ${diff < 0 ? 'under' : 'over'} your ${kcalTarget.round()} target',
    ));

    // 2) Protein adherence (athlete priority).
    final pPct = proteinTarget <= 0 ? 0.0 : avgProtein / proteinTarget;
    rows.add(_TakeawayRow(
      icon: LucideIcons.target,
      tone: pPct >= 0.9 ? c.positive : (pPct >= 0.7 ? c.amber : c.negative),
      headline: '${avgProtein.round()}g protein/day',
      sub: proteinTarget <= 0
          ? 'Set a protein target to track adherence'
          : '${(pPct * 100).round()}% of your ${proteinTarget.round()}g goal',
    ));

    // 3) Direction of travel (needs ≥4 logged days).
    if (logged.length >= 4) {
      final mid = logged.length ~/ 2;
      final firstAvg =
          logged.take(mid).fold<double>(0, (a, d) => a + d.totals.kcal) / mid;
      final lastAvg =
          logged.skip(mid).fold<double>(0, (a, d) => a + d.totals.kcal) /
              (logged.length - mid);
      final delta = lastAvg - firstAvg;
      final pctChange = firstAvg <= 0 ? 0 : ((delta / firstAvg) * 100).round();
      if (pctChange.abs() >= 5) {
        final up = delta > 0;
        rows.add(_TakeawayRow(
          icon: up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
          tone: c.textSecondary,
          headline: 'Intake trending ${up ? 'up' : 'down'} ${pctChange.abs()}%',
          sub: 'vs the first half of this window',
        ));
      }
    }

    // 4) Logging consistency.
    final cPct = days == 0 ? 0.0 : n / days;
    rows.add(_TakeawayRow(
      icon: LucideIcons.calendarDays,
      tone: cPct >= 0.8 ? c.positive : (cPct >= 0.5 ? c.amber : c.negative),
      headline: 'Logged $n of $days days',
      sub: '${(cPct * 100).round()}% consistency',
    ));

    return _Card(
      title: 'KEY TAKEAWAYS',
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _TakeawayRow extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String headline, sub;
  const _TakeawayRow({
    required this.icon,
    required this.tone,
    required this.headline,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: tone),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.2,
                  )),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: c.textMuted,
                    height: 1.2,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Protein vs target ───────────────────────────────────────────

class _ProteinCard extends StatelessWidget {
  final List<DayTotals> week;
  final double target;
  const _ProteinCard({required this.week, required this.target});

  Color _barColor(AppPalette c, double v) {
    if (target <= 0 || v <= 0) return c.surfaceElevated;
    final r = v / target;
    if (r >= 0.9) return c.athletic;
    if (r >= 0.6) return c.athletic.withValues(alpha: 0.6);
    return c.amber.withValues(alpha: 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final logged = week.where((d) => d.hasLogs).toList();
    final n = logged.length;
    final avg = n == 0
        ? 0.0
        : logged.fold<double>(0, (a, d) => a + d.totals.proteinG) / n;
    final hitDays = logged
        .where((d) => target > 0 && d.totals.proteinG >= target * 0.9)
        .length;
    final maxV = math.max(target,
            week.fold<double>(0, (a, d) => math.max(a, d.totals.proteinG))) *
        1.15;
    final isLong = week.length > 14;

    return _Card(
      title: 'PROTEIN · LAST ${week.length} DAYS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${avg.round()}',
                  style: AppType.numLg
                      .copyWith(color: c.textPrimary, fontSize: 24)),
              const SizedBox(width: 4),
              Text('g avg/logged day',
                  style: AppType.meta.copyWith(color: c.textMuted)),
              const Spacer(),
              if (n > 0)
                Text('$hitDays/$n on target',
                    style:
                        AppType.numMd.copyWith(color: c.athletic, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: isLong
                ? _line(context, maxV)
                : _bars(context, maxV),
          ),
        ],
      ),
    );
  }

  Widget _bars(BuildContext context, double maxV) {
    final c = context.c;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV <= 0 ? 100 : maxV,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => c.surfaceElevated,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            getTooltipItem: (group, _, rod, _) {
              final d = week[group.x];
              return BarTooltipItem(
                '${rod.toY.round()} g\n',
                TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: DateFormat('EEE d MMM').format(d.date),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= week.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('E').format(week[i].date)[0],
                      style: AppType.overline.copyWith(color: c.textMuted)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (target > 0)
            HorizontalLine(
              y: target,
              color: c.athletic.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
        ]),
        barGroups: [
          for (int i = 0; i < week.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: week[i].totals.proteinG,
                width: 16,
                borderRadius: BorderRadius.circular(3),
                color: _barColor(c, week[i].totals.proteinG),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, double maxV) {
    final c = context.c;
    final spots = <FlSpot>[
      for (int i = 0; i < week.length; i++)
        if (week[i].totals.proteinG > 0)
          FlSpot(i.toDouble(), week[i].totals.proteinG),
    ];
    if (spots.isEmpty) {
      return Center(
        child: Text('No logs in this window',
            style: context.t.body.copyWith(color: c.textMuted)),
      );
    }
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (week.length - 1).toDouble(),
        minY: 0,
        maxY: maxV <= 0 ? 100 : maxV,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.surfaceElevated,
            getTooltipItems: (s) => s.map((spot) {
              final d = week[spot.x.toInt()];
              return LineTooltipItem(
                '${spot.y.round()} g\n',
                TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: DateFormat('d MMM').format(d.date),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: ((week.length - 1) / 4).clamp(1, double.infinity),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= week.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('d/M').format(week[i].date),
                      style: AppType.overline
                          .copyWith(color: c.textMuted, fontSize: 9)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (target > 0)
            HorizontalLine(
              y: target,
              color: c.athletic.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
        ]),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: c.athletic,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: c.athletic.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card chrome ──────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppType.overline.copyWith(color: c.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

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

/// Insights surface: 7-day kcal columns, macro distribution donut, slot
/// heatmap, micro flag list, adherence ring. Pure-read over food_logs.
class InsightsTab extends ConsumerWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final weekAsync = ref.watch(weeklyTotalsProvider);
    final targets = ref.watch(dailyTargetsProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text('Failed to load insights: $e',
              style: context.t.body.copyWith(color: c.negative)),
        ),
        data: (week) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screenH, 14, AppSpace.screenH, 118),
            children: [
              _AdherenceCard(week: week, target: targets.kcal),
              const SizedBox(height: 12),
              _CalorieColumnsCard(week: week, target: targets.kcal),
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
    );
  }
}

// ── Adherence ring ──────────────────────────────────────────────

class _AdherenceCard extends StatelessWidget {
  final List<DayTotals> week;
  final double target;
  const _AdherenceCard({required this.week, required this.target});

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
      title: 'ADHERENCE · LAST 7 DAYS',
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
                _kv(context, 'Days logged', '$loggedCount / 7'),
                const SizedBox(height: 6),
                _kv(context, 'Within ±15% kcal', '$hits days'),
                const SizedBox(height: 6),
                _kv(context, 'Skipped', '${7 - loggedCount} days'),
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
    final c = context.c;
    final maxV = math.max(
        target,
        week.fold<double>(0, (a, d) => math.max(a, d.totals.kcal))) *
        1.15;

    return _Card(
      title: 'CALORIES · LAST 7 DAYS',
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxV <= 0 ? 100 : maxV,
            barTouchData: BarTouchData(enabled: false),
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

    return _Card(
      title: 'MACRO MIX · 7-DAY AVG',
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
                _row(context, 'Protein', pPct, p / 7, c.athletic),
                const SizedBox(height: 8),
                _row(context, 'Carbs', cPct, ca / 7, c.amber),
                const SizedBox(height: 8),
                _row(context, 'Fat', fPct, f / 7, c.mind),
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
    final flags = _computeFlags();
    return _Card(
      title: 'MICRO FLAGS · LAST 7 DAYS',
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
                        Text('${f.daysAffected}/7 days',
                            style: AppType.numMd.copyWith(
                                color: c.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  List<_Flag> _computeFlags() {
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
    if (sodiumHi  >= 3) out.add(_Flag('Sodium',   true,  sodiumHi));
    if (sugarHi   >= 3) out.add(_Flag('Sugar',    true,  sugarHi));
    if (satFatHi  >= 3) out.add(_Flag('Sat fat',  true,  satFatHi));
    if (fiberLo   >= 3) out.add(_Flag('Fiber',    false, fiberLo));
    if (proteinLo >= 3) out.add(_Flag('Protein',  false, proteinLo));
    return out;
  }
}

class _Flag {
  final String label;
  final bool over;
  final int daysAffected;
  _Flag(this.label, this.over, this.daysAffected);
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
        border: Border.all(color: c.border),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_count.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/models/models.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../home/providers/home_providers.dart';
import 'stats_chart.dart';
import 'stats_primitives.dart';

/// PERFORMANCE — the switchable score trend (7/30/90), week-over-week change,
/// and when-you-perform patterns. All read the batched series / analytics, so
/// they share numbers with the rest of the app.
class StatsPerformance extends StatelessWidget {
  const StatsPerformance({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ScoreTrendCard(),
        SizedBox(height: 12),
        _SectionTrendCard(),
        SizedBox(height: 12),
        _WeekCompareCard(),
        SizedBox(height: 12),
        _PatternsCard(),
      ],
    );
  }
}

// ── Score trend (7 / 30 / 90) ──────────────────────────────────
class _ScoreTrendCard extends ConsumerStatefulWidget {
  const _ScoreTrendCard();
  @override
  ConsumerState<_ScoreTrendCard> createState() => _ScoreTrendCardState();
}

class _ScoreTrendCardState extends ConsumerState<_ScoreTrendCard> {
  static const _ranges = [7, 30, 90];
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final async = ref.watch(dailyScoreSeriesProvider(_days));
    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SCORE TREND', style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              StatsRangeToggle(
                labels: const ['7D', '30D', '90D'],
                selected: _ranges.indexOf(_days),
                onChanged: (i) => setState(() => _days = _ranges[i]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          async.when(
            data: (pts) {
              // Only real, scheduled days — skip no-data days so the line shows
              // performance instead of a flat-zero floor then a cliff.
              final past = [for (final p in pts) if (!p.isFuture && p.total > 0) p];
              final avg = past.isEmpty
                  ? 0.0
                  : past.map((p) => p.score).reduce((a, b) => a + b) /
                      past.length;
              return StatsLineChart(
                series: [
                  ChartSeries([for (final p in past) p.score.toDouble()], c.accent,
                      fill: true),
                ],
                dates: [for (final p in past) p.date],
                minY: 0,
                maxY: 100,
                yInterval: 25,
                tooltipValue: (v) => '${v.round()}%',
                goalLine: past.length >= 2 ? avg : null,
                goalColor: c.textMuted,
                goalLabel: 'avg ${avg.round()}',
                emphasizeLast: true,
              );
            },
            loading: () => const ChartSkeleton(),
            error: (_, _) => SizedBox(
              height: 180,
              child: Center(
                  child: Text('Trend unavailable.',
                      style: AppType.meta.copyWith(color: c.textMuted))),
            ),
          ),
        ],
      ),
    );
  }
}

// ── This week vs last ──────────────────────────────────────────
class _WeekCompareCard extends ConsumerWidget {
  const _WeekCompareCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final data = ref.watch(analyticsProvider).valueOrNull;
    if (data == null) {
      return const StatsCard(child: SizedBox(height: 80));
    }
    final delta = (data.weekAvg - data.prevWeekAvg).round();
    final up = delta >= 0;
    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THIS WEEK VS LAST',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCount(data.weekAvg.round(),
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -1,
                  )),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('weekly avg',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted)),
                ),
              ),
              const SizedBox(width: 8),
              _DeltaChip(delta: delta, up: up, suffix: 'vs last wk'),
            ],
          ),
          const SizedBox(height: 14),
          for (final s in HabitSection.values) ...[
            _SectionDeltaRow(
              label: s.label,
              color: s.color(c),
              thisPct: (data.weekSectionAvg[s] ?? 0) * 100,
              lastPct: (data.prevWeekSectionAvg[s] ?? 0) * 100,
            ),
            if (s != HabitSection.values.last) const SizedBox(height: 9),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 2, height: 11, color: c.textMuted),
              const SizedBox(width: 6),
              Text('marker = last week',
                  style: AppType.meta.copyWith(color: c.textDim)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionDeltaRow extends StatelessWidget {
  final String label;
  final Color color;
  final double thisPct;
  final double lastPct;
  const _SectionDeltaRow({
    required this.label,
    required this.color,
    required this.thisPct,
    required this.lastPct,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final delta = (thisPct - lastPct).round();
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary)),
        ),
        Expanded(
          child: _CompareBar(
            thisPct: thisPct.clamp(0, 110),
            lastPct: lastPct.clamp(0, 110),
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 30,
          child: Text('${thisPct.round()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        SizedBox(
          width: 34,
          child: Text(
            delta == 0 ? '·' : (delta > 0 ? '+$delta' : '$delta'),
            textAlign: TextAlign.right,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: delta == 0
                    ? c.textDim
                    : (delta > 0 ? c.positive : c.negative),
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

/// This-week fill with a thin "last week" ghost marker on the same track, so
/// the week-over-week move reads at a glance (not just the +/- number).
class _CompareBar extends StatelessWidget {
  final double thisPct; // 0..110
  final double lastPct;
  final Color color;
  const _CompareBar({
    required this.thisPct,
    required this.lastPct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final lastX = (lastPct / 110).clamp(0.0, 1.0) * w;
      return SizedBox(
        height: 8,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            // Track.
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            // This-week fill.
            TweenAnimationBuilder<double>(
              tween: Tween(end: (thisPct / 110).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            // Last-week ghost marker.
            if (lastPct > 0)
              Positioned(
                left: (lastX - 1).clamp(0.0, w - 2),
                child: Container(width: 2, height: 12, color: c.textMuted),
              ),
          ],
        ),
      );
    });
  }
}

class _DeltaChip extends StatelessWidget {
  final int delta;
  final bool up;
  final String suffix;
  const _DeltaChip({required this.delta, required this.up, required this.suffix});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = delta == 0 ? c.textMuted : (up ? c.positive : c.negative);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          delta == 0
              ? LucideIcons.minus
              : (up ? LucideIcons.trendingUp : LucideIcons.trendingDown),
          size: 13,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          '${delta > 0 ? '+' : ''}$delta $suffix',
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

// ── When you perform (weekday + time of day) ───────────────────
// Two honest, clearly-separated reads: which weekdays you score highest, and
// which scheduled time-of-day slots you actually complete. Empty slots are
// hidden (no more misleading "0% Night"), and a plain headline ties it together.
class _PatternsCard extends ConsumerWidget {
  const _PatternsCard();

  static const _wk = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final data = ref.watch(analyticsProvider).valueOrNull;
    if (data == null) return const StatsCard(child: SizedBox(height: 80));

    // Strongest weekday among those with data.
    final active = data.weekdays.where((w) => w.days > 0).toList();
    WeekdayStat? best;
    for (final w in active) {
      if (best == null || w.avgScore > best.avgScore) best = w;
    }
    final maxWd = active.isEmpty
        ? 1.0
        : active.map((w) => w.avgScore).reduce((a, b) => a > b ? a : b);

    // Only day-parts that actually have scheduled habits — plus best/worst.
    final periods = data.periods.where((p) => p.scheduled > 0).toList();
    final maxRate = periods.isEmpty
        ? 1.0
        : periods.map((p) => p.rate).reduce((a, b) => a > b ? a : b);
    PeriodStat? bestP;
    for (final p in periods) {
      if (bestP == null || p.rate > bestP.rate) bestP = p;
    }

    final headline = best == null
        ? 'Log a few days to reveal your patterns.'
        : 'Strongest on ${_wkFull(best.weekday)}'
            '${bestP != null && periods.length > 1 ? ' · most done ${_periodPhrase(bestP.period)}' : ''}.';

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHEN YOU PERFORM',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 10),
          Text(headline,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: c.textPrimary,
                  height: 1.3)),
          const SizedBox(height: 16),
          Text('AVG SCORE BY DAY',
              style: AppType.meta.copyWith(
                  color: c.textDim, letterSpacing: 0.6, fontSize: 9.5)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final w in data.weekdays)
                Expanded(
                  child: _MiniBar(
                    label: _wk[(w.weekday - 1).clamp(0, 6)],
                    fraction: maxWd <= 0 ? 0 : (w.avgScore / maxWd).clamp(0.0, 1.0),
                    highlight: best != null && w.weekday == best.weekday,
                  ),
                ),
            ],
          ),
          if (periods.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 0.5, color: c.border),
            const SizedBox(height: 12),
            Text('COMPLETED BY TIME OF DAY',
                style: AppType.meta.copyWith(
                    color: c.textDim, letterSpacing: 0.6, fontSize: 9.5)),
            const SizedBox(height: 10),
            for (int i = 0; i < periods.length; i++) ...[
              _PeriodRow(
                p: periods[i],
                fraction:
                    maxRate <= 0 ? 0 : (periods[i].rate / maxRate).clamp(0.0, 1.0),
                best: bestP != null && periods[i].period == bestP.period && periods.length > 1,
              ),
              if (i < periods.length - 1) const SizedBox(height: 9),
            ],
          ],
        ],
      ),
    );
  }

  static String _wkFull(int wd) => const [
        '', 'Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays',
        'Fridays', 'Saturdays', 'Sundays',
      ][wd.clamp(0, 7)];

  static String _periodPhrase(String p) => switch (p) {
        'MORNING' => 'in the morning',
        'AFTERNOON' => 'in the afternoon',
        'EVENING' => 'in the evening',
        _ => 'at night',
      };
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double fraction;
  final bool highlight;
  const _MiniBar({required this.label, required this.fraction, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = highlight ? c.accent : c.textDim;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: fraction.clamp(0.04, 1.0)),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Container(
                  width: 9,
                  height: 54 * v,
                  decoration: BoxDecoration(
                    color: highlight ? color : color.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 10,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? c.textPrimary : c.textDim)),
      ],
    );
  }
}

/// One time-of-day row: label + a completion bar + rate% + the raw count that
/// explains the percentage ("12/31"), so the number is never a mystery.
class _PeriodRow extends StatelessWidget {
  final PeriodStat p;
  final double fraction;
  final bool best;
  const _PeriodRow({required this.p, required this.fraction, required this.best});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = (p.rate * 100).round();
    final color = best ? c.accent : c.textSecondary;
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(_label(p.period),
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: best ? FontWeight.w700 : FontWeight.w600,
                  color: best ? c.textPrimary : c.textSecondary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: c.surfaceElevated,
                valueColor: AlwaysStoppedAnimation(
                    best ? c.accent : c.textMuted.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text('$pct%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text('${p.completed}/${p.scheduled}',
              textAlign: TextAlign.right,
              style: AppType.meta.copyWith(
                  color: c.textDim,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ],
    );
  }

  static String _label(String period) => switch (period) {
        'MORNING' => 'Morning',
        'AFTERNOON' => 'Afternoon',
        'EVENING' => 'Evening',
        _ => 'Night',
      };
}

// ── Per-section trends over time (7 / 30 / 90) ─────────────────
class _SectionTrendCard extends ConsumerStatefulWidget {
  const _SectionTrendCard();
  @override
  ConsumerState<_SectionTrendCard> createState() => _SectionTrendCardState();
}

class _SectionTrendCardState extends ConsumerState<_SectionTrendCard> {
  // 7D is dropped — a 7-day rolling average needs at least a week of history to
  // mean anything.
  static const _ranges = [30, 90];
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final async = ref.watch(sectionTrendProvider(_days));
    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SECTION TRENDS',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              StatsRangeToggle(
                labels: const ['30D', '90D'],
                selected: _ranges.indexOf(_days),
                onChanged: (i) => setState(() => _days = _ranges[i]),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('7-day rolling average',
              style: AppType.meta.copyWith(color: c.textDim)),
          const SizedBox(height: 12),
          async.when(
            data: (t) {
              // Current smoothed value per section → a legend that doubles as a
              // "where each section stands now" readout.
              double curr(HabitSection s) {
                final v = t.series[s];
                return (v == null || v.isEmpty) ? 0 : v.last;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      for (final s in HabitSection.values)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 10,
                            height: 3,
                            decoration: BoxDecoration(
                                color: s.color(c),
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 5),
                          Text(s.label,
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.textSecondary)),
                          const SizedBox(width: 4),
                          Text('${(curr(s) * 100).round()}%',
                              style: TextStyle(
                                  fontFamily: 'SpaceGrotesk',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: s.color(c),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ]),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StatsLineChart(
                    series: [
                      for (final s in HabitSection.values)
                        ChartSeries(
                          [
                            for (final v in t.series[s] ?? const <double>[])
                              v.clamp(0.0, 1.1)
                          ],
                          s.color(c),
                          label: s.label,
                        ),
                    ],
                    dates: t.dates,
                    minY: 0,
                    maxY: 1.0,
                    yInterval: 0.5,
                    yLabel: (v) => '${(v * 100).round()}',
                    tooltipValue: (v) => '${(v * 100).round()}%',
                  ),
                ],
              );
            },
            loading: () => const ChartSkeleton(),
            error: (_, _) => SizedBox(
              height: 180,
              child: Center(
                  child: Text('Trend unavailable.',
                      style: AppType.meta.copyWith(color: c.textMuted))),
            ),
          ),
        ],
      ),
    );
  }
}

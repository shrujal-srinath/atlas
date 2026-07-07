import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../journal/providers/journal_providers.dart';
import 'stats_primitives.dart';

/// WELLNESS — 30-day mood/energy/sleep trends, plus the "do you actually
/// perform better when you sleep well?" correlation. Stats-native (shared
/// StatsCard + Sparkline) so it matches the rest of the dashboard.
class StatsWellness extends StatelessWidget {
  const StatsWellness({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      child: Column(
        children: const [
          _WellnessTrendCard(),
          SizedBox(height: 12),
          _WellnessVsScoreCard(),
        ],
      ),
    );
  }
}

class _WellnessTrendCard extends ConsumerWidget {
  const _WellnessTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final entries = ref.watch(journalLast30Provider).valueOrNull ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.heartPulse, size: 14, color: c.accent),
              const SizedBox(width: 6),
              Text('WELLNESS · 30D',
                  style: AppType.overline.copyWith(color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          _MetricRow(
            icon: LucideIcons.smile,
            label: 'Mood',
            color: c.amber,
            suffix: '/5',
            maxY: 5,
            values: [for (final e in entries) e.mood?.toDouble()],
          ),
          const SizedBox(height: 12),
          _MetricRow(
            icon: LucideIcons.zap,
            label: 'Energy',
            color: c.athletic,
            suffix: '/5',
            maxY: 5,
            values: [for (final e in entries) e.energy?.toDouble()],
          ),
          const SizedBox(height: 12),
          _MetricRow(
            icon: LucideIcons.moon,
            label: 'Sleep',
            color: c.mind,
            suffix: 'h',
            maxY: 12,
            values: [for (final e in entries) e.sleepHours],
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String suffix;
  final double maxY;
  final List<double?> values;
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.suffix,
    required this.maxY,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pts = [for (final v in values) ?v];
    final avg = pts.isEmpty ? null : pts.reduce((a, b) => a + b) / pts.length;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary)),
        ),
        Expanded(
          child: SizedBox(
            height: 28,
            child: pts.length < 2
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text('not enough data',
                        style: AppType.meta.copyWith(color: c.textDim)),
                  )
                : Sparkline(
                    points: pts,
                    color: color,
                    height: 28,
                    minY: 0,
                    maxY: maxY,
                    emphasizeLast: true,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            avg == null ? '—' : '${avg.toStringAsFixed(1)}$suffix',
            textAlign: TextAlign.right,
            style: AppType.numMd.copyWith(color: c.textPrimary, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _WellnessVsScoreCard extends ConsumerWidget {
  const _WellnessVsScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final rows = ref.watch(wellnessVsScoreProvider).valueOrNull ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WELLNESS × SCORE',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 4),
          Text('How you perform on good days vs low days',
              style: AppType.meta.copyWith(color: c.textMuted)),
          const SizedBox(height: 14),
          for (int i = 0; i < rows.length; i++) ...[
            _CorrRow(corr: rows[i]),
            if (i < rows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CorrRow extends StatelessWidget {
  final WellnessCorrelation corr;
  const _CorrRow({required this.corr});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final delta = corr.delta.round();
    final positive = delta >= 0;
    final color = positive ? c.positive : c.negative;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(corr.label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary)),
        ),
        Expanded(
          child: Text(
            positive
                ? 'You score +$delta on good ${corr.label.toLowerCase()} days'
                : 'You score $delta on good ${corr.label.toLowerCase()} days',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${corr.highAvgScore.round()} vs ${corr.lowAvgScore.round()}',
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

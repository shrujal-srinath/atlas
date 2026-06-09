import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/journal_entry.dart';
import '../providers/journal_providers.dart';

/// Analytics block — last 30 days of mood / energy / sleep.
///
/// Drops in anywhere as a sliver child. Skips rendering when there are no
/// entries yet, so an empty journal doesn't leave a blank section behind.
class WellnessTrendSection extends ConsumerWidget {
  const WellnessTrendSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final entries = ref.watch(journalLast30Provider).valueOrNull ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();

    double? avg(double? Function(JournalEntry) pick) {
      final vals = entries.map(pick).whereType<double>().toList();
      if (vals.isEmpty) return null;
      return vals.fold<double>(0, (a, b) => a + b) / vals.length;
    }

    final moodAvg = avg((e) => e.mood?.toDouble());
    final energyAvg = avg((e) => e.energy?.toDouble());
    final sleepAvg = avg((e) => e.sleepHours);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      child: Container(
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
              avg: moodAvg,
              suffix: '/5',
              spark: entries.map((e) => e.mood?.toDouble()).toList(),
              maxY: 5,
            ),
            const SizedBox(height: 10),
            _MetricRow(
              icon: LucideIcons.zap,
              label: 'Energy',
              avg: energyAvg,
              suffix: '/5',
              spark: entries.map((e) => e.energy?.toDouble()).toList(),
              maxY: 5,
            ),
            const SizedBox(height: 10),
            _MetricRow(
              icon: LucideIcons.moon,
              label: 'Sleep',
              avg: sleepAvg,
              suffix: 'h',
              spark: entries.map((e) => e.sleepHours).toList(),
              maxY: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? avg;
  final String suffix;
  final List<double?> spark;
  final double maxY;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.avg,
    required this.suffix,
    required this.spark,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hasData = spark.any((v) => v != null);
    return Row(
      children: [
        Icon(icon, size: 14, color: c.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(label,
              style: AppType.body.copyWith(color: c.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: SizedBox(
            height: 28,
            child: hasData
                ? _Spark(values: spark, color: c.accent, maxY: maxY)
                : Center(
                    child: Text('—',
                        style: AppType.meta.copyWith(color: c.textDim)),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          child: Text(
            avg == null ? '—' : '${avg!.toStringAsFixed(1)}$suffix',
            textAlign: TextAlign.right,
            style: AppType.numMd.copyWith(color: c.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _Spark extends StatelessWidget {
  final List<double?> values;
  final Color color;
  final double maxY;
  const _Spark({required this.values, required this.color, required this.maxY});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 1.6,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

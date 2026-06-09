import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/weight_entry.dart';
import '../providers/weight_providers.dart';

/// Body sub-tab: current weight + 7/30-day deltas, line chart, measurement list.
class BodyTab extends ConsumerWidget {
  const BodyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final weightsAsync = ref.watch(weightLogProvider);
    final measurementsAsync = ref.watch(measurementsProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: weightsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text('Failed to load body data: $e',
              style: context.t.body.copyWith(color: c.negative)),
        ),
        data: (logs) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screenH, 14, AppSpace.screenH, 100),
            children: [
              _CurrentWeightCard(logs: logs),
              const SizedBox(height: 12),
              _WeightChartCard(logs: logs),
              const SizedBox(height: 12),
              measurementsAsync.when(
                data: (m) => _MeasurementsCard(measurements: m),
                loading: () => _MeasurementsCard(measurements: const []),
                error: (_, _) => _MeasurementsCard(measurements: const []),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        heroTag: 'logWeight',
        onPressed: () => _openAddWeight(context, ref),
        icon: const Icon(LucideIcons.scale, size: 18),
        label: const Text('Log weight',
            style:
                TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _openAddWeight(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.background,
      builder: (_) => _AddWeightSheet(
        onSaved: () {
          ref.invalidate(weightLogProvider);
        },
      ),
    );
  }
}

// ── Current weight card ─────────────────────────────────────────

class _CurrentWeightCard extends ConsumerWidget {
  final List<WeightEntry> logs;
  const _CurrentWeightCard({required this.logs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final latest = logs.isEmpty ? null : logs.last;
    final delta7 = ref.watch(weightDeltaProvider(7));
    final delta30 = ref.watch(weightDeltaProvider(30));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('CURRENT WEIGHT',
                  style: AppType.overline.copyWith(
                      color: c.textMuted, letterSpacing: 1.2)),
              const Spacer(),
              if (latest != null)
                Text(
                  'Logged ${DateFormat('MMM d').format(latest.date)}',
                  style: AppType.meta.copyWith(color: c.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latest == null ? '—' : latest.kg.toStringAsFixed(1),
                style: AppType.display.copyWith(
                  color: c.textPrimary,
                  fontSize: 40,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('kg',
                    style: t.h2.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _DeltaTile(label: '7-DAY',  delta: delta7)),
              const SizedBox(width: 10),
              Expanded(child: _DeltaTile(label: '30-DAY', delta: delta30)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaTile extends StatelessWidget {
  final String label;
  final double? delta;
  const _DeltaTile({required this.label, required this.delta});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color tint;
    String value;
    if (delta == null) {
      tint = c.textMuted;
      value = '—';
    } else if (delta!.abs() < 0.05) {
      tint = c.textSecondary;
      value = '0.0';
    } else {
      tint = delta! > 0 ? c.positive : c.amber;
      value = '${delta! > 0 ? '+' : ''}${delta!.toStringAsFixed(1)}';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          Text(label,
              style: AppType.overline.copyWith(color: c.textMuted, letterSpacing: 1.2)),
          const Spacer(),
          Text(value,
              style: AppType.numMd.copyWith(color: tint, fontSize: 16)),
          const SizedBox(width: 3),
          Text('kg', style: AppType.meta.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

// ── Weight chart card ───────────────────────────────────────────

class _WeightChartCard extends StatelessWidget {
  final List<WeightEntry> logs;
  const _WeightChartCard({required this.logs});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (logs.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border),
        ),
        alignment: Alignment.center,
        child: Text('No weight history yet — log to start the chart.',
            style: context.t.body.copyWith(color: c.textMuted)),
      );
    }
    final minKg = logs.map((e) => e.kg).reduce((a, b) => a < b ? a : b);
    final maxKg = logs.map((e) => e.kg).reduce((a, b) => a > b ? a : b);
    final spread = (maxKg - minKg);
    final pad = spread < 1 ? 0.5 : spread * 0.15;

    final firstDate = logs.first.date;
    final spots = [
      for (final w in logs)
        FlSpot(w.date.difference(firstDate).inDays.toDouble(), w.kg),
    ];

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
          Text('WEIGHT · LAST 90 DAYS',
              style: AppType.overline.copyWith(color: c.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: minKg - pad,
                maxY: maxKg + pad,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: c.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: spread < 2 ? 0.5 : (spread / 4).clamp(0.5, 5),
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(spread < 2 ? 1 : 0),
                        style: AppType.meta.copyWith(color: c.textMuted),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: c.accent,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                        radius: 2.5,
                        color: c.accent,
                        strokeWidth: 0,
                      ),
                    ),
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

// ── Measurements card ───────────────────────────────────────────

class _MeasurementsCard extends ConsumerWidget {
  final List<MeasurementEntry> measurements;
  const _MeasurementsCard({required this.measurements});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final byKind = {for (final m in measurements) m.kind: m};
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
              Text('MEASUREMENTS',
                  style: AppType.overline.copyWith(color: c.textMuted, letterSpacing: 1.2)),
              const Spacer(),
              TextButton(
                onPressed: () => _addMeasurement(context, ref),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.plus, size: 13, color: c.accent),
                  const SizedBox(width: 4),
                  Text('Add', style: AppType.bodyStrong.copyWith(color: c.accent)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final kind in MeasurementKind.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(kind.label, style: context.t.body)),
                  if (byKind.containsKey(kind))
                    Text(
                      '${byKind[kind]!.cm.toStringAsFixed(1)} cm',
                      style: AppType.numMd.copyWith(color: c.textPrimary),
                    )
                  else
                    Text('—',
                        style: AppType.numMd.copyWith(color: c.textDim)),
                  const SizedBox(width: 10),
                  if (byKind.containsKey(kind))
                    Text(
                      DateFormat('MMM d').format(byKind[kind]!.date),
                      style: AppType.meta.copyWith(color: c.textMuted),
                    )
                  else
                    const SizedBox(width: 1),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addMeasurement(BuildContext context, WidgetRef ref) async {
    MeasurementKind kind = MeasurementKind.waist;
    final ctl = TextEditingController();
    final result = await showDialog<({MeasurementKind kind, double cm})>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: c.surface,
            title: const Text('Add measurement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MeasurementKind>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Body part'),
                  items: [
                    for (final k in MeasurementKind.values)
                      DropdownMenuItem(value: k, child: Text(k.label)),
                  ],
                  onChanged: (k) => setSt(() => kind = k ?? kind),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Centimetres',
                    suffixText: 'cm',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  final v = double.tryParse(ctl.text.replaceAll(',', '.'));
                  if (v == null || v <= 0) return;
                  Navigator.of(ctx).pop((kind: kind, cm: v));
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
    if (result == null) return;
    final repo = ref.read(weightRepositoryProvider);
    await repo.addMeasurement(kind: result.kind, cm: result.cm);
    ref.invalidate(measurementsProvider);
    HapticFeedback.lightImpact();
  }
}

// ── Add-weight bottom sheet ─────────────────────────────────────

class _AddWeightSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddWeightSheet({required this.onSaved});
  @override
  ConsumerState<_AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends ConsumerState<_AddWeightSheet> {
  final _kg = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        18,
        AppSpace.screenH,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Log weight',
              style: context.t.h2.copyWith(color: c.textPrimary)),
          const SizedBox(height: 14),
          TextField(
            controller: _kg,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weight',
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. post-shower fasted',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final v = double.tryParse(_kg.text.replaceAll(',', '.'));
    if (v == null || v <= 0 || v > 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight in kg')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(weightRepositoryProvider);
      await repo.add(kg: v, note: _note.text.trim().isEmpty ? null : _note.text.trim());
      if (!mounted) return;
      widget.onSaved();
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }
}

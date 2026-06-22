import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/food.dart';
import '../domain/targets.dart';

/// Full-screen drag-up sheet showing all 19 micronutrients with:
///   - %RDA progress bars
///   - Color-coded status (green = on track, amber = low, red = over limit)
///   - Upper-bound nutrients (sodium, cholesterol, sugar, sat fat, trans fat)
///     flagged when *over*, not under.
class MicrosSheet extends StatelessWidget {
  final Nutrients totals;
  final DailyTargets targets;
  const MicrosSheet({super.key, required this.totals, required this.targets});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final m = targets.micros;

    final sections = <(String, List<_NutItem>)>[
      ('MACROS', [
        _NutItem('Protein',  totals.proteinG,  targets.proteinG, 'g'),
        _NutItem('Carbs',    totals.carbsG,    targets.carbsG,   'g'),
        _NutItem('Fat',      totals.fatG,      targets.fatG,     'g'),
        _NutItem('Fiber',    totals.fiberG,    m.fiberG,         'g'),
        _NutItem('Sugar',    totals.sugarG,    m.sugarG,         'g',  upper: true),
        _NutItem('Sat. fat', totals.satFatG,   m.satFatG,        'g',  upper: true),
        _NutItem('Trans fat',totals.transFatG, m.transFatG,      'g',  upper: true),
      ]),
      ('MINERALS', [
        _NutItem('Sodium',    totals.sodiumMg,    m.sodiumMg,    'mg', upper: true),
        _NutItem('Potassium', totals.potassiumMg, m.potassiumMg, 'mg'),
        _NutItem('Calcium',   totals.calciumMg,   m.calciumMg,   'mg'),
        _NutItem('Iron',      totals.ironMg,      m.ironMg,      'mg'),
        _NutItem('Magnesium', totals.magnesiumMg, m.magnesiumMg, 'mg'),
        _NutItem('Zinc',      totals.zincMg,      m.zincMg,      'mg'),
        _NutItem('Cholesterol',totals.cholesterolMg, m.cholesterolMg, 'mg', upper: true),
      ]),
      ('VITAMINS', [
        _NutItem('Vit A',   totals.vitAUg,  m.vitAUg,  'µg'),
        _NutItem('Vit C',   totals.vitCMg,  m.vitCMg,  'mg'),
        _NutItem('Vit D',   totals.vitDUg,  m.vitDUg,  'µg'),
        _NutItem('Vit E',   totals.vitEMg,  m.vitEMg,  'mg'),
        _NutItem('Vit K',   totals.vitKUg,  m.vitKUg,  'µg'),
        _NutItem('B6',      totals.b6Mg,    m.b6Mg,    'mg'),
        _NutItem('B12',     totals.b12Ug,   m.b12Ug,   'µg'),
        _NutItem('Folate',  totals.folateUg, m.folateUg,'µg'),
      ]),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 14, AppSpace.screenH, 6),
              child: Row(
                children: [
                  Expanded(child: Text('Nutrient breakdown', style: t.h2)),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: c.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 6, AppSpace.screenH, 32),
                children: [
                  for (final (header, items) in sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 10),
                      child: Text(header,
                          style: AppType.overline.copyWith(color: c.textMuted)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: c.border, width: 0.5),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            _NutRow(item: items[i]),
                            if (i < items.length - 1)
                              Divider(height: 1, color: c.border),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutItem {
  final String label;
  final double value;
  final double target;
  final String unit;
  final bool upper; // upper-bound nutrient (flag when over, not under)
  const _NutItem(this.label, this.value, this.target, this.unit,
      {this.upper = false});
}

class _NutRow extends StatelessWidget {
  final _NutItem item;
  const _NutRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final pct = item.target <= 0 ? 0.0 : item.value / item.target;
    final status = statusFor(
      value: item.value,
      target: item.target,
      isUpperBound: item.upper,
    );

    final Color barColor;
    final String badge;
    switch (status) {
      case NutrientStatus.under:
        barColor = c.amber;
        badge = 'Low';
      case NutrientStatus.onTrack:
        barColor = c.positive;
        badge = '';
      case NutrientStatus.over:
        barColor = c.negative;
        badge = 'High';
    }

    final pctLabel = item.target > 0 ? '${(pct * 100).round()}%' : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.label, style: t.bodyStrong),
              ),
              if (badge.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: barColor,
                    ),
                  ),
                ),
              Text(
                '${_fmtVal(item.value)} / ${_fmtVal(item.target)} ${item.unit}',
                style: AppType.numMd.copyWith(color: c.textPrimary),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text(
                  pctLabel,
                  textAlign: TextAlign.right,
                  style: AppType.meta.copyWith(
                    color: status == NutrientStatus.onTrack
                        ? c.textMuted
                        : barColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 4, color: c.surfaceElevated),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(height: 4, color: barColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtVal(double v) {
    if (v >= 100) return v.round().toString();
    if (v >= 10) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// One macro row: label, value/target, hairline progress bar.
class MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final String unit;
  final Color? tint;
  final VoidCallback? onTap;

  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    this.unit = 'g',
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final color = tint ?? c.accent;
    final over = target > 0 && value > target;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: t.bodyStrong)),
                Text(
                  '${value.round()} / ${target.round()} $unit',
                  style: AppType.numMd.copyWith(
                    color: over ? c.negative : c.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Stack(
                children: [
                  Container(height: 4, color: c.surfaceElevated),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(height: 4, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

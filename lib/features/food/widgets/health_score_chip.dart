import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/health_score.dart';

/// Compact pill: `87 · WELL FUELED`. Colour bands on the score.
class HealthScoreChip extends StatelessWidget {
  final HealthScore score;

  /// `large` is used in the hero card. `small` fits inside meal section headers.
  final bool large;

  const HealthScoreChip({super.key, required this.score, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (score == HealthScore.empty) {
      return _empty(context);
    }
    final tint = _tint(c, score.value);
    final padH = large ? 10.0 : 7.0;
    final padV = large ? 6.0 : 3.0;
    final numStyle = large ? AppType.numMd : AppType.overline;
    final labelStyle = (large ? AppType.label : AppType.overline)
        .copyWith(color: tint, fontWeight: FontWeight.w700, letterSpacing: 0.6);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: tint.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(score.value.toString(), style: numStyle.copyWith(color: tint)),
          const SizedBox(width: 6),
          Container(width: 1, height: large ? 10 : 8, color: tint.withValues(alpha: 0.35)),
          const SizedBox(width: 6),
          Text(score.label, style: labelStyle),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 7, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.border),
      ),
      child: Text('—', style: AppType.overline.copyWith(color: c.textDim)),
    );
  }

  Color _tint(AppPalette c, int v) {
    if (v >= 85) return c.positive;
    if (v >= 70) return c.accent;
    if (v >= 50) return c.amber;
    return c.negative;
  }
}

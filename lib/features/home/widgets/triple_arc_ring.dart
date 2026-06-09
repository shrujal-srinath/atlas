import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Triple-arc score ring — Athletic (50%) / Building (20%) / Breaking (30%)
/// segments laid out around a hairline track. The center number is animated
/// in lockstep with arc fill.
///
/// Section weights aren't configurable on purpose: they are baked into the
/// HUD's visual language so users learn the geometry.
class TripleArcRing extends StatelessWidget {
  final double score;
  final double athleticPct;
  final double buildingPct;
  final double breakingPct;
  final double size;
  final double centerFontSize;

  const TripleArcRing({
    super.key,
    required this.score,
    required this.athleticPct,
    required this.buildingPct,
    required this.breakingPct,
    this.size = 148,
    this.centerFontSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, animPct, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _TripleArcPainter(
            animProgress: animPct,
            athleticPct: athleticPct,
            buildingPct: buildingPct,
            breakingPct: breakingPct,
            athleticColor: c.athletic,
            buildingColor: c.mind,
            breakingColor: c.body,
            trackColor: c.surfaceElevated,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(score * animPct).round()}',
                  style: AppType.display.copyWith(
                    color: c.textPrimary,
                    fontSize: centerFontSize,
                    height: 1.0,
                  ),
                ),
                Text(
                  '%',
                  style: AppType.h2.copyWith(
                    color: c.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripleArcPainter extends CustomPainter {
  final double animProgress;
  final double athleticPct, buildingPct, breakingPct;
  final Color athleticColor, buildingColor, breakingColor, trackColor;

  _TripleArcPainter({
    required this.animProgress,
    required this.athleticPct,
    required this.buildingPct,
    required this.breakingPct,
    required this.athleticColor,
    required this.buildingColor,
    required this.breakingColor,
    required this.trackColor,
  });

  static const _stroke = 8.0;
  static const _gapRad = 0.04;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - _stroke) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final totalAngle = 2 * math.pi - 3 * _gapRad;
    final sections = <(double, double, double, Color)>[
      (-math.pi / 2, totalAngle * 0.5, athleticPct, athleticColor),
      (-math.pi / 2 + totalAngle * 0.5 + _gapRad, totalAngle * 0.2,
          buildingPct, buildingColor),
      (-math.pi / 2 + totalAngle * 0.7 + 2 * _gapRad, totalAngle * 0.3,
          breakingPct, breakingColor),
    ];

    for (final (start, sweep, fill, color) in sections) {
      if (fill <= 0 || animProgress <= 0) continue;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round;
      final animatedSweep = sweep * fill.clamp(0.0, 1.0) * animProgress;
      if (animatedSweep > 0.01) {
        canvas.drawArc(arcRect, start, animatedSweep, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TripleArcPainter old) =>
      old.animProgress != animProgress ||
      old.athleticPct != athleticPct ||
      old.buildingPct != buildingPct ||
      old.breakingPct != breakingPct;
}

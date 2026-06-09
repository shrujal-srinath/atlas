import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Big calorie ring: consumed vs target, with a status colour.
/// Animates between value changes (400ms easeOutCubic).
///
/// Tint rules:
///   green  — under target by ≥10%
///   accent — on track (90%–105%)
///   amber  — 90%–100%
///   red    — > 105% (overshoot)
class CalorieRing extends StatelessWidget {
  final double consumed;
  final double target;
  final double size;
  final double strokeWidth;

  /// Hide the inner text labels — useful when stacking inside a smaller hero card.
  final bool compact;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 160,
    this.strokeWidth = 10,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final pct = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.25);

    final Color tint;
    if (pct > 1.05) {
      tint = c.negative;
    } else if (pct >= 1.0) {
      tint = c.amber;
    } else if (pct >= 0.9) {
      tint = c.accent;
    } else {
      tint = c.accent;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (_, p, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: p,
                tint: tint,
                track: c.surfaceElevated,
                stroke: strokeWidth,
              ),
            ),
          ),
          if (!compact)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: consumed),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    v.round().toString(),
                    style: AppType.display.copyWith(
                      color: c.textPrimary,
                      fontSize: size >= 150 ? 38 : 28,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('of ${target.round()} kcal',
                    style: t.meta.copyWith(color: c.textMuted)),
              ],
            )
          else
            // Compact: just the number, used inside small home-tab hero
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: consumed),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text(
                v.round().toString(),
                style: AppType.display.copyWith(
                  color: c.textPrimary,
                  fontSize: 22,
                  letterSpacing: -1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0…1
  final Color tint, track;
  final double stroke;
  _RingPainter({required this.progress, required this.tint, required this.track, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centre, radius, trackPaint);

    if (progress <= 0) return;
    final fgPaint = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.tint != tint || old.track != track;
}

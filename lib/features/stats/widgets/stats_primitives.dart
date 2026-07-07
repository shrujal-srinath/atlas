import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pressable_scale.dart';
export '../../../shared/widgets/pressable_scale.dart';

/// Shared building blocks for the Stats dashboard. Centralising these kills the
/// per-screen drift in card decoration, range toggles, and sparklines that made
/// the old Stats/Trends split feel disorganised.

/// The standard stats surface — rounded, hairline-bordered, soft shadow.
/// Replaces the copy-pasted `_cardDeco` so every card matches.
class StatsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const StatsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(onTap: onTap!, child: card);
  }
}

/// A titled divider between dashboard sections — drives the "related info
/// grouped under a heading" rhythm. Optional [trailing] (e.g. a range toggle or
/// a "See all" affordance) sits on the right.
class StatsSectionHeader extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? trailing;
  const StatsSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: c.textSecondary,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!, style: AppType.meta.copyWith(color: c.textMuted)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Segmented pill toggle — the single 7/30/90 (or any labels) range control,
/// generalised from the old per-chart `_ChipToggle`.
class StatsRangeToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color? accent;
  const StatsRangeToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = accent ?? c.accent;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active ? a.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: active
                    ? Border.all(color: a.withValues(alpha: 0.32))
                    : null,
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? a : c.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A compact line sparkline. Auto-fits to the data's own min/max (so per-task
/// values read well), or pass [minY]/[maxY] to pin the scale (e.g. 0–100 for
/// scores). Optional gradient fill + endpoint dot.
class Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final double height;
  final bool fill;
  final bool showDot;
  final double? minY;
  final double? maxY;

  /// Optional dashed horizontal reference line (e.g. a "norm"/avg), in the same
  /// value scale as [points]. Drawn in [baselineColor].
  final double? baseline;
  final Color? baselineColor;

  /// Emphasize the final point with a ringed dot (e.g. "today").
  final bool emphasizeLast;

  /// Draw the line in left → right on first build instead of popping in.
  final bool animate;
  const Sparkline({
    super.key,
    required this.points,
    required this.color,
    this.height = 38,
    this.fill = true,
    this.showDot = true,
    this.minY,
    this.maxY,
    this.baseline,
    this.baselineColor,
    this.emphasizeLast = false,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringBg = context.c.surface;
    _SparkPainter painterFor(double progress) => _SparkPainter(
          points: points,
          color: color,
          fillColor: fill ? color.withValues(alpha: 0.10) : Colors.transparent,
          showDot: showDot,
          minY: minY,
          maxY: maxY,
          baseline: baseline,
          baselineColor: baselineColor,
          emphasizeLast: emphasizeLast,
          ringBg: ringBg,
          progress: progress,
        );
    if (!animate) {
      return SizedBox(
        height: height,
        child: CustomPaint(
            size: Size.fromHeight(height), painter: painterFor(1)),
      );
    }
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, p, _) =>
            CustomPaint(size: Size.fromHeight(height), painter: painterFor(p)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final Color fillColor;
  final bool showDot;
  final double? minY;
  final double? maxY;
  final double? baseline;
  final Color? baselineColor;
  final bool emphasizeLast;
  final Color ringBg;
  final double progress;
  _SparkPainter({
    required this.points,
    required this.color,
    required this.fillColor,
    required this.showDot,
    this.minY,
    this.maxY,
    this.baseline,
    this.baselineColor,
    this.emphasizeLast = false,
    this.ringBg = Colors.white,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final stepX = points.length > 1 ? w / (points.length - 1) : w;
    final hi = maxY ?? points.reduce(math.max);
    final lo = minY ?? points.reduce(math.min);
    final range = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    double yFor(double v) => h - ((v - lo) / range) * h * 0.9 - h * 0.05;
    Offset ptAt(int i) => Offset(i * stepX, yFor(points[i]));

    // Dashed baseline (drawn behind the line).
    if (baseline != null && baseline! >= lo && baseline! <= hi) {
      final by = yFor(baseline!);
      final p = Paint()
        ..color = (baselineColor ?? color).withValues(alpha: 0.5)
        ..strokeWidth = 1;
      const dash = 4.0, gap = 3.0;
      for (double x = 0; x < w; x += dash + gap) {
        canvas.drawLine(Offset(x, by), Offset(math.min(x + dash, w), by), p);
      }
    }

    if (points.length == 1) {
      canvas.drawCircle(Offset(w / 2, h / 2), 3, Paint()..color = color);
      return;
    }

    final line = Path()..moveTo(ptAt(0).dx, ptAt(0).dy);
    for (int i = 1; i < points.length; i++) {
      line.lineTo(ptAt(i).dx, ptAt(i).dy);
    }
    final revealing = progress < 1;
    if (revealing) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, w * progress, h));
    }
    if (fillColor.a > 0) {
      final area = Path.from(line)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(area, Paint()..color = fillColor);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (revealing) canvas.restore();
    if (progress >= 0.999) {
      final last = ptAt(points.length - 1);
      if (emphasizeLast) {
        // A ringed "today" marker: bg halo + colour fill.
        canvas.drawCircle(last, 5, Paint()..color = ringBg);
        canvas.drawCircle(last, 4.5, Paint()..color = color);
        canvas.drawCircle(
            last, 2, Paint()..color = ringBg); // inner dot for a ring look
      } else if (showDot) {
        canvas.drawCircle(last, 3, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.points != points ||
      old.color != color ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.baseline != baseline ||
      old.emphasizeLast != emphasizeLast ||
      old.progress != progress;
}

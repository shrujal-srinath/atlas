import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 7-day mini line chart. Tinted to a macro colour, with a 1px dashed
/// target line. Hand-painted to stay lean (no fl_chart dependency for this
/// 28-px widget). Caller passes oldest → newest values + a target.
class MacroSparkline extends StatelessWidget {
  final List<double> values;
  final double target;
  final Color tint;
  final double height;

  const MacroSparkline({
    super.key,
    required this.values,
    required this.target,
    required this.tint,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    final c = context.c;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(
          values: values,
          target: target,
          tint: tint,
          track: c.border,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final double target;
  final Color tint;
  final Color track;
  _SparkPainter({
    required this.values,
    required this.target,
    required this.tint,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final w = size.width, h = size.height;
    final maxV = [target, ...values].reduce((a, b) => a > b ? a : b);
    final scaleY = maxV <= 0 ? 0.0 : (h - 4) / maxV;

    // Dashed target line.
    if (target > 0 && maxV > 0) {
      final ty = h - (target * scaleY) - 2;
      final paint = Paint()
        ..color = track
        ..strokeWidth = 1;
      const dash = 3.0, gap = 3.0;
      double x = 0;
      while (x < w) {
        canvas.drawLine(Offset(x, ty), Offset(x + dash, ty), paint);
        x += dash + gap;
      }
    }

    // Sparkline.
    final path = Path();
    final step = values.length <= 1 ? 0.0 : w / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final x = i * step;
      final y = h - (values[i] * scaleY) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final line = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);

    // Last-point dot.
    final lastX = (values.length - 1) * step;
    final lastY = h - (values.last * scaleY) - 2;
    canvas.drawCircle(Offset(lastX, lastY), 2.5, Paint()..color = tint);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.target != target || old.tint != tint;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The STRIDE brand mark, alive: a ruby "score-ring" that sweeps continuously
/// around a static Space Grotesk "S" — the exact identity carried by the
/// launcher icon and native splash. Shown on the launch splash and the sign-in
/// hand-off so the first thing the user ever sees is the brand, not a generic
/// Material spinner. Colours are injected so it can live in both the themed
/// app (AppPalette) and the self-contained auth design system (AuthColors).
class BrandSpinner extends StatefulWidget {
  final double size;
  final Color ring; // ruby sweep
  final Color track; // faint full ring behind the sweep
  final Color letter; // the centred "S"
  const BrandSpinner({
    super.key,
    this.size = 76,
    required this.ring,
    required this.track,
    required this.letter,
  });

  @override
  State<BrandSpinner> createState() => _BrandSpinnerState();
}

class _BrandSpinnerState extends State<BrandSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(t: _c.value, ring: widget.ring, track: widget.track),
          child: child,
        ),
        child: Center(
          child: Text(
            'S',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: widget.size * 0.40,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: widget.letter,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t; // 0..1 rotation phase
  final Color ring;
  final Color track;
  _RingPainter({required this.t, required this.ring, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.055;
    final rect =
        Offset(stroke / 2 + 1, stroke / 2 + 1) &
        Size(size.width - stroke - 2, size.height - stroke - 2);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    // ~280° ruby arc (echoes the icon's top gap) rotating around the "S".
    final sweep = 2 * math.pi * 0.78;
    final start = 2 * math.pi * t - math.pi / 2;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.t != t || old.ring != ring || old.track != track;
}

part of 'home_screen.dart';

class _ScoreBlock extends StatelessWidget {
  final _DayVM day;
  final VoidCallback onTap;
  const _ScoreBlock({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Card(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 116,
            height: 116,
            child: CustomPaint(
              painter: _TripleArcPainter(
                values: [
                  day.cats['ATH']! / 100,
                  day.cats['MIND']! / 100,
                  day.cats['BODY']! / 100,
                ],
                colors: [c.athletic, c.mind, c.body],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${day.score}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.8,
                        color: c.textPrimary,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const _Overline('Score'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _Overline('Standing'),
                    const Spacer(),
                    Text(
                      'proj 84%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, size: 15, color: c.textMuted),
                  ],
                ),
                const SizedBox(height: 9),
                _catRow(context, 'ATH', day.cats['ATH']!),
                const SizedBox(height: 8),
                _catRow(context, 'MIND', day.cats['MIND']!),
                const SizedBox(height: 8),
                _catRow(context, 'BODY', day.cats['BODY']!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MicroPill(
                      text: '${day.done}/${day.total} done',
                      color: c.textMuted,
                    ),
                    const SizedBox(width: 6),
                    _MicroPill(
                      icon: LucideIcons.flame,
                      text: '3d',
                      color: c.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catRow(BuildContext context, String key, int pct) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _catColor(context, key),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _catName(key),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
              height: 1.0,
            ),
          ),
        ),
        Text(
          '$pct%',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _TripleArcPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _TripleArcPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 42.0;
    const segAng = 120.0;
    const gap = 22.0;
    final fullSweep = (segAng - gap) * math.pi / 180;

    for (int i = 0; i < values.length; i++) {
      final rotDeg = -90 + i * segAng + gap / 2;
      final startRad = rotDeg * math.pi / 180;
      final filledSweep = fullSweep * values[i].clamp(0.0, 1.0);

      final trackPaint = Paint()
        ..color = colors[i].withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startRad,
        fullSweep,
        false,
        trackPaint,
      );

      if (filledSweep > 0) {
        final fillPaint = Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          startRad,
          filledSweep,
          false,
          fillPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TripleArcPainter old) =>
      old.values != values || old.colors != colors;
}

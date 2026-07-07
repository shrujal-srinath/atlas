part of 'home_screen.dart';

class _FuelCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _FuelCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final totals = ref.watch(diaryTotalsProvider);
    final targets = ref.watch(dailyTargetsProvider);
    final waterMl = ref.watch(waterIntakeProvider).valueOrNull ?? 0;
    final waterTargetMl = ref.watch(waterTargetProvider);
    final phase = ref.watch(bodyPhaseProvider);

    final kcal = totals.kcal.round();
    final kgoal = targets.kcal.round() == 0 ? 3000 : targets.kcal.round();
    final macros = [
      ('Protein', totals.proteinG.round(), targets.proteinG.round(), c.body),
      ('Carbs', totals.carbsG.round(), targets.carbsG.round(), c.mind),
      ('Fat', totals.fatG.round(), targets.fatG.round(), c.athletic),
    ];

    // Phase-aware delta + tone matching the diary hero card semantics.
    final delta = _fuelDelta(phase, kcal: kcal, kgoal: kgoal);

    return _Card(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(kcal),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: c.textPrimary,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  '/ ${_fmt(kgoal)} kcal',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                    height: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              _FuelPhasePill(phase: phase),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.fromLTRB(9, 4, 7, 4),
                decoration: BoxDecoration(
                  color: _fuelDeltaTint(c, delta.tone).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      delta.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _fuelDeltaTint(c, delta.tone),
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight,
                        size: 13, color: c.textMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _fuelPaceHint(phase, kcal: kcal, kgoal: kgoal),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: c.textMuted,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 9),
          // Macro bar + chips, full-width now that water has its own row.
          SizedBox(
            height: 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Row(
                children: [
                  for (final m in macros) ...[
                    Expanded(
                      flex: ((m.$2 / kgoal) * 4 * 1000).round().clamp(1, 1 << 20),
                      child: Container(color: m.$4),
                    ),
                    const SizedBox(width: 2),
                  ],
                  Expanded(
                    flex: ((1 - kcal / kgoal) * 1.2 * 1000).round().clamp(1, 1 << 20),
                    child: Container(color: c.surfaceElevated),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < macros.length; i++) ...[
                Expanded(child: _macroMini(context, macros[i])),
                if (i < macros.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          // Hairline divider before the hydration row.
          const SizedBox(height: 10),
          Container(height: 0.5, color: c.border),
          const SizedBox(height: 10),
          _FuelWaterRow(
            waterMl: waterMl,
            waterTargetMl: waterTargetMl,
          ),
        ],
      ),
    );
  }

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  Widget _macroMini(BuildContext context, (String, int, int, Color) m) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: m.$4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              m.$1,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${m.$2}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
            Text(
              '/${m.$3}g',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Phase-aware delta + tone for the fuel-card calorie pill.
enum _FuelTone { positive, warn, negative, neutral }

class _FuelDelta {
  final String label;
  final _FuelTone tone;
  const _FuelDelta(this.label, this.tone);
}

_FuelDelta _fuelDelta(BodyPhase phase, {required int kcal, required int kgoal}) {
  final remaining = kgoal - kcal;
  switch (phase) {
    case BodyPhase.bulk:
      if (kcal < kgoal) return _FuelDelta('+$remaining to go', _FuelTone.warn);
      final over = kcal - kgoal;
      return _FuelDelta('+$over surplus', _FuelTone.positive);
    case BodyPhase.cut:
      if (kcal <= kgoal) return _FuelDelta('$remaining left', _FuelTone.positive);
      final over = kcal - kgoal;
      return _FuelDelta('-$over over', _FuelTone.negative);
    case BodyPhase.maintain:
      if (kcal <= kgoal) return _FuelDelta('$remaining left', _FuelTone.neutral);
      final over = kcal - kgoal;
      return _FuelDelta('-$over over', _FuelTone.warn);
  }
}

Color _fuelDeltaTint(AppPalette c, _FuelTone t) {
  return switch (t) {
    _FuelTone.positive => c.accent,
    _FuelTone.warn => c.amber,
    _FuelTone.negative => c.negative,
    _FuelTone.neutral => c.textSecondary,
  };
}

String _fuelPaceHint(BodyPhase phase, {required int kcal, required int kgoal}) {
  final phaseLabel = switch (phase) {
    BodyPhase.bulk => 'Bulk',
    BodyPhase.cut => 'Cut',
    BodyPhase.maintain => 'Maintain',
  };
  if (kgoal <= 0) return phaseLabel;
  final now = DateTime.now();
  final minsIntoDay = now.hour * 60 + now.minute;
  // Linear waking pace: 7am → 11pm. Outside that window, fall back to ratio.
  const wakeStartMin = 7 * 60;
  const wakeEndMin = 23 * 60;
  final wakingFrac = minsIntoDay <= wakeStartMin
      ? 0.0
      : minsIntoDay >= wakeEndMin
          ? 1.0
          : (minsIntoDay - wakeStartMin) / (wakeEndMin - wakeStartMin);
  final expected = (kgoal * wakingFrac).round();
  if (expected == 0) {
    return '$phaseLabel · day just starting';
  }
  final diff = kcal - expected;
  if (diff.abs() <= (kgoal * 0.05)) {
    return '$phaseLabel · on pace';
  }
  if (diff > 0) {
    return '$phaseLabel · ${diff.abs()} ahead of pace';
  }
  return '$phaseLabel · ${diff.abs()} behind pace';
}

class _FuelPhasePill extends StatelessWidget {
  final BodyPhase phase;
  const _FuelPhasePill({required this.phase});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, color) = switch (phase) {
      BodyPhase.bulk => ('BULK', c.athletic),
      BodyPhase.cut => ('CUT', c.mind),
      BodyPhase.maintain => ('KEEP', c.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Hydration row that lives inside the Fuel card. Tap the `+250 ml` pill to
/// log a glass; long-press for a custom-volume dialog. The bar + label tap
/// falls through to the parent _Card's onTap (→ /food).
class _FuelWaterRow extends ConsumerWidget {
  final int waterMl;
  final int waterTargetMl;
  const _FuelWaterRow({required this.waterMl, required this.waterTargetMl});

  String _fmtLiters(int ml) => fmtLiters(ml); // accurate, no misleading rounding

  Future<void> _addWater(WidgetRef ref, int ml) async {
    HapticFeedback.selectionClick();
    await addWaterIntake(ref, ml); // one path: handles dev-mode + refresh
  }

  Future<void> _promptCustom(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ml = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Custom volume', style: ctx.t.h2),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: ctx.t.body,
            decoration: InputDecoration(
              hintText: 'ml',
              suffixText: 'ml',
              suffixStyle: AppType.meta.copyWith(color: c.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (ml != null && ml > 0) await _addWater(ref, ml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final target = waterTargetMl <= 0 ? 3500 : waterTargetMl;
    final pct = (waterMl / target).clamp(0.0, 1.0);
    return Row(
      children: [
        Icon(LucideIcons.droplet, size: 13, color: c.mind),
        const SizedBox(width: 7),
        Text(
          '${_fmtLiters(waterMl)} / ${_fmtLiters(target)} L',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: c.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(c.mind),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _WaterAddBtn(
          onTap: () => _addWater(ref, 250),
          onLongPress: () => _promptCustom(context, ref),
        ),
      ],
    );
  }
}

/// Pill button for `+250 ml` (tap) / custom volume (long-press). Opaque
/// hit-test so the parent card's onTap (route to /food) isn't also triggered.
/// Press-scales + deepens on touch so a high-frequency action feels tactile.
class _WaterAddBtn extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _WaterAddBtn({required this.onTap, required this.onLongPress});

  @override
  State<_WaterAddBtn> createState() => _WaterAddBtnState();
}

class _WaterAddBtnState extends State<_WaterAddBtn> {
  bool _down = false;
  void _set(bool v) {
    if (v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          // Larger tap target (≈34px tall) for a frequently-used control.
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: c.mind.withValues(alpha: _down ? 0.24 : 0.15),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
                color: c.mind.withValues(alpha: 0.40), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus, size: 13, color: c.mind),
              const SizedBox(width: 5),
              Text(
                '250 ml',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.mind,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter({
    required this.pct,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final trackP = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, trackP);

    if (pct > 0) {
      final p = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        2 * math.pi * pct,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.pct != pct || old.color != color;
}

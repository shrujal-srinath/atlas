import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/atlas_controls.dart';

/// A tiny first-run "where do I make a habit?" coach-mark. Two beats:
///   1. spotlight the center `+` button,
///   2. spotlight the "Habit" tile inside the quick-add sheet.
/// Armed once when onboarding completes; never persisted (an already-onboarded
/// user is never armed). See `CoachmarkLayer` for the visual.
enum HabitGuideStep { off, fab, habitTile }

class HabitGuideController extends StateNotifier<HabitGuideStep> {
  HabitGuideController() : super(HabitGuideStep.off);

  /// Begin the guide on the center `+`.
  void start() => state = HabitGuideStep.fab;

  /// Move on to the "Habit" tile once the quick-add sheet is open.
  void advanceToTile() => state = HabitGuideStep.habitTile;

  /// End the guide (finished or skipped).
  void dismiss() => state = HabitGuideStep.off;
}

final habitGuideProvider =
    StateNotifierProvider<HabitGuideController, HabitGuideStep>(
      (ref) => HabitGuideController(),
    );

/// Attached to the center `+` (`_CenterFab`) and the quick-add "Habit" tile so
/// the spotlight can measure their on-screen rect.
final habitGuideFabKey = GlobalKey();
final habitGuideHabitTileKey = GlobalKey();

/// A reusable spotlight overlay: dims everything, punches a soft hole over the
/// [targetKey] widget (which stays tappable), pulses an accent ring, and floats
/// a tooltip card with step dots + a Skip link. Drop it as the top child of a
/// full-bleed [Stack] that sits over the screen / sheet you want to coach.
class CoachmarkLayer extends StatefulWidget {
  final GlobalKey targetKey;
  final String title;
  final String body;
  final int stepIndex; // 0-based
  final int stepCount;
  final VoidCallback onSkip;

  /// Circular hole (for the round FAB) vs a rounded-rect hole (for a tile).
  final bool circular;
  final double cutoutPadding;
  final double cutoutRadius;

  const CoachmarkLayer({
    super.key,
    required this.targetKey,
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.stepCount,
    required this.onSkip,
    this.circular = false,
    this.cutoutPadding = 8,
    this.cutoutRadius = 18,
  });

  @override
  State<CoachmarkLayer> createState() => _CoachmarkLayerState();
}

class _CoachmarkLayerState extends State<CoachmarkLayer>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _entrance;
  Rect? _hole; // in this layer's local coordinates, already padded
  Rect? _pendingRect; // last measured rect, awaiting a stable confirmation
  int _settleFrames = 0; // frames spent watching the target settle

  static const _scrim = Color(0xB3000000); // ~70% black

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measure();
      HapticFeedback.lightImpact();
    });
  }

  @override
  void didUpdateWidget(CoachmarkLayer old) {
    super.didUpdateWidget(old);
    if (old.targetKey != widget.targetKey) {
      _hole = null;
      _pendingRect = null;
      _settleFrames = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  /// Measure the target's rect in this layer's local space, but only *lock* it
  /// once it's stable across two consecutive frames and fully on-screen. During
  /// the onboarding→home route transition the FAB is still settling, so a single
  /// post-frame read can capture a transient/off-screen position — which is what
  /// pushed the tooltip off the bottom of the screen. We keep watching for a
  /// short window so the spotlight always lands on the settled target.
  void _measure() {
    if (!mounted) return;
    final selfBox = context.findRenderObject() as RenderBox?;
    final targetBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    final ready =
        selfBox != null &&
        selfBox.hasSize &&
        targetBox != null &&
        targetBox.hasSize;
    if (ready) {
      final size = selfBox.size;
      final topLeft = selfBox.globalToLocal(
        targetBox.localToGlobal(Offset.zero),
      );
      final rect = (topLeft & targetBox.size).inflate(widget.cutoutPadding);
      final ctr = rect.center;
      final onScreen =
          ctr.dx >= 0 &&
          ctr.dx <= size.width &&
          ctr.dy >= 0 &&
          ctr.dy <= size.height;
      if (onScreen) {
        if (_pendingRect == rect && _hole != rect) {
          setState(() => _hole = rect);
          _entrance.forward();
        }
        _pendingRect = rect;
      }
    }
    _settleFrames++;
    // Watch ~1.5s of frames so we track the target through the transition; once
    // locked and stable this is a cheap no-op each frame, then it stops.
    if (_settleFrames < 90) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hole = _hole;
    if (hole == null) return const SizedBox.expand();
    final radius = widget.circular
        ? hole.shortestSide / 2
        : widget.cutoutRadius;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final mq = MediaQuery.of(context);
        final safeTop = mq.viewPadding.top + 10;
        final safeBottom = mq.viewPadding.bottom + 10;
        // Place the tooltip on whichever side of the target has more room, and
        // never let it overlap the hole, run off-screen, or hide under the
        // status bar / gesture nav.
        final roomAbove = hole.top - safeTop;
        final roomBelow = size.height - hole.bottom - safeBottom;
        final placeBelow = roomBelow >= roomAbove;
        final maxH = ((placeBelow ? roomBelow : roomAbove) - 12).clamp(
          96.0,
          size.height,
        );

        return Stack(
          children: [
            // 1 ── Dimming scrim with the hole, fading in. Non-interactive.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_entrance, _pulse]),
                  builder: (_, _) => CustomPaint(
                    painter: _SpotlightPainter(
                      hole: hole,
                      radius: radius,
                      scrim: _scrim.withValues(alpha: 0.70 * _entrance.value),
                      ringColor: context.c.accent,
                      pulse: _pulse.value,
                    ),
                  ),
                ),
              ),
            ),
            // 2 ── Absorb taps everywhere *except* the hole, so the real target
            //      stays tappable and stray taps don't hit the screen behind.
            ..._absorbers(size, hole),
            // 3 ── Tooltip card, placed on the roomier side of the target and
            //      clamped fully on-screen.
            Positioned(
              left: 16,
              right: 16,
              top: placeBelow ? hole.bottom + 12 : null,
              bottom: placeBelow ? null : (size.height - hole.top + 12),
              child: FadeTransition(
                opacity: _entrance,
                child: ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _entrance,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  alignment: placeBelow
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxH),
                    child: _CoachTooltip(
                      title: widget.title,
                      body: widget.body,
                      stepIndex: widget.stepIndex,
                      stepCount: widget.stepCount,
                      pointerDown: !placeBelow,
                      pointerDx: hole.center.dx - 16,
                      onSkip: widget.onSkip,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Four transparent tap-absorbers framing the hole (top/bottom/left/right).
  List<Widget> _absorbers(Size size, Rect hole) {
    Widget block(double l, double t, double w, double h) => Positioned(
      left: l,
      top: t,
      width: w.clamp(0, size.width),
      height: h.clamp(0, size.height),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // swallow — Skip is the explicit dismissal
      ),
    );
    return [
      block(0, 0, size.width, hole.top),
      block(0, hole.bottom, size.width, size.height - hole.bottom),
      block(0, hole.top, hole.left, hole.height),
      block(hole.right, hole.top, size.width - hole.right, hole.height),
    ];
  }
}

/// Paints the dimming scrim with a cleared rounded hole, plus an expanding,
/// fading ring around the hole for a gentle "look here" pulse.
class _SpotlightPainter extends CustomPainter {
  final Rect hole;
  final double radius;
  final Color scrim;
  final Color ringColor;
  final double pulse; // 0..1

  _SpotlightPainter({
    required this.hole,
    required this.radius,
    required this.scrim,
    required this.ringColor,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, Radius.circular(radius));
    // Dim everything, then clear the hole.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = scrim);
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Expanding ring (one continuous loop).
    final grow = Curves.easeOut.transform(pulse);
    final ringAlpha = (1.0 - pulse).clamp(0.0, 1.0) * 0.55;
    final inflated = hole.inflate(4 + grow * 14);
    final ringRRect = RRect.fromRectAndRadius(
      inflated,
      Radius.circular(radius + 4 + grow * 14),
    );
    canvas.drawRRect(
      ringRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ringColor.withValues(alpha: ringAlpha),
    );
    // A steady inner hairline so the target always reads as "active".
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole.inflate(1.5), Radius.circular(radius + 1.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ringColor.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole ||
      old.pulse != pulse ||
      old.scrim != scrim ||
      old.radius != radius;
}

/// The floating instruction card: step dots, title, body, a Skip link, and a
/// small triangle pointer toward the spotlighted target.
class _CoachTooltip extends StatelessWidget {
  final String title;
  final String body;
  final int stepIndex;
  final int stepCount;
  final bool pointerDown; // pointer at the bottom (card sits above target)
  final double pointerDx; // x of the pointer within the 16-inset band
  final VoidCallback onSkip;

  const _CoachTooltip({
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.stepCount,
    required this.pointerDown,
    required this.pointerDx,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final pointer = CustomPaint(
      size: const Size(20, 9),
      painter: _PointerPainter(
        color: c.surface,
        down: pointerDown,
        border: c.border,
      ),
    );
    // Keep the pointer under the target but inside the card's rounded ends.
    final pointerAlign = Align(
      alignment: Alignment(
        ((pointerDx / (MediaQuery.of(context).size.width - 32)).clamp(
                  0.08,
                  0.92,
                ) *
                2) -
            1,
        0,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: pointer,
      ),
    );

    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Step dots.
              Row(
                children: List.generate(stepCount, (i) {
                  final on = i == stepIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 5),
                    width: on ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: on ? c.accent : c.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const Spacer(),
              PressScale(
                scale: 0.95,
                onTap: onSkip,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Text(
                    'Skip',
                    style: t.meta.copyWith(
                      color: c.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: t.bodyStrong.copyWith(fontSize: 16)),
          const SizedBox(height: 3),
          Text(
            body,
            style: t.body.copyWith(color: c.textSecondary, height: 1.35),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!pointerDown) pointerAlign,
        card,
        if (pointerDown) pointerAlign,
      ],
    );
  }
}

/// A small filled triangle (with a hairline edge) that points up or down.
class _PointerPainter extends CustomPainter {
  final Color color;
  final Color border;
  final bool down;
  _PointerPainter({
    required this.color,
    required this.border,
    required this.down,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (down) {
      p.moveTo(0, 0);
      p.lineTo(size.width, 0);
      p.lineTo(size.width / 2, size.height);
    } else {
      p.moveTo(size.width / 2, 0);
      p.lineTo(size.width, size.height);
      p.lineTo(0, size.height);
    }
    p.close();
    canvas.drawShadow(p, Colors.black.withValues(alpha: 0.18), 3, false);
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter old) =>
      old.color != color || old.down != down;
}

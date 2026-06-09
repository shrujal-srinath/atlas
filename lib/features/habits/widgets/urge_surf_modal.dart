import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../providers/habit_provider.dart';

/// Outcomes returned to the caller.
enum UrgeOutcome {
  /// Made it through — log as `completed=true, urge_only=true`
  /// (counts the streak but earns no XP).
  surfed,

  /// Gave in — log as `completed=false`.
  gaveIn,

  /// Cancelled the timer without choosing.
  dismissed,
}

/// 5-min urge-surf timer for breaking habits. Returns an [UrgeOutcome] and
/// writes the corresponding habit_log if [persistOutcome] is true.
Future<UrgeOutcome> showUrgeSurfModal(
  BuildContext context, {
  required Habit habit,
  required String dateStr,
  Duration duration = const Duration(minutes: 5),
  bool persistOutcome = true,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final result = await showModalBottomSheet<UrgeOutcome>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _UrgeSurfSheet(
      habit: habit,
      duration: duration,
    ),
  );
  final outcome = result ?? UrgeOutcome.dismissed;

  if (persistOutcome && outcome != UrgeOutcome.dismissed) {
    await container.read(habitActionsProvider.notifier).toggleHabit(
          habit.id,
          dateStr,
          completed: outcome == UrgeOutcome.surfed,
          urgeOnly: outcome == UrgeOutcome.surfed,
          triggerTag: null,
        );
  }

  return outcome;
}

class _UrgeSurfSheet extends ConsumerStatefulWidget {
  final Habit habit;
  final Duration duration;

  const _UrgeSurfSheet({required this.habit, required this.duration});

  @override
  ConsumerState<_UrgeSurfSheet> createState() => _UrgeSurfSheetState();
}

class _UrgeSurfSheetState extends ConsumerState<_UrgeSurfSheet>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  Timer? _timer;

  late Duration _remaining;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _finished = true;
          _timer?.cancel();
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final progress =
        1 - (_remaining.inMilliseconds / widget.duration.inMilliseconds);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        16,
        AppSpace.screenH,
        MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _finished ? 'You did it.' : 'Urge surf · ${widget.habit.name}',
            style: t.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _finished
                ? 'The wave passed. How did you ride it?'
                : 'Breathe with the ring. The urge peaks fast and falls.',
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: _BreathingRing(
              breath: _breath,
              progress: progress,
              accent: c.accent,
              ring: c.borderStrong,
              child: Text(
                _fmt(_remaining),
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!_finished)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(LucideIcons.x, size: 16, color: c.textSecondary),
                    label: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, UrgeOutcome.dismissed),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(LucideIcons.zap, size: 16, color: c.amber),
                    label: Text(
                      'I gave in',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: c.amber,
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, UrgeOutcome.gaveIn),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.amber.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(LucideIcons.zap, size: 16, color: c.amber),
                    label: Text(
                      'I gave in',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: c.amber,
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, UrgeOutcome.gaveIn),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.amber.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(LucideIcons.check, size: 16, color: c.onAccent),
                    label: Text(
                      'I surfed it',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: c.onAccent,
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(context, UrgeOutcome.surfed),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BreathingRing extends StatelessWidget {
  final AnimationController breath;
  final double progress;
  final Color accent;
  final Color ring;
  final Widget child;

  const _BreathingRing({
    required this.breath,
    required this.progress,
    required this.accent,
    required this.ring,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breath,
      builder: (_, _) {
        final scale = 0.92 + (breath.value * 0.08);
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            painter: _RingPainter(
              progress: progress,
              accent: accent,
              ring: ring,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color ring;

  _RingPainter({
    required this.progress,
    required this.accent,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;

    final bg = Paint()
      ..color = ring.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.accent != accent || old.ring != ring;
}

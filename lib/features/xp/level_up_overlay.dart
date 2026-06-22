import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/dev/dev_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import 'leveling_providers.dart';
import 'prereq_providers.dart';
import 'rank_tier.dart';

/// Mounted near the app root. When the dual gate passes (XP threshold AND
/// every milestone for the next transition), this widget *confirms* the
/// level-up — persisting `users.confirmed_level` — then pops the celebratory
/// burst, writes a `notifications` row, and pushes the milestone picker for
/// the next chapter. Because confirmation recomputes `canLevelUpProvider`,
/// banked XP spanning several levels chains one celebration at a time.
class LevelUpOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const LevelUpOverlay({super.key, required this.child});

  @override
  ConsumerState<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends ConsumerState<LevelUpOverlay> {
  int? _showLevel;
  Timer? _dismiss;
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(canLevelUpProvider, (prev, next) {
      if (next.valueOrNull ?? false) _confirmPending();
    });

    return Stack(
      children: [
        widget.child,
        if (_showLevel != null)
          Positioned.fill(
            child: IgnorePointer(
              child: _BurstAndCard(level: _showLevel!),
            ),
          ),
      ],
    );
  }

  /// Advances the confirmed level by exactly one and celebrates. Guarded so
  /// overlapping provider refreshes can't double-award the same transition
  /// (the DB write is additionally monotonic via [persistConfirmedLevel]).
  Future<void> _confirmPending() async {
    if (_confirming) return;
    _confirming = true;
    try {
      final confirmed = await ref.read(confirmedLevelProvider.future);
      final newLevel = confirmed + 1;
      if (ref.read(devModeProvider)) {
        ref.read(devConfirmedLevelProvider.notifier).state = newLevel;
      } else {
        final session = ref.read(sessionProvider);
        if (session == null) return;
        await persistConfirmedLevel(session.user.id, newLevel);
      }
      if (!mounted) return;
      ref.invalidate(confirmedLevelProvider);
      _fire(newLevel);
    } finally {
      _confirming = false;
    }
  }

  void _fire(int level) {
    HapticFeedback.heavyImpact();
    setState(() => _showLevel = level);
    _dismiss?.cancel();
    _dismiss = Timer(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      setState(() => _showLevel = null);
      // After the celebratory burst, prompt the user to pick milestones for
      // the next level transition. Best-effort: navigation can fail silently
      // if the app is mid-tear-down.
      _pushPickerForNext(level + 1);
    });
    final session = ref.read(sessionProvider);
    if (session != null) {
      final rank = rankFor(level);
      () async {
        try {
          await SupabaseService.client.from('notifications').insert({
            'user_id': session.user.id,
            'type': 'level_up',
            'title': 'Level $level reached',
            'body': '${rank.tier.name} · ${rank.subTier.label}',
            'payload': {'level': level},
          });
        } catch (_) {}
      }();
    }
  }

  void _pushPickerForNext(int targetLevel) {
    if (!mounted) return;
    try {
      GoRouter.of(context).push('/level/prereq-picker/$targetLevel');
    } catch (_) {}
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    super.dispose();
  }
}

class _BurstAndCard extends StatefulWidget {
  final int level;
  const _BurstAndCard({required this.level});
  @override
  State<_BurstAndCard> createState() => _BurstAndCardState();
}

class _BurstAndCardState extends State<_BurstAndCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  final _seed = math.Random().nextInt(99999);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rank = rankFor(widget.level);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final v = _ctrl.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _BurstPainter(
                progress: v,
                seed: _seed,
                primary: c.accent,
                secondary: c.amber,
              ),
            ),
            Opacity(
              opacity: v < 0.15 ? v / 0.15 : (v > 0.85 ? (1 - v) / 0.15 : 1),
              child: Transform.scale(
                scale: 0.85 + 0.15 * Curves.easeOutBack.transform(v.clamp(0.0, 1.0)),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 22, 16),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.zap, size: 28, color: Colors.white),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LEVEL UP',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Level ${widget.level} · ${rank.tier.name}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final int seed;
  final Color primary;
  final Color secondary;
  _BurstPainter({
    required this.progress,
    required this.seed,
    required this.primary,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = math.Random(seed);
    const n = 60;
    for (int i = 0; i < n; i++) {
      final ang = rng.nextDouble() * math.pi * 2;
      final dist = (60 + rng.nextDouble() * 220) * Curves.easeOutQuart.transform(progress);
      final p = center + Offset(math.cos(ang), math.sin(ang)) * dist;
      final r = 1.4 + rng.nextDouble() * 2.6;
      final fade = (1 - progress).clamp(0.0, 1.0);
      final color = (i % 3 == 0 ? secondary : primary).withValues(alpha: fade);
      canvas.drawCircle(p, r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.progress != progress;
}

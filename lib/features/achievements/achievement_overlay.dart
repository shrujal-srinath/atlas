import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import 'achievement_catalog.dart';
import 'achievement_engine.dart';
import 'achievement_provider.dart';

/// Mounted once near the app root. Listens to [unlockedAchievementsProvider]
/// and pops a one-shot card whenever a new achievement id appears.
class AchievementOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const AchievementOverlay({super.key, required this.child});

  @override
  ConsumerState<AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends ConsumerState<AchievementOverlay> {
  Set<String> _known = const {};
  final _queue = <String>[];
  bool _showing = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    // Side-effect: kick off the unlocker so it starts listening.
    Future.microtask(() => ref.read(achievementUnlockerProvider));
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _enqueue(String id) {
    _queue.add(id);
    if (!_showing) _showNext();
  }

  void _showNext() {
    if (_queue.isEmpty) {
      setState(() => _showing = false);
      return;
    }
    final next = _queue.removeAt(0);
    HapticFeedback.mediumImpact();
    setState(() {
      _showing = true;
      _current = next;
    });
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), _showNext);
  }

  String? _current;

  @override
  Widget build(BuildContext context) {
    // Watch for new unlocks.
    ref.listen<AsyncValue<Set<String>>>(
      unlockedAchievementsProvider,
      (prev, next) {
        final cur = next.valueOrNull;
        if (cur == null) return;
        if (_known.isEmpty) {
          // First load — treat as baseline, don't fire for past unlocks.
          _known = cur;
          return;
        }
        final fresh = cur.difference(_known);
        for (final id in fresh) {
          _enqueue(id);
        }
        _known = cur;
      },
    );

    return Stack(
      children: [
        widget.child,
        if (_showing && _current != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: SafeArea(
              child: _UnlockCard(
                def: achievementCatalog.firstWhere((a) => a.id == _current),
                onDismiss: _showNext,
              ),
            ),
          ),
      ],
    );
  }
}

class _UnlockCard extends StatefulWidget {
  final AchievementDef def;
  final VoidCallback onDismiss;
  const _UnlockCard({required this.def, required this.onDismiss});

  @override
  State<_UnlockCard> createState() => _UnlockCardState();
}

class _UnlockCardState extends State<_UnlockCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ScaleTransition(
      scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
      child: FadeTransition(
        opacity: _ctrl,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onDismiss,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(AppRadii.card),
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.40),
                    blurRadius: 30,
                    spreadRadius: -4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.def.icon, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACHIEVEMENT UNLOCKED',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.def.name,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+${widget.def.xpReward} XP',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.x, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

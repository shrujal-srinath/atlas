import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../providers/connectivity_provider.dart';

/// Persistent pill anchored at the top of the app. Visible whenever the
/// device is offline or when there are queued mutations awaiting sync.
/// Flashes "Synced" for 2.5s after the queue fully drains.
class OfflinePill extends ConsumerStatefulWidget {
  const OfflinePill({super.key});

  @override
  ConsumerState<OfflinePill> createState() => _OfflinePillState();
}

class _OfflinePillState extends ConsumerState<OfflinePill> {
  bool _showSynced = false;
  int _lastDepth = 0;
  bool _wasOffline = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final offline = ref.watch(isOfflineProvider);
    final depth = ref.watch(syncQueueDepthProvider).valueOrNull ?? 0;

    // Detect drain-complete edge: was queued, now empty AND online.
    if (!offline && depth == 0 && _lastDepth > 0) {
      _showSynced = true;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showSynced = false);
      });
    }
    // Edge: offline → online.
    if (!offline && _wasOffline && depth == 0) {
      _showSynced = true;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showSynced = false);
      });
    }
    _lastDepth = depth;
    _wasOffline = offline;

    final visible = offline || depth > 0 || _showSynced;
    final Widget pill;
    if (_showSynced && !offline && depth == 0) {
      pill = _PillBody(
        icon: LucideIcons.checkCircle2,
        text: 'Synced',
        tint: c.positive,
      );
    } else if (offline) {
      pill = _PillBody(
        icon: LucideIcons.wifiOff,
        text: depth > 0
            ? 'Offline · $depth pending'
            : 'Offline',
        tint: c.amber,
      );
    } else if (depth > 0) {
      pill = _PillBody(
        icon: LucideIcons.refreshCw,
        text: 'Syncing · $depth',
        tint: c.accent,
      );
    } else {
      pill = const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(
          sizeFactor: anim,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: visible
          ? Padding(
              key: ValueKey('pill-${pill.runtimeType}-$offline-$depth-$_showSynced'),
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenH, 6, AppSpace.screenH, 0),
              child: pill,
            )
          : const SizedBox.shrink(key: ValueKey('pill-empty')),
    );
  }
}

class _PillBody extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color tint;
  const _PillBody({required this.icon, required this.text, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: tint.withValues(alpha: 0.55), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tint,
              letterSpacing: 0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Container(width: 4, height: 4,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

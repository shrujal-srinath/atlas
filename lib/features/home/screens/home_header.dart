part of 'home_screen.dart';

/// The home's top row: the live status ticker ("on pace…") takes the width, with
/// the notification bell pinned to its right. Replaces the old greeting/date
/// header to reclaim the vertical space it spent.
class _TopBar extends StatelessWidget {
  final VoidCallback onBell;
  const _TopBar({required this.onBell});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: _NotifBanner()),
        const SizedBox(width: 8),
        _BellButton(onTap: onBell),
      ],
    );
  }
}

/// Notification bell with an unread dot — sized to sit flush beside the ticker.
class _BellButton extends ConsumerWidget {
  final VoidCallback onTap;
  const _BellButton({required this.onTap});

  static const double _size = 46;
  static const double _radius = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final unread = ref.watch(bellBadgeCountProvider);
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 7,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(LucideIcons.bell, size: 19, color: c.textSecondary),
              if (unread > 0)
                Positioned(
                  top: 12,
                  right: 13,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent,
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifBanner extends ConsumerStatefulWidget {
  const _NotifBanner();
  @override
  ConsumerState<_NotifBanner> createState() => _NotifBannerState();
}

class _NotifBannerState extends ConsumerState<_NotifBanner> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 3400), (_) {
      if (!mounted) return;
      final n = ref.read(tickerLinesProvider).length;
      if (n > 0) setState(() => _i = (_i + 1) % n);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lines = ref.watch(tickerLinesProvider);
    if (lines.isEmpty) return const SizedBox.shrink();
    final idx = _i % lines.length;
    final f = lines[idx];
    final tc = f.tone == TickerTone.warn
        ? c.amber
        : f.tone == TickerTone.accent
            ? c.accent
            : c.textSecondary;
    return InkWell(
      onTap: f.routeTo == null ? null : () => context.push(f.routeTo!),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 9,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(f.icon, size: 14, color: tc),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  f.text,
                  key: ValueKey(idx),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(lines.length, (k) {
              final active = k == idx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(left: 4),
                width: active ? 12 : 5,
                height: 4,
                decoration: BoxDecoration(
                  color: active ? c.accent : c.borderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
            ),
          ],
        ),
      ),
    );
  }
}

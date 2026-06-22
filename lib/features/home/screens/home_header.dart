part of 'home_screen.dart';

class _Header extends ConsumerWidget {
  final VoidCallback onBell;
  final bool showGreeting;
  const _Header({required this.onBell, this.showGreeting = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final unread = ref.watch(bellBadgeCountProvider);
    // Bell shrinks when the greeting collapses, so the whole row contracts and
    // we actually reclaim vertical pixels (otherwise the bell pins the row).
    final bellSize = showGreeting ? 42.0 : 30.0;
    final bellRadius = showGreeting ? 13.0 : 9.0;
    final bellIconSize = showGreeting ? 19.0 : 15.0;
    final now = DateTime.now();
    final dateLabel =
        DateFormat('EEEE · d MMM').format(now).toUpperCase();
    final greeting = _greetingFor(now);
    final fullName = ref.watch(appUserProvider).valueOrNull?.name.trim() ?? '';
    final firstName =
        fullName.isEmpty ? '' : fullName.split(RegExp(r'\s+')).first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: c.textMuted,
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: showGreeting
                        ? Padding(
                            key: const ValueKey('greeting-on'),
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              firstName.isEmpty
                                  ? greeting
                                  : '$greeting, $firstName',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: c.textPrimary,
                                height: 1.0,
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('greeting-off'),
                            width: double.infinity,
                            height: 0,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          width: bellSize,
          height: bellSize,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(bellRadius),
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
            borderRadius: BorderRadius.circular(bellRadius),
            child: InkWell(
              onTap: onBell,
              borderRadius: BorderRadius.circular(bellRadius),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(LucideIcons.bell,
                      size: bellIconSize, color: c.textSecondary),
                  if (unread > 0)
                    Positioned(
                      top: showGreeting ? 9 : 6,
                      right: showGreeting ? 10 : 7,
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
        ),
      ],
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

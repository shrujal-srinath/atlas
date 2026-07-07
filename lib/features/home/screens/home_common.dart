part of 'home_screen.dart';

class _FilterPills extends StatelessWidget {
  final String value;
  final Map<String, int> counts;
  final ValueChanged<String> onChange;
  const _FilterPills({
    required this.value,
    required this.counts,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final opts = [
      ('all', 'All'),
      ('MORNING', 'Morning'),
      ('AFTERNOON', 'Afternoon'),
      ('EVENING', 'Evening'),
      ('NIGHT', 'Night'),
      ('incomplete', 'Incomplete'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final o in opts) ...[
            _pill(context, o.$1, o.$2, counts[o.$1] ?? 0),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String id, String label, int cnt) {
    final c = context.c;
    final on = value == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChange(id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? c.accent : c.border, width: 0.5),
          boxShadow: on
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 7,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : c.textSecondary,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 17),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: on
                    ? Colors.white.withValues(alpha: 0.22)
                    : c.surfaceElevated,
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: Text(
                '$cnt',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : c.textMuted,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const _Card({required this.child, this.padding = EdgeInsets.zero, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(onTap: onTap!, child: card);
  }
}

class _Overline extends StatelessWidget {
  final String text;
  final double size;
  const _Overline(this.text, {this.size = 10.5});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: c.textMuted,
        height: 1.0,
      ),
    );
  }
}

class _MicroPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const _MicroPill({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

part of 'settings_screen.dart';

// ─────────────────────────── primitives ────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: context.t.label);
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: context.c.border);
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _Row({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Text(label, style: t.body.copyWith(color: c.textSecondary)),
            const Spacer(),
            Text(value, style: t.bodyStrong),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 14, color: c.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumRow extends StatelessWidget {
  final String label;
  final String unit;
  final int? value;
  final Future<void> Function(int) onSaved;
  const _NumRow({
    required this.label,
    required this.unit,
    required this.value,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      value: value == null ? 'Set' : '$value $unit',
      onTap: () async {
        final v = await showTextEditSheet(
          context,
          title: label,
          initial: value?.toString() ?? '',
          suffix: unit,
          keyboardType: TextInputType.number,
        );
        if (v != null && v.isNotEmpty) {
          final n = int.tryParse(v);
          if (n != null) await onSaved(n);
        }
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // Whole row is the tap target; the switch mirrors the state.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.bodyStrong),
                  const SizedBox(height: 2),
                  Text(sub, style: t.meta),
                ],
              ),
            ),
            const SizedBox(width: 14),
            AtlasSwitch(value: value),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool destructive;
  const _NavRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final iconColor = destructive ? c.negative : c.accent;
    final labelColor = destructive ? c.negative : c.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.bodyStrong.copyWith(color: labelColor)),
                  const SizedBox(height: 2),
                  Text(sub, style: t.meta),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 14, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _ToggleHalf(
            icon: LucideIcons.moon,
            label: 'Dark',
            active: mode == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
          _ToggleHalf(
            icon: LucideIcons.sun,
            label: 'Light',
            active: mode == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
        ],
      ),
    );
  }
}

class _ToggleHalf extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleHalf({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: active ? c.accent : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? c.accent : c.textMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? c.accent : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

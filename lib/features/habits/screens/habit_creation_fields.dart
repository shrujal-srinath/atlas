part of 'habit_creation_screen.dart';

// ─────────────────────────────── pieces ───────────────────────────────

/// Titled BENTO container. Wraps a logical group of inputs in the same
/// surface + 0.5px border + soft-shadow card style used on the home screen.
class _BentoSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _BentoSection({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: c.textMuted,
              height: 1.0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Single-line TextField wrapped in the BENTO input style: 56dp height,
/// `surfaceElevated` fill, 0.5px border, accent on focus. Matches home cards.
class _BentoField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final TextInputType? keyboard;
  final bool autofocus;
  const _BentoField({
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboard,
    this.autofocus = false,
  });

  @override
  State<_BentoField> createState() => _BentoFieldState();
}

class _BentoFieldState extends State<_BentoField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final focused = _focus.hasFocus;
    return Container(
      // Horizontal inset only; the vertical inset comes solely from the
      // field's contentPadding so the interior whitespace is uniform on all
      // four sides (was double-padded + uncentred before).
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        // Inputs read as inputs: surface fill + borderStrong (house rule 5) —
        // the old surfaceElevated fill ≈ the card behind it, so the field read
        // as an unpainted patch. The accent focus ring on an empty autofocused
        // field also read as an error before the user typed anything
        // (NORTHSTAR T3); focus now just firms the border instead.
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(
          color: c.borderStrong,
          width: focused ? 1.4 : 0.8,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboard,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.textMuted,
          ),
          suffixText: widget.suffix,
          suffixStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: context.t.label);
}

/// Section picker — chips for every section in the registry (3 built-ins +
/// custom), so a habit can be assigned to any of them. Selected = solid accent.
class _SectionRow extends ConsumerWidget {
  final String selectedId;
  final ValueChanged<String> onChanged;
  const _SectionRow({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final sections = ref.watch(sectionsProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in sections)
          PressScale(
            scale: 0.96,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(s.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: s.id == selectedId ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(
                  color: s.id == selectedId ? c.accent : c.border,
                  width: s.id == selectedId ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: s.id == selectedId
                          ? c.onAccent
                          : sectionColorForKey(c, s.colorKey),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    s.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: s.id == selectedId
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: s.id == selectedId ? c.onAccent : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final HabitPriority selected;
  final ValueChanged<HabitPriority> onChanged;
  const _PriorityRow({required this.selected, required this.onChanged});

  Color _color(AppPalette c, HabitPriority p) => switch (p) {
        HabitPriority.low => c.textMuted,
        HabitPriority.normal => c.accent,
        HabitPriority.high => c.amber,
        HabitPriority.critical => c.negative,
      };

  String _label(HabitPriority p) => switch (p) {
        HabitPriority.low => 'Low',
        HabitPriority.normal => 'Normal',
        HabitPriority.high => 'High',
        HabitPriority.critical => 'Critical',
      };

  String _multiplier(HabitPriority p) => switch (p) {
        HabitPriority.low => '0.5×',
        HabitPriority.normal => '1×',
        HabitPriority.high => '1.5×',
        HabitPriority.critical => '2.5×',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Segmented(
      index: selected.index,
      height: 52,
      colorFor: (i) => _color(c, HabitPriority.values[i]),
      onChanged: (i) => onChanged(HabitPriority.values[i]),
      items: [
        for (final p in HabitPriority.values)
          _Seg(_label(p), sub: _multiplier(p)),
      ],
    );
  }
}

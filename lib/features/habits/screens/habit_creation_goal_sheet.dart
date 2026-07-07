part of 'habit_creation_screen.dart';

// ───────────────────── Goal sheet ─────────────────────
// Two-layer goal picker: first the *type* (count / duration / distance /
// volume / custom), then its *unit* (e.g. min ↔ hr, km ↔ mi, L ↔ ml). The
// value is stored in whatever unit the user picks (ratio-based scoring is
// unit-agnostic), with `goalUnit` recording the choice so it displays right.

/// The fully-resolved goal choice handed back to the screen.
typedef GoalChoice = ({GoalType? type, String value, String? unit});

class _GoalSheet extends StatefulWidget {
  final GoalType? initialType;
  final String initialValue;
  final String? initialUnit;
  final Color accent;
  const _GoalSheet({
    required this.initialType,
    required this.initialValue,
    required this.initialUnit,
    required this.accent,
  });

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late GoalType? _type;
  late String? _unit;
  late final TextEditingController _ctrl;
  late final TextEditingController _customUnitCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _unit = widget.initialUnit ?? _defaultUnit(_type);
    _ctrl = TextEditingController(text: widget.initialValue);
    // For a custom goal the "unit" is a free-text label the user owns.
    _customUnitCtrl = TextEditingController(
      text: _type == GoalType.custom ? (widget.initialUnit ?? '') : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _customUnitCtrl.dispose();
    super.dispose();
  }

  String? _defaultUnit(GoalType? t) {
    if (t == null) return null;
    final units = goalUnitsFor(t);
    return units.isEmpty ? null : units.first;
  }

  String _typeLabel(GoalType g) => switch (g) {
        GoalType.reps => 'Count',
        GoalType.durationMin => 'Duration',
        GoalType.distanceKm => 'Distance',
        GoalType.litres => 'Volume',
        GoalType.custom => 'Custom',
      };

  IconData _icon(GoalType g) => switch (g) {
        GoalType.reps => LucideIcons.hash,
        GoalType.durationMin => LucideIcons.clock,
        GoalType.distanceKm => LucideIcons.mapPin,
        GoalType.litres => LucideIcons.droplet,
        GoalType.custom => LucideIcons.target,
      };

  // Switching units converts the entered value for convenience (e.g. 60 min →
  // 1 hr) so the user isn't left with a nonsensical number.
  void _changeUnit(String unit) {
    final t = _type;
    final old = _unit;
    final v = double.tryParse(_ctrl.text.trim());
    setState(() {
      _unit = unit;
      if (t != null && v != null) {
        final canonical = goalToCanonical(t, old, v);
        final converted = goalFromCanonical(t, unit, canonical);
        _ctrl.text = _fmtGoal(converted);
      }
    });
  }

  String _fmtGoal(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return (v * 100).round() / 100 == (v * 10).round() / 10
        ? v.toStringAsFixed(1)
        : v.toStringAsFixed(2);
  }

  String get _activeUnitLabel {
    if (_type == GoalType.custom) {
      final u = _customUnitCtrl.text.trim();
      return u.isEmpty ? 'units' : u;
    }
    return goalUnitLabel(_type!, _unit);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final units = _type == null ? const <String>[] : goalUnitsFor(_type!);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpace.screenH,
          14,
          AppSpace.screenH,
          MediaQuery.of(context).viewPadding.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            Text('Daily goal', style: t.h2),
            const SizedBox(height: 4),
            Text(
              'How much counts as one day done.',
              style: t.meta.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 14),
            // ── Layer 1: type ──────────────────────────────────────
            _Label('Track by'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TypeChip(
                  label: 'Off',
                  icon: LucideIcons.ban,
                  active: _type == null,
                  accent: widget.accent,
                  onTap: () => setState(() => _type = null),
                ),
                for (final g in GoalType.values)
                  _TypeChip(
                    label: _typeLabel(g),
                    icon: _icon(g),
                    active: _type == g,
                    accent: widget.accent,
                    onTap: () => setState(() {
                      _type = g;
                      _unit = _defaultUnit(g);
                    }),
                  ),
              ],
            ),
            // ── Layer 2: unit ──────────────────────────────────────
            if (_type != null && units.length > 1) ...[
              const SizedBox(height: 16),
              _Label('Measure in'),
              const SizedBox(height: 8),
              _UnitToggleRow(
                units: units,
                selected: _unit,
                accent: widget.accent,
                onChanged: _changeUnit,
              ),
            ],
            if (_type == GoalType.custom) ...[
              const SizedBox(height: 16),
              _Label('Unit name'),
              const SizedBox(height: 8),
              _GoalInput(
                controller: _customUnitCtrl,
                hint: 'e.g. pages, glasses, sets',
                accent: widget.accent,
                keyboard: TextInputType.text,
                onChanged: () => setState(() {}),
              ),
            ],
            // ── Value ──────────────────────────────────────────────
            if (_type != null) ...[
              const SizedBox(height: 16),
              _Label('Target'),
              const SizedBox(height: 8),
              _GoalInput(
                controller: _ctrl,
                hint: '0',
                suffix: _activeUnitLabel,
                accent: widget.accent,
                autofocus: _type != GoalType.custom,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: _readableOn(widget.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
              ),
              onPressed: () {
                final unit = _type == GoalType.custom
                    ? (_customUnitCtrl.text.trim().isEmpty
                        ? null
                        : _customUnitCtrl.text.trim())
                    : _unit;
                Navigator.pop(
                  context,
                  (type: _type, value: _ctrl.text.trim(), unit: unit),
                );
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented unit selector (e.g. min | hr) — selected segment fills with the
/// accent and high-contrast text, the rest read as quiet surface chips.
class _UnitToggleRow extends StatelessWidget {
  final List<String> units;
  final String? selected;
  final Color accent;
  final ValueChanged<String> onChanged;
  const _UnitToggleRow({
    required this.units,
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadii.button + 4),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          for (final u in units)
            Expanded(
              child: _PressScale(
                scale: 0.96,
                onTap: () => onChanged(u),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: u == selected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Text(
                    _unitDisplay(u),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: u == selected ? _readableOn(accent) : c.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _unitDisplay(String u) => switch (u) {
        'min' => 'Minutes',
        'hr' => 'Hours',
        'km' => 'Kilometres',
        'mi' => 'Miles',
        'L' => 'Litres',
        'ml' => 'Millilitres',
        _ => u,
      };
}

/// Goal-sheet input styled like the form's BENTO fields (surface fill, defined
/// border, accent on focus) with an optional unit suffix.
class _GoalInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final Color accent;
  final bool autofocus;
  final TextInputType keyboard;
  final VoidCallback? onChanged;
  const _GoalInput({
    required this.controller,
    required this.hint,
    required this.accent,
    this.suffix,
    this.autofocus = false,
    this.keyboard = TextInputType.text,
    this.onChanged,
  });

  @override
  State<_GoalInput> createState() => _GoalInputState();
}

class _GoalInputState extends State<_GoalInput> {
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(
          color: focused ? widget.accent.withValues(alpha: 0.55) : c.border,
          width: focused ? 1 : 0.5,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboard,
        textAlignVertical: TextAlignVertical.center,
        onChanged: (_) => widget.onChanged?.call(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
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
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: c.textDim,
          ),
          suffixText: widget.suffix,
          suffixStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? accent : c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(
            color: active ? accent : c.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: active ? _readableOn(accent) : c.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? _readableOn(accent) : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

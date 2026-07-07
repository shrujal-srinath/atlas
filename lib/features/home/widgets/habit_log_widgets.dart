part of 'habit_log_modal.dart';

// ── Compact widgets ─────────────────────────────────────────────────

class _CompactStepper extends StatelessWidget {
  final double currentValue;
  final double goal;
  final String unit;
  final Color sectionColor;
  final void Function(double delta) onAdd;
  final void Function(double v) onSet;

  const _CompactStepper({
    required this.currentValue,
    required this.goal,
    required this.unit,
    required this.sectionColor,
    required this.onAdd,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = goal <= 0 ? 0.0 : (currentValue / goal).clamp(0.0, 1.10);
    final overshoot = currentValue > goal;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StepBtn(
                icon: LucideIcons.minus,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onAdd(-_stepFor(unit));
                },
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _HabitLogSheetState._trimZero(currentValue),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: overshoot ? c.amber : c.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '/ ${_HabitLogSheetState._trimZero(goal)} $unit',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textMuted,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: c.surface,
                        valueColor: AlwaysStoppedAnimation(
                            overshoot ? c.amber : sectionColor),
                      ),
                    ),
                  ],
                ),
              ),
              _StepBtn(
                icon: LucideIcons.plus,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onAdd(_stepFor(unit));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PresetChip(label: '25%', onTap: () => onSet(goal * 0.25)),
              _PresetChip(label: '50%', onTap: () => onSet(goal * 0.5)),
              _PresetChip(label: 'Goal', onTap: () => onSet(goal), accent: sectionColor),
              _PresetChip(label: 'Reset', onTap: () => onSet(0), muted: true),
            ],
          ),
        ],
      ),
    );
  }

  static double _stepFor(String unit) {
    switch (unit) {
      case 'km':
        return 0.5;
      case 'L':
        return 0.25;
      default:
        return 1;
    }
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Icon(icon, size: 18, color: c.textPrimary),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool muted;
  final Color? accent;
  const _PresetChip({
    required this.label,
    required this.onTap,
    this.muted = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hasAccent = accent != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: hasAccent
              ? accent!.withValues(alpha: 0.12)
              : (muted ? c.surface : c.surfaceElevated),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: hasAccent ? accent! : c.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: hasAccent ? accent : (muted ? c.textMuted : c.textSecondary),
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _CompactOutcomeBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CompactOutcomeBtn({
    required this.label,
    required this.color,
    required this.selected,
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
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
            color: selected ? color : c.border,
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? color : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.10) : c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: active ? accent.withValues(alpha: 0.55) : c.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: active ? accent : c.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? c.textPrimary : c.textSecondary,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CircleIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Icon(icon, size: 14, color: c.textSecondary),
        ),
      ),
    );
  }
}

// ── Legacy expanded-mode widgets (unchanged) ────────────────────────

class _NumericProgressBlock extends StatelessWidget {
  final TextEditingController valueCtrl;
  final double current;
  final double goal;
  final String unit;
  final Color sectionColor;
  final ValueChanged<String> onChanged;
  final void Function(double delta) onAdd;
  final void Function(double v) onSet;

  const _NumericProgressBlock({
    required this.valueCtrl,
    required this.current,
    required this.goal,
    required this.unit,
    required this.sectionColor,
    required this.onChanged,
    required this.onAdd,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = goal <= 0 ? 0.0 : (current / goal).clamp(0.0, 1.10);
    final pctInt = (pct * 100).round();
    final overshoot = current > goal;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _HabitLogSheetState._trimZero(current),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: c.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '/ ${_HabitLogSheetState._trimZero(goal)} $unit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                    height: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: overshoot
                      ? c.amber.withValues(alpha: 0.18)
                      : sectionColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$pctInt%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: overshoot ? c.amber : sectionColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: c.surface,
              valueColor: AlwaysStoppedAnimation(sectionColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: valueCtrl,
                  onChanged: onChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter $unit',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.border, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.border, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: sectionColor, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(label: '+1', onTap: () => onAdd(1)),
              _Chip(label: '+5', onTap: () => onAdd(5)),
              _Chip(label: 'Goal', onTap: () => onSet(goal)),
              _Chip(label: 'Reset', onTap: () => onSet(0), muted: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool muted;
  const _Chip({required this.label, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: muted ? c.surface : c.surfaceElevated,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: muted ? c.textMuted : c.textSecondary,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _OutcomeBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _OutcomeBtn({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(color: selected ? color : c.border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? color : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

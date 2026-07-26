part of 'habit_creation_screen.dart';

// ════════════════════════════════════════════════════════════════════
// Shared interaction primitives — the building blocks that give every
// control on this screen the same premium feel: a sliding-thumb segmented
// control, a custom switch, and press-scale tactility.
// ════════════════════════════════════════════════════════════════════

/// Picks a legible foreground for an arbitrary swatch — white on saturated
/// mid-tones, ink on pale ones — so a filled accent never produces low-contrast
/// text (the habit colour is user-chosen and can be light).
Color _readableOn(Color bg) =>
    bg.computeLuminance() > 0.6 ? const Color(0xFF1B1714) : Colors.white;

/// Wraps any tappable in a quick scale-down on press. The small physical
/// "give" is what separates a considered control from a flat one.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  const _PressScale({
    required this.child,
    required this.onTap,
    this.scale = 0.94,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;
  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// One segment's content.
class _Seg {
  final String label;
  final IconData? icon;
  final String? sub;
  const _Seg(this.label, {this.icon, this.sub});
}

/// iOS-style segmented control: a recessed track with a single raised thumb
/// that *slides* to the active segment. The thumb carries a soft shadow and a
/// hairline of the active colour; labels light up in that colour. One source
/// of truth for every single-choice selector on the form.
class _Segmented extends StatelessWidget {
  final List<_Seg> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Color Function(int) colorFor;
  final double height;
  const _Segmented({
    required this.items,
    required this.index,
    required this.onChanged,
    required this.colorFor,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = items.length;
    final hasIcons = items.any((e) => e.icon != null);
    final active = colorFor(index);

    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(AppRadii.button + 4),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Stack(
          children: [
            // Sliding thumb. Position and border-colour animate together so a
            // section/priority change cross-fades its colour as it travels.
            AnimatedAlign(
              alignment:
                  n <= 1 ? Alignment.center : Alignment(-1 + 2 * index / (n - 1), 0),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    border: Border.all(
                        color: active.withValues(alpha: 0.45), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: List.generate(n, (i) {
                final on = i == index;
                final col = colorFor(i);
                final it = items[i];
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (it.icon != null) ...[
                            Icon(it.icon,
                                size: 15, color: on ? col : c.textMuted),
                            const SizedBox(height: 3),
                          ] else if (hasIcons)
                            const SizedBox(height: 18),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              it.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight:
                                    on ? FontWeight.w700 : FontWeight.w600,
                                color: on ? col : c.textMuted,
                                height: 1.0,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          if (it.sub != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              it.sub!,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: on
                                    ? col.withValues(alpha: 0.9)
                                    : c.textDim,
                                height: 1.0,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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

/// Custom iOS-style switch — solid accent track when on, white thumb that
/// slides. Replaces the stock Material switch so it sits inside the design
/// language instead of next to it.
class _AtlasSwitch extends StatelessWidget {
  final bool value;
  final Color accent;
  const _AtlasSwitch({required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 48,
      height: 29,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? accent : c.borderStrong,
        borderRadius: BorderRadius.circular(99),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Form controls.
// ════════════════════════════════════════════════════════════════════

/// Top-level repeat choice: every day, or a weekly cadence ("X / week") that
/// then splits into exact-days vs flexible-count below.
class _FreqRow extends StatelessWidget {
  final bool isEveryDay;
  final Color accent;
  final VoidCallback onEveryDay;
  final VoidCallback onXWeek;
  const _FreqRow({
    required this.isEveryDay,
    required this.accent,
    required this.onEveryDay,
    required this.onXWeek,
  });

  @override
  Widget build(BuildContext context) {
    return _Segmented(
      index: isEveryDay ? 0 : 1,
      colorFor: (_) => accent,
      onChanged: (i) => i == 0 ? onEveryDay() : onXWeek(),
      height: 44,
      items: const [
        _Seg('Every day'),
        _Seg('X / week'),
      ],
    );
  }
}

/// Sub-choice shown under "X / week": pin exact weekdays, or a flexible weekly
/// count with rest days.
class _XWeekModeRow extends StatelessWidget {
  final bool exactDays;
  final Color accent;
  final ValueChanged<bool> onChanged; // true → exact days
  const _XWeekModeRow({
    required this.exactDays,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Segmented(
      index: exactDays ? 0 : 1,
      colorFor: (_) => accent,
      onChanged: (i) => onChanged(i == 0),
      height: 46,
      items: const [
        _Seg('Exact days', icon: LucideIcons.calendarDays),
        _Seg('Flexible count', icon: LucideIcons.repeat2),
      ],
    );
  }
}

/// Caption under the flexible-count field: turns "X / week" into the plain-
/// language promise — "any X days, Y flexible rest days". Updates live with the
/// count field. (The rest-day *action* itself ships in Phase 2.)
class _RestDayHint extends StatelessWidget {
  final TextEditingController controller;
  final Color accent;
  const _RestDayHint({required this.controller, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final x = int.tryParse(value.text.trim()) ?? 0;
        final ok = x >= 1 && x <= 7;
        final rest = (7 - x).clamp(0, 7);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.coffee, size: 15, color: accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  ok
                      ? 'Shows every day — finish it any $x ${x == 1 ? 'day' : 'days'} a week, with $rest flexible rest ${rest == 1 ? 'day' : 'days'}.'
                      : 'Enter how many days a week (1–7).',
                  style: t.meta.copyWith(color: c.textSecondary, height: 1.3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DaysRow extends StatelessWidget {
  final List<int> selected;
  final Color accent;
  final ValueChanged<int> onToggle;
  const _DaysRow({
    required this.selected,
    required this.accent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = _readableOn(accent);
    return Row(
      children: List.generate(7, (i) {
        final d = i + 1;
        final active = selected.contains(d);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
            child: _PressScale(
              onTap: () => onToggle(d),
              scale: 0.9,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 42,
                decoration: BoxDecoration(
                  color: active ? accent : c.surfaceElevated,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: active ? accent : c.border,
                    width: active ? 1 : 0.5,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _dayLabels[i],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? on : c.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _WhenRow extends StatelessWidget {
  final TimePeriod? selected;
  final Color accent;
  final ValueChanged<TimePeriod?> onChanged;
  const _WhenRow({
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Index 0 == Anytime (null); 1..3 map to the TimePeriod enum.
    final index = selected == null ? 0 : selected!.index + 1;
    return _Segmented(
      index: index,
      colorFor: (_) => accent,
      height: 52,
      onChanged: (i) => onChanged(i == 0 ? null : TimePeriod.values[i - 1]),
      items: const [
        _Seg('Anytime'),
        _Seg('Morning', icon: LucideIcons.sunrise),
        _Seg('Afternoon', icon: LucideIcons.sun),
        _Seg('Evening', icon: LucideIcons.moon),
      ],
    );
  }
}

class _EndRow extends StatelessWidget {
  final EndMode selected;
  final Color accent;
  final ValueChanged<EndMode> onChanged;
  const _EndRow({
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Segmented(
      index: selected.index,
      colorFor: (_) => accent,
      height: 44,
      onChanged: (i) => onChanged(EndMode.values[i]),
      items: const [
        _Seg('Off'),
        _Seg('On date'),
        _Seg('After N days'),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color accent;
  final VoidCallback onTap;
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _PressScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: context.t.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(LucideIcons.chevronRight, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// A non-interactive row matching [_PickerRow]'s shape — used to show a
/// field is deliberately locked/off (no chevron, muted icon+text) rather
/// than hiding it entirely, so the reason is legible instead of just absent.
class _MutedHintRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MutedHintRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.textMuted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: c.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.t.body.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPicker extends StatefulWidget {
  final String selected;
  final Color tint;
  final ValueChanged<String> onSelect;
  const _IconPicker({
    required this.selected,
    required this.tint,
    required this.onSelect,
  });

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  String _category = 'Athletic';

  @override
  void initState() {
    super.initState();
    // Open on the category containing the current icon.
    for (final entry in kHabitIconCategories.entries) {
      if (entry.value.contains(widget.selected)) {
        _category = entry.key;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final icons = kHabitIconCategories[_category] ?? const <String>[];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: kHabitIconCategories.keys.map((cat) {
                final active = cat == _category;
                return _PressScale(
                  scale: 0.95,
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: active
                          ? widget.tint.withValues(alpha: 0.14)
                          : c.surface,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: active
                            ? widget.tint.withValues(alpha: 0.6)
                            : c.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: active ? widget.tint : c.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: icons.map((k) {
              final active = k == widget.selected;
              return _PressScale(
                scale: 0.88,
                onTap: () => widget.onSelect(k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: active
                        ? widget.tint.withValues(alpha: 0.15)
                        : c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? widget.tint : c.border,
                      width: active ? 1.5 : 0.5,
                    ),
                  ),
                  child: Icon(
                    habitIcon(k),
                    size: 19,
                    color: active ? widget.tint : c.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _ColorSwatchRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: kHabitColorOrder.map((k) {
        final color = Color(kHabitColorSwatch[k]!);
        final active = k == selected;
        return _PressScale(
          scale: 0.88,
          onTap: () => onSelect(k),
          // Selected swatch gains an iOS-style ring (a gap, then a halo in its
          // own colour) rather than just an inset tick.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            padding: EdgeInsets.all(active ? 3.5 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? color : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: active
                  ? Icon(LucideIcons.check, size: 15, color: _readableOn(color))
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // The whole row is the target — far easier than aiming for the switch.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.bodyStrong),
                  const SizedBox(height: 1),
                  Text(sub, style: t.meta),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _AtlasSwitch(value: value, accent: accent),
          ],
        ),
      ),
    );
  }
}

class _AdvancedHeader extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  const _AdvancedHeader({required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            Icon(LucideIcons.settings2, size: 15, color: c.textMuted),
            const SizedBox(width: 8),
            Text(
              'Advanced',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(LucideIcons.chevronDown, size: 18, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editor for a task's food link: which meal slot to log into, plus the list
/// of foods (each a fixed portion) that get auto-logged on completion.
class _FoodLinkEditor extends StatelessWidget {
  final HabitFoodLink link;
  final Color accent;
  final bool busy;
  final ValueChanged<bool> onFlexibleChanged;
  final ValueChanged<MealTimeSlot> onSlotChanged;
  final VoidCallback onAddItem;
  final VoidCallback onAddManualItem;
  final ValueChanged<int> onRemoveItem;
  const _FoodLinkEditor({
    required this.link,
    required this.accent,
    required this.busy,
    required this.onFlexibleChanged,
    required this.onSlotChanged,
    required this.onAddItem,
    required this.onAddManualItem,
    required this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Segmented(
          items: const [
            _Seg('Fixed', icon: LucideIcons.utensils),
            _Seg('Flexible', icon: LucideIcons.shuffle),
          ],
          index: link.isFlexible ? 1 : 0,
          colorFor: (_) => accent,
          onChanged: (i) => onFlexibleChanged(i == 1),
        ),
        const SizedBox(height: 14),
        _Label('Log to'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in kDiarySlotOrder)
              _MealSlotChip(
                label: s.label,
                active: s == link.slot,
                accent: accent,
                onTap: () => onSlotChanged(s),
              ),
          ],
        ),
        if (link.isFlexible) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Text(
              "No preset food — you'll be asked to enter calories, log the "
              'real food, or skip it for later each time you complete this.',
              style: t.body.copyWith(color: c.textMuted),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          _Label('Foods'),
          const SizedBox(height: 8),
          if (link.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: c.border, width: 0.5),
              ),
              child: Text(
                'Add the foods this task logs — each with the quantity you take.',
                style: t.body.copyWith(color: c.textMuted),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < link.items.length; i++) ...[
                  _FoodLinkItemRow(
                    item: link.items[i],
                    accent: accent,
                    onRemove: () => onRemoveItem(i),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          const SizedBox(height: 4),
          _PickerRow(
            icon: LucideIcons.search,
            label: busy ? 'Adding…' : 'Search food',
            accent: accent,
            trailing: busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accent),
                  )
                : null,
            onTap: busy ? () {} : onAddItem,
          ),
          const SizedBox(height: 8),
          _PickerRow(
            icon: LucideIcons.pencil,
            label: 'Enter manually',
            accent: accent,
            trailing: const SizedBox.shrink(),
            onTap: busy ? () {} : onAddManualItem,
          ),
          if (link.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Total', style: t.bodyStrong),
                const Spacer(),
                Text(
                  '${link.totalKcal.round()} kcal',
                  style: AppType.numMd.copyWith(color: accent, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Small sheet for adding a `HabitFoodLinkItem` without a food-database
/// lookup — just a name + calories (+ optional macros), for foods you know
/// the numbers for by heart (a homemade shake, a usual portion) and don't
/// want to search for. Mirrors QuickAddSheet's field style/validation.
class _ManualFoodEntrySheet extends StatefulWidget {
  const _ManualFoodEntrySheet();

  @override
  State<_ManualFoodEntrySheet> createState() => _ManualFoodEntrySheetState();
}

class _ManualFoodEntrySheetState extends State<_ManualFoodEntrySheet> {
  final _name = TextEditingController(text: 'Food');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double _val(TextEditingController c) {
    final v = double.tryParse(c.text) ?? 0.0;
    return v < 0 ? 0.0 : v;
  }

  void _save() {
    final kcal = _val(_kcal);
    if (kcal <= 0) return;
    Navigator.of(context).pop(
      HabitFoodLinkItem(
        foodId: null,
        name: _name.text.trim().isEmpty ? 'Food' : _name.text.trim(),
        qty: 1,
        unit: 'serving',
        totals: Nutrients(
          kcal: kcal,
          proteinG: _val(_protein),
          carbsG: _val(_carbs),
          fatG: _val(_fat),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Enter manually', style: t.h2),
            const SizedBox(height: 16),
            _Label('Name'),
            const SizedBox(height: 6),
            _BentoField(controller: _name, hint: 'e.g. Milkshake'),
            const SizedBox(height: 14),
            _Label('Calories'),
            const SizedBox(height: 6),
            _BentoField(controller: _kcal, hint: 'kcal', keyboard: TextInputType.number),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Protein'),
                      const SizedBox(height: 6),
                      _BentoField(controller: _protein, hint: 'g', keyboard: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Carbs'),
                      const SizedBox(height: 6),
                      _BentoField(controller: _carbs, hint: 'g', keyboard: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Fat'),
                      const SizedBox(height: 6),
                      _BentoField(controller: _fat, hint: 'g', keyboard: TextInputType.number),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AtlasButton(label: 'Add', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _MealSlotChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  const _MealSlotChip({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _PressScale(
      scale: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.12) : c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: active ? accent : c.border,
            width: active ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? accent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FoodLinkItemRow extends StatelessWidget {
  final HabitFoodLinkItem item;
  final Color accent;
  final VoidCallback onRemove;
  const _FoodLinkItemRow({
    required this.item,
    required this.accent,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.utensils, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: t.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.portionLabel}  ·  ${item.totals.kcal.round()} kcal',
                  style: t.meta.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.x, size: 16, color: c.textMuted),
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ReplacementPicker extends ConsumerWidget {
  final String? selectedId;
  final Color accent;
  final ValueChanged<String?> onChanged;
  const _ReplacementPicker({
    required this.selectedId,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];
    final builders = habits
        .where((h) => h.sectionId == 'mind' && !h.isArchived)
        .toList();

    if (builders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Text(
          'No Building habits yet — create one to use as a replacement.',
          style: context.t.body.copyWith(color: c.textMuted),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final h in builders)
          _PressScale(
            scale: 0.95,
            onTap: () => onChanged(selectedId == h.id ? null : h.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selectedId == h.id
                    ? accent.withValues(alpha: 0.12)
                    : c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: selectedId == h.id ? accent : c.border,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(habitIcon(h.icon),
                      size: 14,
                      color: selectedId == h.id ? accent : c.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    h.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selectedId == h.id ? accent : c.textSecondary,
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

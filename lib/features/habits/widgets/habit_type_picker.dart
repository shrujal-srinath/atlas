import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/atlas_back_button.dart';

/// Opens the "what kind of habit" chooser. It's a full page (not a sheet) so
/// each type gets room to describe itself — the routing to /habit-creation
/// happens once the user commits with Continue.
Future<void> showHabitTypePicker(BuildContext context) {
  return context.push('/habit-type');
}

class HabitTypePickerScreen extends StatefulWidget {
  const HabitTypePickerScreen({super.key});

  @override
  State<HabitTypePickerScreen> createState() => _HabitTypePickerScreenState();
}

class _HabitTypePickerScreenState extends State<HabitTypePickerScreen> {
  HabitType _selected = HabitType.positive;

  Color _accentFor(BuildContext context, HabitType t) {
    final c = context.c;
    return switch (t) {
      HabitType.positive => c.accent,
      HabitType.negative => c.negative,
      HabitType.todo => c.indigo,
    };
  }

  void _select(HabitType t) {
    if (t == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = t);
  }

  void _continue() {
    HapticFeedback.selectionClick();
    context.pushReplacement('/habit-creation', extra: {'type': _selected});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final accent = _accentFor(context, _selected);

    return Scaffold(
      appBar: AppBar(leading: const AtlasBackButton()),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.screenH, 4, AppSpace.screenH, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Create a habit', style: t.h1),
                    const SizedBox(height: 6),
                    Text(
                      'Pick what kind of behaviour you want to track.',
                      style: t.body.copyWith(color: c.textMuted),
                    ),
                    const SizedBox(height: 26),
                    _TypeRow(
                      icon: LucideIcons.repeat,
                      label: 'Regular',
                      desc: 'Something you do consistently — '
                          'daily, weekly, or on set days.',
                      accent: c.accent,
                      selected: _selected == HabitType.positive,
                      onTap: () => _select(HabitType.positive),
                    ),
                    const SizedBox(height: 12),
                    _TypeRow(
                      icon: LucideIcons.ban,
                      label: 'Break',
                      desc: 'A behaviour you\'re quitting. '
                          'Streaks count consecutive clean days.',
                      accent: c.negative,
                      selected: _selected == HabitType.negative,
                      onTap: () => _select(HabitType.negative),
                    ),
                    const SizedBox(height: 12),
                    _TypeRow(
                      icon: LucideIcons.checkSquare,
                      label: 'Todo',
                      desc: 'A one-time task to finish by a date. '
                          'Counts toward your day, no streak.',
                      accent: c.indigo,
                      selected: _selected == HabitType.todo,
                      onTap: () => _select(HabitType.todo),
                    ),
                    const SizedBox(height: 18),
                    _ExamplesStrip(type: _selected, accent: accent),
                  ],
                ),
              ),
            ),
            // Pinned action area — the commit is always reachable without a
            // scroll, and the CTA takes on the chosen type's colour.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenH, 8, AppSpace.screenH, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.1,
                        ),
                      ),
                      onPressed: _continue,
                      child: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => context.push('/habits'),
                    icon: Icon(LucideIcons.layoutList,
                        size: 15, color: c.textMuted),
                    label: Text(
                      'View all habits',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width, self-describing type option. Selection is carried by the
/// border, a soft accent lift, the icon colour and the trailing tick — the
/// text never sits on a tint that would soften it.
class _TypeRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String desc;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _TypeRow({
    required this.icon,
    required this.label,
    required this.desc,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TypeRow> createState() => _TypeRowState();
}

class _TypeRowState extends State<_TypeRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sel = widget.selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: sel ? widget.accent.withValues(alpha: 0.07) : c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: sel ? widget.accent : c.border,
              width: sel ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: sel
                    ? widget.accent.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: sel ? 16 : 7,
                spreadRadius: sel ? -2 : 0,
                offset: Offset(0, sel ? 5 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.accent
                      .withValues(alpha: sel ? 0.16 : 0.11),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: sel ? 0.4 : 0.2),
                    width: 0.5,
                  ),
                ),
                child: Icon(widget.icon,
                    size: 21,
                    color: sel
                        ? widget.accent
                        : widget.accent.withValues(alpha: 0.85)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: c.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.desc,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: sel ? c.textSecondary : c.textMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SelectTick(selected: sel, accent: widget.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectTick extends StatelessWidget {
  final bool selected;
  final Color accent;
  const _SelectTick({required this.selected, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : c.borderStrong,
          width: selected ? 0 : 1.5,
        ),
      ),
      child: selected
          ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

/// Concrete examples for the selected type — keeps the original "nice info"
/// while the rows above carry the definitions. Swaps with a soft cross-fade.
class _ExamplesStrip extends StatelessWidget {
  final HabitType type;
  final Color accent;
  const _ExamplesStrip({required this.type, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final examples = switch (type) {
      HabitType.positive => 'morning run · read 20 min · stretch after training',
      HabitType.negative => 'no phone after 10pm · no junk food · no doomscroll',
      HabitType.todo => 'book physio · order whey · send invoice',
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(type),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.sparkles, size: 15, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                    height: 1.3,
                  ),
                  children: [
                    TextSpan(
                      text: 'For example   ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.textMuted,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                    TextSpan(text: examples),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

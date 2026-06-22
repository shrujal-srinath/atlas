import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════════
// ATLAS shared controls — the reusable interaction primitives that give
// every screen the same premium feel. Lifted out of one-off screen files
// so buttons, switches, segmented controls and cards stop being reinvented.
// Tuned light-mode-first; all colours come from `context.c`.
// ════════════════════════════════════════════════════════════════════

/// Wraps any tappable in a quick scale-down on press — the physical "give"
/// that separates a considered control from a flat one.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  final bool haptic;
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.haptic = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
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
        if (widget.haptic) HapticFeedback.selectionClick();
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

/// iOS-style switch — solid accent track when on, a white thumb that slides.
/// Pass [onChanged] to make the switch itself tappable, or omit it when the
/// surrounding row already handles the tap.
class AtlasSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? accent;
  const AtlasSwitch({super.key, required this.value, this.onChanged, this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final track = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 48,
      height: 29,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? (accent ?? c.accent) : c.borderStrong,
        borderRadius: BorderRadius.circular(99),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 23,
          height: 23,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
    if (onChanged == null) return track;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged!(!value);
      },
      child: track,
    );
  }
}

/// One segment's content for [AtlasSegmented].
class AtlasSeg {
  final String label;
  final IconData? icon;
  final String? sub;
  const AtlasSeg(this.label, {this.icon, this.sub});
}

/// iOS-style segmented control: a recessed track with a single raised thumb
/// that *slides* to the active segment. Use for any single-choice row of
/// boxes (frequency, section, priority, period, …).
class AtlasSegmented extends StatelessWidget {
  final List<AtlasSeg> items;
  final int index;
  final ValueChanged<int> onChanged;
  /// Per-segment active colour; defaults to the accent.
  final Color Function(int)? colorFor;
  final double height;
  const AtlasSegmented({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.colorFor,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = items.length;
    final hasIcons = items.any((e) => e.icon != null);
    Color colAt(int i) => colorFor?.call(i) ?? c.accent;
    final active = colAt(index);

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
            AnimatedAlign(
              alignment: n <= 1
                  ? Alignment.center
                  : Alignment(-1 + 2 * index / (n - 1), 0),
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
                    border:
                        Border.all(color: active.withValues(alpha: 0.45), width: 1),
                    boxShadow: AppShadows.card,
                  ),
                ),
              ),
            ),
            Row(
              children: List.generate(n, (i) {
                final on = i == index;
                final col = colAt(i);
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
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              it.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
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
                                color: on ? col.withValues(alpha: 0.9) : c.textDim,
                                height: 1.0,
                                fontFeatures: const [FontFeature.tabularFigures()],
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

/// Standard surface card — `c.surface`, hairline border, soft light shadow.
/// Tappable cards get press-scale feedback for free.
class AtlasCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const AtlasCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
    final tap = onTap;
    if (tap == null) return card;
    return PressScale(scale: 0.985, onTap: tap, child: card);
  }
}

/// Text/number field with the label ABOVE a clean filled box. Replaces the
/// Material floating `labelText` (which cuts across the box edge and reads as
/// broken in this design). Optional inline unit suffix; focus lights the border.
class AtlasField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final bool numeric;
  final bool autofocus;
  final bool big;
  const AtlasField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.numeric = false,
    this.autofocus = false,
    this.big = false,
  });

  @override
  State<AtlasField> createState() => _AtlasFieldState();
}

class _AtlasFieldState extends State<AtlasField> {
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
    final t = context.t;
    final focused = _focus.hasFocus;
    final valueStyle = widget.big
        ? AppType.numLg.copyWith(color: c.textPrimary, fontSize: 24)
        : t.body.copyWith(fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: t.label),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: focused ? c.accent.withValues(alpha: 0.6) : c.border,
              width: focused ? 1 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  keyboardType: widget.numeric
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : null,
                  style: valueStyle,
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: widget.big ? 15 : 14),
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: valueStyle.copyWith(
                        color: c.textDim, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.suffix!,
                  style: t.meta
                      .copyWith(color: c.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum AtlasButtonVariant { primary, secondary, tonal }

/// The one button to replace thin/pale `OutlinedButton`s. Substantial height,
/// press-scale, three weights: filled accent (primary), bordered surface
/// (secondary), and tinted (tonal).
class AtlasButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AtlasButtonVariant variant;
  final Color? color;
  final double height;
  final bool expand;
  final bool loading;
  const AtlasButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AtlasButtonVariant.primary,
    this.color,
    this.height = 52,
    this.expand = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = color ?? c.accent;
    // "inactive" = no handler. While loading we keep the active look + spinner.
    final inactive = onPressed == null && !loading;

    final (Color bg, Color fg, Border? border, List<BoxShadow>? shadow) =
        switch (variant) {
      AtlasButtonVariant.primary => (
          accent,
          c.onAccent,
          null,
          [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5))],
        ),
      AtlasButtonVariant.secondary => (
          c.surface,
          c.textPrimary,
          Border.all(color: c.borderStrong, width: 1),
          AppShadows.card,
        ),
      AtlasButtonVariant.tonal => (
          accent.withValues(alpha: 0.12),
          accent,
          Border.all(color: accent.withValues(alpha: 0.25), width: 1),
          null,
        ),
    };

    final content = Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: inactive ? c.surfaceElevated : bg,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: border,
        boxShadow: inactive ? null : shadow,
      ),
      child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
            )
          : Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: inactive ? c.textDim : fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                    color: inactive ? c.textDim : fg,
                  ),
                ),
              ],
            ),
    );

    final sized = expand ? SizedBox(width: double.infinity, child: content) : content;
    if (onPressed == null || loading) return sized;
    return PressScale(scale: 0.97, onTap: onPressed!, child: sized);
  }
}

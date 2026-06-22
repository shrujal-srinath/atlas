import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/food.dart';

/// Bottom-floating confirmation toast for food logs. Replaces the legacy
/// SnackBar so meal deltas (kcal + macros) read at a glance with colour tints.
///
/// Use [show] from any tap handler with the logged [Nutrients] delta.
class LogConfirmationToast {
  static OverlayEntry? _current;
  static AnimationController? _ctrl;

  static void show(BuildContext context, Nutrients delta, {String? slotLabel}) {
    HapticFeedback.mediumImpact();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _dismiss();

    final entry = OverlayEntry(
      builder: (ctx) => _ToastBody(delta: delta, slotLabel: slotLabel),
    );
    _current = entry;
    overlay.insert(entry);

    // Auto-dismiss after 1.6s.
    Future.delayed(const Duration(milliseconds: 1600), () => _dismiss());
  }

  static void _dismiss() {
    _current?.remove();
    _current = null;
    _ctrl?.dispose();
    _ctrl = null;
  }
}

class _ToastBody extends StatefulWidget {
  final Nutrients delta;
  final String? slotLabel;
  const _ToastBody({required this.delta, this.slotLabel});

  @override
  State<_ToastBody> createState() => _ToastBodyState();
}

class _ToastBodyState extends State<_ToastBody> with TickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _ac.reverse();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final media = MediaQuery.of(context);
    final bottom = media.padding.bottom + media.viewInsets.bottom + 80;

    return Positioned(
      left: AppSpace.screenH,
      right: AppSpace.screenH,
      bottom: bottom,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: c.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.check_rounded, size: 18, color: c.onAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Hide the "+ 0 kcal" prefix for non-food deltas
                            // (e.g. water, quick chips) where the slot label
                            // already carries the meaningful message.
                            if (widget.delta.kcal > 0)
                              Text('+ ${widget.delta.kcal.round()} kcal',
                                  style: AppType.numMd.copyWith(color: c.textPrimary)),
                            if (widget.slotLabel != null) ...[
                              if (widget.delta.kcal > 0)
                                const SizedBox(width: 8),
                              Text(
                                widget.delta.kcal > 0
                                    ? '· ${widget.slotLabel!.toUpperCase()}'
                                    : widget.slotLabel!.toUpperCase(),
                                style: AppType.numMd.copyWith(
                                  color: widget.delta.kcal > 0
                                      ? c.textMuted
                                      : c.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (widget.delta.kcal > 0) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _macro('P', widget.delta.proteinG, c.athletic),
                              const SizedBox(width: 10),
                              _macro('C', widget.delta.carbsG, c.amber),
                              const SizedBox(width: 10),
                              _macro('F', widget.delta.fatG, c.mind),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _macro(String label, double v, Color tint) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: AppType.overline.copyWith(color: tint, letterSpacing: 0.4)),
        const SizedBox(width: 3),
        Text('+${v.round()}g',
            style: AppType.numMd.copyWith(color: tint, fontSize: 12)),
      ],
    );
  }
}

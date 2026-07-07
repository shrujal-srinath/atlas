import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a tappable surface with a subtle press-scale + selection haptic — the
/// "this app sweats the details" feel. Shared so cards across Stats, Home, Food
/// etc. all get identical, tactile, visible feedback instead of feeling dead.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;
  final bool haptics;
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.985,
    this.haptics = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  void _set(bool v) {
    if (v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () {
        if (widget.haptics) HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

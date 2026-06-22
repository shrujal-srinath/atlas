import 'package:flutter/material.dart';
import '../style/auth_style.dart';

/// Full-bleed living gradient for the auth flow: lerps between two colour
/// sets and gently rotates the gradient axis on a slow, reversing loop.
/// Light, cinematic, and dependency-free (no Lottie/Rive).
class AnimatedGradientCanvas extends StatefulWidget {
  final Widget child;
  const AnimatedGradientCanvas({super.key, required this.child});

  @override
  State<AnimatedGradientCanvas> createState() => _AnimatedGradientCanvasState();
}

class _AnimatedGradientCanvasState extends State<AnimatedGradientCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AuthMotion.gradient)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final colors = <Color>[
          for (var i = 0; i < AuthColors.gradientA.length; i++)
            Color.lerp(AuthColors.gradientA[i], AuthColors.gradientB[i], t)!,
        ];
        final shift = t * 0.6;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment(-1 + shift, -1),
              end: Alignment(1, 1 - shift),
              stops: const [0.0, 0.38, 0.66, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

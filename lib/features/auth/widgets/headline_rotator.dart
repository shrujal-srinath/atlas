import 'dart:async';
import 'package:flutter/material.dart';
import '../style/auth_style.dart';

/// Rotating value-prop headline that advertises what the app does — a light
/// stand-in alongside the demo-video placeholder. Fades + slides between
/// phrases on a timer.
class HeadlineRotator extends StatefulWidget {
  final List<String> phrases;
  const HeadlineRotator({super.key, required this.phrases});

  @override
  State<HeadlineRotator> createState() => _HeadlineRotatorState();
}

class _HeadlineRotatorState extends State<HeadlineRotator> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(AuthMotion.headlineInterval, (_) {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % widget.phrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AuthMotion.headlineSwitch,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.28),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        widget.phrases[_i],
        key: ValueKey(_i),
        style: AuthType.headline,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A number that animates (counts up) to [value] — from 0 on first appearance,
/// then from the previous value whenever it changes. The small "effort shows"
/// detail on headline metrics. Uses tabular figures so the width doesn't jitter.
class AnimatedCount extends StatelessWidget {
  final num value;
  final TextStyle style;
  final Duration duration;
  final String prefix;
  final String suffix;
  final int decimals;
  const AnimatedCount(
    this.value, {
    super.key,
    required this.style,
    this.duration = const Duration(milliseconds: 650),
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(
        '$prefix${v.toStringAsFixed(decimals)}$suffix',
        style: style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

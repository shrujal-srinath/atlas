import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Pulse-shimmer skeleton placeholder used during initial loads.
///
/// Built on a single [AnimationController] driving an Opacity tween so the
/// surface "breathes" at ~1.2s per cycle without using shader-based shimmer
/// (which costs more on low-end devices).
enum AtlasSkeletonVariant { card, listRow, ring, sparkline }

class AtlasSkeleton extends StatefulWidget {
  final AtlasSkeletonVariant variant;
  final int rows;

  /// For [variant] == [AtlasSkeletonVariant.card], how tall the card should be.
  final double cardHeight;

  const AtlasSkeleton.card({super.key, this.cardHeight = 160})
      : variant = AtlasSkeletonVariant.card,
        rows = 1;

  const AtlasSkeleton.listRow({super.key, this.rows = 4})
      : variant = AtlasSkeletonVariant.listRow,
        cardHeight = 0;

  const AtlasSkeleton.ring({super.key})
      : variant = AtlasSkeletonVariant.ring,
        rows = 1,
        cardHeight = 0;

  const AtlasSkeleton.sparkline({super.key})
      : variant = AtlasSkeletonVariant.sparkline,
        rows = 1,
        cardHeight = 0;

  @override
  State<AtlasSkeleton> createState() => _AtlasSkeletonState();
}

class _AtlasSkeletonState extends State<AtlasSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) {
        final tint = c.surfaceElevated.withValues(alpha: _opacity.value);
        switch (widget.variant) {
          case AtlasSkeletonVariant.card:
            return _block(tint, height: widget.cardHeight, radius: AppRadii.card);
          case AtlasSkeletonVariant.listRow:
            return Column(
              children: [
                for (int i = 0; i < widget.rows; i++) ...[
                  _block(tint, height: 62, radius: AppRadii.card),
                  const SizedBox(height: 10),
                ],
              ],
            );
          case AtlasSkeletonVariant.ring:
            return Center(
              child: Container(
                width: 132, height: 132,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                ),
              ),
            );
          case AtlasSkeletonVariant.sparkline:
            return _block(tint, height: 28, radius: AppRadii.chip);
        }
      },
    );
  }

  Widget _block(Color color, {required double height, required double radius}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

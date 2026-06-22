import 'package:flutter/material.dart';
import '../style/auth_style.dart';

/// A 16:10 stand-in for the future product demo video. Soft glass frame with a
/// play glyph + caption — swap the inner content for a real player later.
class DemoVideoPlaceholder extends StatelessWidget {
  const DemoVideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x3DFFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AuthColors.glassBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color: AuthColors.shadow,
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AuthColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AuthColors.accent.withValues(alpha: 0.4),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 14),
              Text('Demo video goes here',
                  style: AuthType.label.copyWith(color: AuthColors.inkSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

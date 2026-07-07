import 'package:flutter/material.dart';
import '../style/auth_style.dart';

/// A stand-in for the future product demo video. Soft glass frame with a
/// play glyph + caption — swap the inner content for a real player later.
///
/// By default it keeps a 16:10 frame; set [expand] to let it fill whatever
/// height the parent gives it (used as the dominant hero on the login screen).
class DemoVideoPlaceholder extends StatelessWidget {
  final bool expand;
  const DemoVideoPlaceholder({super.key, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final frame = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x59FFFFFF), Color(0x26FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AuthColors.glassBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AuthColors.shadow,
            blurRadius: 38,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AuthColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AuthColors.accent.withValues(alpha: 0.42),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Demo video goes here',
              style: AuthType.label.copyWith(color: AuthColors.inkSecondary),
            ),
          ],
        ),
      ),
    );

    return expand ? frame : AspectRatio(aspectRatio: 16 / 10, child: frame);
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../style/auth_style.dart';
import 'animated_gradient_canvas.dart';

/// Shared shell for the secondary auth screens (signup · forgot-password):
/// the same living gradient canvas + a back affordance, branded header, and a
/// free-floating frosted-glass panel holding the form. Keeps the whole auth
/// flow visually one piece with the redesigned login.
class GlassAuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  const GlassAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientCanvas(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AuthSpace.gutter, 10, AuthSpace.gutter, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: _BackCircle()),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(width: 24, height: 3, color: AuthColors.accent),
                    const SizedBox(width: 8),
                    Text('PERFORMANCE OS', style: AuthType.eyebrow),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title, style: AuthType.headline),
                const SizedBox(height: 8),
                Text(subtitle,
                    style:
                        AuthType.body.copyWith(color: AuthColors.inkSecondary)),
                const SizedBox(height: 24),
                _GlassPanel(child: child),
                if (footer != null) ...[
                  const SizedBox(height: 20),
                  Center(child: footer!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          context.canPop() ? context.pop() : context.go('/login'),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x73FFFFFF),
          shape: BoxShape.circle,
          border: Border.all(color: AuthColors.glassBorder, width: 1),
        ),
        child: const Icon(LucideIcons.chevronLeft,
            size: 22, color: AuthColors.ink),
      ),
    );
  }
}

/// Free-floating frosted panel (all corners rounded) for the secondary forms.
class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: AuthColors.glassFill,
            borderRadius: radius,
            border: Border.all(color: AuthColors.glassBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AuthColors.shadow,
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

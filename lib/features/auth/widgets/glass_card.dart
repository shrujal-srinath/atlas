import 'dart:ui';
import 'package:flutter/material.dart';
import '../style/auth_style.dart';

/// Frosted-glass surface — the bottom login unit's container. A real backdrop
/// blur over the living gradient + a translucent white fill.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 18, 22, 20),
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(
      top: Radius.circular(AuthSpace.cardRadius),
    );
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: const BoxDecoration(
            color: AuthColors.glassFill,
            borderRadius: radius,
            border: Border(
              top: BorderSide(color: AuthColors.glassBorder, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: AuthColors.shadow,
                blurRadius: 40,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shared input decoration for fields living inside the glass card.
InputDecoration authFieldDecoration({
  required String hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AuthSpace.fieldRadius),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: AuthType.body.copyWith(color: AuthColors.inkMuted),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: true,
    filled: true,
    fillColor: AuthColors.glassFieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(AuthColors.fieldBorder, 1),
    enabledBorder: border(AuthColors.fieldBorder, 1),
    focusedBorder: border(AuthColors.accent, 1.5),
  );
}

/// Primary ink CTA with press-scale + a built-in loading state.
class AuthPrimaryButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: AuthMotion.press,
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? AuthColors.accent
                : AuthColors.accent.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AuthSpace.buttonRadius),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AuthColors.accent.withValues(alpha: 0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.label, style: AuthType.button),
        ),
      ),
    );
  }
}

/// Solid white "Continue with Google" button (glass-era variant) with a
/// press-scale "give" matching the primary CTA.
class AuthGoogleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool loading;
  const AuthGoogleButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<AuthGoogleButton> createState() => _AuthGoogleButtonState();
}

class _AuthGoogleButtonState extends State<AuthGoogleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: AuthMotion.press,
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AuthSpace.buttonRadius),
            border: Border.all(color: const Color(0x1A15171C)),
            boxShadow: const [
              BoxShadow(
                color: AuthColors.shadow,
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AuthColors.ink,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleG(size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: AuthType.button.copyWith(color: AuthColors.ink),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary auth action (e.g. "Continue with email") — a defined surface +
/// border control with high-contrast ink text and a leading glyph. Deliberately
/// NOT a tinted ghost: it reads as a real, tappable button beside the white
/// Google CTA, while staying visually subordinate to it.
class AuthSecondaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<AuthSecondaryButton> createState() => _AuthSecondaryButtonState();
}

class _AuthSecondaryButtonState extends State<AuthSecondaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: AuthMotion.press,
        curve: Curves.easeOut,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x59FFFFFF), // translucent surface (~35%)
            borderRadius: BorderRadius.circular(AuthSpace.buttonRadius),
            border: Border.all(color: const Color(0x331B1714), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: AuthColors.ink),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: AuthType.button.copyWith(color: AuthColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "──── or ────" separator.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AuthColors.hairline, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: AuthType.label.copyWith(color: AuthColors.inkSecondary),
          ),
        ),
        const Expanded(child: Divider(color: AuthColors.hairline, height: 1)),
      ],
    );
  }
}

// ── Official Google "G" mark ─────────────────────────────────────────
// The real four-colour logo, traced from Google's 48×48 brand SVG and drawn
// as filled vector paths (no asset / package dependency). Replaces the old
// hand-rolled arc approximation, which read as off-brand.
class _GoogleG extends StatelessWidget {
  final double size;
  const _GoogleG({this.size = 18});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleGPainter());
}

class _GoogleGPainter extends CustomPainter {
  static final Path _blue = Path()
    ..moveTo(46.98, 24.55)
    ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.60, 20.00)
    ..lineTo(24.00, 20.00)
    ..lineTo(24.00, 29.02)
    ..lineTo(36.94, 29.02)
    ..cubicTo(36.36, 31.98, 34.68, 34.50, 32.16, 36.20)
    ..lineTo(39.89, 42.20)
    ..cubicTo(44.40, 38.02, 46.98, 31.84, 46.98, 24.55)
    ..close();

  static final Path _green = Path()
    ..moveTo(24.00, 48.00)
    ..cubicTo(30.48, 48.00, 35.93, 45.87, 39.89, 42.19)
    ..lineTo(32.16, 36.19)
    ..cubicTo(30.01, 37.64, 27.24, 38.49, 24.00, 38.49)
    ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
    ..lineTo(2.55, 34.77)
    ..cubicTo(6.51, 42.62, 14.62, 48.00, 24.00, 48.00)
    ..close();

  static final Path _yellow = Path()
    ..moveTo(10.53, 28.59)
    ..cubicTo(10.05, 27.14, 9.77, 25.60, 9.77, 24.00)
    ..cubicTo(9.77, 22.40, 10.04, 20.86, 10.53, 19.41)
    ..lineTo(2.55, 13.22)
    ..cubicTo(0.92, 16.46, 0.00, 20.12, 0.00, 24.00)
    ..cubicTo(0.00, 27.88, 0.92, 31.54, 2.56, 34.78)
    ..lineTo(10.53, 28.59)
    ..close();

  static final Path _red = Path()
    ..moveTo(24.00, 9.50)
    ..cubicTo(27.54, 9.50, 30.71, 10.72, 33.21, 13.10)
    ..lineTo(40.06, 6.25)
    ..cubicTo(35.90, 2.38, 30.47, 0.00, 24.00, 0.00)
    ..cubicTo(14.62, 0.00, 6.51, 5.38, 2.56, 13.22)
    ..lineTo(10.54, 19.41)
    ..cubicTo(12.43, 13.72, 17.74, 9.50, 24.00, 9.50)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48.0);
    final p = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawPath(_blue, p..color = const Color(0xFF4285F4));
    canvas.drawPath(_green, p..color = const Color(0xFF34A853));
    canvas.drawPath(_yellow, p..color = const Color(0xFFFBBC05));
    canvas.drawPath(_red, p..color = const Color(0xFFEA4335));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

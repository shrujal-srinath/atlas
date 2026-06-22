import 'dart:math' as math;
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
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 22),
  });

  @override
  Widget build(BuildContext context) {
    const radius =
        BorderRadius.vertical(top: Radius.circular(AuthSpace.cardRadius));
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
          height: 54,
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
                      strokeWidth: 2.2, color: Colors.white),
                )
              : Text(widget.label, style: AuthType.button),
        ),
      ),
    );
  }
}

/// Solid white "Continue with Google" button (glass-era variant).
class AuthGoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  const AuthGoogleButton({super.key, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
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
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AuthColors.ink),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleG(size: 18),
                  const SizedBox(width: 10),
                  Text('Continue with Google',
                      style: AuthType.button.copyWith(color: AuthColors.ink)),
                ],
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
          child: Text('or',
              style: AuthType.label.copyWith(color: AuthColors.inkMuted)),
        ),
        const Expanded(child: Divider(color: AuthColors.hairline, height: 1)),
      ],
    );
  }
}

// ── Google "G" mark (four arcs + crossbar, no asset dependency) ──────
class _GoogleG extends StatelessWidget {
  final double size;
  const _GoogleG({this.size = 18});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleGPainter());
}

class _GoogleGPainter extends CustomPainter {
  double _rad(double deg) => deg * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.26;
    final rect = Rect.fromCircle(
      center: Offset(w / 2, w / 2),
      radius: (w - stroke) / 2,
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, _rad(25), _rad(80), false, p..color = const Color(0xFF34A853));
    canvas.drawArc(rect, _rad(110), _rad(80), false, p..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, _rad(195), _rad(80), false, p..color = const Color(0xFFEA4335));
    canvas.drawArc(rect, _rad(280), _rad(55), false, p..color = const Color(0xFF4285F4));
    canvas.drawRect(
      Rect.fromLTWH(w / 2, w / 2 - stroke / 2, w / 2, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

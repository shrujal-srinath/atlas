import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/auth_provider.dart';
import '../style/auth_style.dart';
import '../widgets/glass_auth_scaffold.dart';
import '../widgets/glass_card.dart';
import '../../../shared/widgets/app_snackbar.dart';

/// Password recovery in two in-app phases — no deep-link required:
///   1. Enter email  → email a 6-digit recovery code.
///   2. Enter the code + a new password → verify + update, then go home.
/// Styled on the redesigned cinematic / glass auth identity.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  int _phase = 0; // 0 = request, 1 = verify
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _email => _emailCtrl.text.trim();

  Future<void> _sendCode() async {
    if (!isValidEmail(_email)) {
      return showSnack(context, 'Enter a valid email address.', isError: true);
    }
    setState(() => _loading = true);
    try {
      await ref.read(authNotifierProvider.notifier).sendPasswordReset(_email);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _phase = 1);
      showSnack(context, 'We emailed a 6-digit code to $_email.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (code.length < 6) {
      return showSnack(context, 'Enter the 6-digit code from your email.',
          isError: true);
    }
    if (password.length < 8) {
      return showSnack(context, 'Password must be at least 8 characters.',
          isError: true);
    }
    setState(() => _loading = true);
    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(
            email: _email,
            code: code,
            newPassword: password,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showSnack(context, 'Password updated — you’re signed in.');
      context.go('/home');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerify = _phase == 1;
    return GlassAuthScaffold(
      title: isVerify ? 'Enter your code' : 'Reset password',
      subtitle: isVerify
          ? 'Enter the code we emailed to $_email, then choose a new password.'
          : "Enter your account email and we'll send a 6-digit recovery code.",
      footer: isVerify ? _verifyFooter() : _requestFooter(),
      child: isVerify ? _verifyCard() : _requestCard(),
    );
  }

  Widget _requestCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Email', style: AuthType.label),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          autofocus: true,
          onSubmitted: (_) => _sendCode(),
          cursorColor: AuthColors.ink,
          style: AuthType.body,
          decoration: authFieldDecoration(
            hint: 'you@example.com',
            prefixIcon:
                const Icon(LucideIcons.mail, size: 18, color: AuthColors.inkMuted),
          ),
        ),
        const SizedBox(height: 18),
        AuthPrimaryButton(
          label: 'Send code',
          loading: _loading,
          onPressed: _sendCode,
        ),
      ],
    );
  }

  Widget _requestFooter() {
    return GestureDetector(
      onTap: () => context.pop(),
      behavior: HitTestBehavior.opaque,
      child: Text('Back to sign in',
          style: AuthType.label.copyWith(color: AuthColors.inkMuted)),
    );
  }

  Widget _verifyCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Recovery code', style: AuthType.label),
        const SizedBox(height: 6),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          cursorColor: AuthColors.ink,
          style: AuthType.body.copyWith(
              letterSpacing: 10, fontWeight: FontWeight.w700, fontSize: 22),
          decoration:
              authFieldDecoration(hint: '123456').copyWith(counterText: ''),
        ),
        const SizedBox(height: 14),
        const Text('New password', style: AuthType.label),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _resetPassword(),
          cursorColor: AuthColors.ink,
          style: AuthType.body,
          decoration: authFieldDecoration(
            hint: 'At least 8 characters',
            prefixIcon:
                const Icon(LucideIcons.lock, size: 18, color: AuthColors.inkMuted),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18, color: AuthColors.inkMuted),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AuthPrimaryButton(
          label: 'Reset password',
          loading: _loading,
          onPressed: _resetPassword,
        ),
      ],
    );
  }

  Widget _verifyFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _loading ? null : () => setState(() => _phase = 0),
          behavior: HitTestBehavior.opaque,
          child: Text('Use a different email',
              style: AuthType.label.copyWith(color: AuthColors.inkMuted)),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _loading ? null : _sendCode,
          behavior: HitTestBehavior.opaque,
          child: const Text('Resend code', style: AuthType.link),
        ),
      ],
    );
  }
}

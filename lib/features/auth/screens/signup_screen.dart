import 'dart:async';

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

/// Account creation in two in-app phases — no confirmation-link round-trip:
///   0. Name + email + password → register and email a 6-digit code.
///   1. Enter the code → verify, which lands a session and routes onward.
/// Styled on the redesigned cinematic / glass auth identity.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  int _phase = 0; // 0 = details, 1 = verify code
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;

  // Resend cooldown — prevents spamming the email-code endpoint with no
  // feedback about why nothing seems to happen.
  static const _resendCooldown = Duration(seconds: 30);
  Timer? _cooldownTicker;
  int _cooldownSecs = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _cooldownTicker?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTicker?.cancel();
    setState(() => _cooldownSecs = _resendCooldown.inSeconds);
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldownSecs <= 1) {
        t.cancel();
        setState(() => _cooldownSecs = 0);
      } else {
        setState(() => _cooldownSecs -= 1);
      }
    });
  }

  String get _email => _emailCtrl.text.trim();

  Future<void> _createAccount() async {
    final name = _nameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.isEmpty) {
      return showSnack(context, 'Enter your name.', isError: true);
    }
    if (!isValidEmail(_email)) {
      return showSnack(context, 'Enter a valid email address.', isError: true);
    }
    if (password.length < 8) {
      return showSnack(context, 'Password must be at least 8 characters.',
          isError: true);
    }

    setState(() => _loading = true);
    await ref.read(authNotifierProvider.notifier).signUp(_email, password, name);
    if (!mounted) return;
    setState(() => _loading = false);

    // signUp() routes errors through AsyncValue.guard (it does not throw), so
    // inspect the notifier state rather than relying on a try/catch.
    final state = ref.read(authNotifierProvider);
    if (state is AsyncError) {
      showErrorSnack(context, state.error);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _phase = 1);
    _startCooldown();
    showSnack(context, 'We emailed a 6-digit code to $_email.');
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      return showSnack(context, 'Enter the 6-digit code from your email.',
          isError: true);
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .verifySignup(email: _email, code: code);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showSnack(context, 'Email verified — welcome to STRIDE.');
      // Navigation is handled by the router redirect (signup → splash →
      // onboarding once the session lands) — hardcoding /home here would flash
      // the home page before the onboarding gate resolves.
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldownSecs > 0) return;
    try {
      await ref.read(authNotifierProvider.notifier).resendSignupCode(_email);
      if (!mounted) return;
      _startCooldown();
      showSnack(context, 'New code sent to $_email.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _google() async {
    setState(() => _googleLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerify = _phase == 1;
    return GlassAuthScaffold(
      title: isVerify ? 'Verify your email' : 'Create your account',
      subtitle: isVerify
          ? 'Enter the 6-digit code we sent to $_email.'
          : 'Set up STRIDE in under a minute.',
      footer: isVerify ? _verifyFooter() : _detailsFooter(),
      child: isVerify ? _verifyCard() : _detailsCard(),
    );
  }

  // ── Phase 0: details ──────────────────────────────────────────
  Widget _detailsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthGoogleButton(onPressed: _google, loading: _googleLoading),
        const SizedBox(height: 16),
        const AuthOrDivider(),
        const SizedBox(height: 16),
        const Text('Name', style: AuthType.label),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          cursorColor: AuthColors.ink,
          style: AuthType.body,
          decoration: authFieldDecoration(
            hint: 'Your name',
            prefixIcon:
                const Icon(LucideIcons.user, size: 18, color: AuthColors.inkMuted),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Email', style: AuthType.label),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          cursorColor: AuthColors.ink,
          style: AuthType.body,
          decoration: authFieldDecoration(
            hint: 'you@example.com',
            prefixIcon:
                const Icon(LucideIcons.mail, size: 18, color: AuthColors.inkMuted),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Password', style: AuthType.label),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _createAccount(),
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
          label: 'Create account',
          loading: _loading,
          onPressed: _createAccount,
        ),
      ],
    );
  }

  Widget _detailsFooter() {
    return GestureDetector(
      onTap: () => context.pop(),
      behavior: HitTestBehavior.opaque,
      child: Text.rich(
        textAlign: TextAlign.center,
        TextSpan(
          text: 'Already have an account?  ',
          style: AuthType.body.copyWith(color: AuthColors.inkSecondary, fontSize: 13.5),
          children: const [
            TextSpan(text: 'Sign in', style: AuthType.link),
          ],
        ),
      ),
    );
  }

  // ── Phase 1: verify code ──────────────────────────────────────
  Widget _verifyCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('6-digit code', style: AuthType.label),
        const SizedBox(height: 6),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofocus: true,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _verify(),
          textAlign: TextAlign.center,
          cursorColor: AuthColors.ink,
          style: AuthType.body.copyWith(
              letterSpacing: 10, fontWeight: FontWeight.w700, fontSize: 22),
          decoration:
              authFieldDecoration(hint: '123456').copyWith(counterText: ''),
        ),
        const SizedBox(height: 18),
        AuthPrimaryButton(
          label: 'Verify & continue',
          loading: _loading,
          onPressed: _verify,
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: (_loading || _cooldownSecs > 0) ? null : _resend,
            child: Text(
              _cooldownSecs > 0
                  ? 'Resend code (${_cooldownSecs}s)'
                  : 'Resend code',
              style: AuthType.link.copyWith(
                color: _cooldownSecs > 0
                    ? AuthColors.inkSecondary
                    : AuthColors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _verifyFooter() {
    return GestureDetector(
      onTap: () => setState(() => _phase = 0),
      behavior: HitTestBehavior.opaque,
      child: Text('Use a different email',
          textAlign: TextAlign.center,
          style: AuthType.label.copyWith(color: AuthColors.inkSecondary)),
    );
  }
}

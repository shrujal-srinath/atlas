import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/auth_provider.dart';
import '../style/auth_style.dart';
import '../widgets/animated_gradient_canvas.dart';
import '../widgets/demo_video_placeholder.dart';
import '../widgets/glass_card.dart';
import '../widgets/headline_rotator.dart';
import '../../../core/dev/dev_unlock.dart';
import '../../../shared/widgets/app_snackbar.dart';

/// Cinematic, light-mode login: a living gradient canvas with a hero
/// (wordmark · demo-video placeholder · rotating headline) above a frosted-
/// glass login unit. Signing in morphs the card into a branded loader that
/// holds until the router lands on home. Self-contained styling — see
/// `auth/style/auth_style.dart`; the rest of the app's theme is untouched.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _googleLoading = false;
  bool _launching = false;
  late final AnimationController _entrance;

  static const _headlines = [
    'Train like a pro.',
    'Fuel with intent.',
    'Level up daily.',
  ];

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: AuthMotion.entrance)
      ..forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _entrance.dispose();
    super.dispose();
  }

  // Staggered fade-rise entrance for a hero element at [order].
  Widget _rise(int order, Widget child) {
    final start = (order * 0.1).clamp(0.0, 0.5);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
            offset: Offset(0, (1 - anim.value) * 18), child: c),
      ),
      child: child,
    );
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (!isValidEmail(email)) {
      return showSnack(context, 'Enter a valid email address.', isError: true);
    }
    if (password.isEmpty) {
      return showSnack(context, 'Enter your password.', isError: true);
    }
    FocusScope.of(context).unfocus();
    setState(() => _launching = true);
    final started = DateTime.now();

    await ref.read(authNotifierProvider.notifier).signIn(email, password);
    if (!mounted) return;

    final state = ref.read(authNotifierProvider);
    if (state is AsyncError) {
      setState(() => _launching = false);
      showErrorSnack(context, state.error);
      return;
    }
    // Success: hold the branded loader for a minimum beat so the hand-off to
    // home never flashes; the router's auth-state listener does the routing.
    final elapsed = DateTime.now().difference(started);
    const minHold = Duration(milliseconds: 500);
    if (elapsed < minHold) await Future.delayed(minHold - elapsed);
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
    return Scaffold(
      body: AnimatedGradientCanvas(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Hero fills the space above the pinned login bar; centered when
              // there's room, scrollable when the viewport (or keyboard) squeezes.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: _hero(),
                    ),
                  ),
                ),
              ),
              // Pinned frosted login bar with a slide-up entrance.
              AnimatedBuilder(
                animation: _entrance,
                builder: (_, child) {
                  final v = Curves.easeOutCubic.transform(_entrance.value);
                  return Transform.translate(
                      offset: Offset(0, (1 - v) * 44), child: child);
                },
                child: _loginUnit(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────
  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AuthSpace.gutter, 18, AuthSpace.gutter, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rise(
            0,
            Row(
              children: [
                Container(width: 24, height: 3, color: AuthColors.accent),
                const SizedBox(width: 8),
                Text('PERFORMANCE OS', style: AuthType.eyebrow),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _rise(0, const Text('ATLAS', style: AuthType.wordmark)),
          const SizedBox(height: 24),
          _rise(1, const DemoVideoPlaceholder()),
          const SizedBox(height: 24),
          _rise(2, const HeadlineRotator(phrases: _headlines)),
          const SizedBox(height: 8),
          _rise(
            2,
            Text(
              'Your daily system for training, fuel, and progress.',
              style: AuthType.body.copyWith(color: AuthColors.inkSecondary),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Bottom login unit ───────────────────────────────────────────
  Widget _loginUnit() {
    return GlassCard(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _launching ? _launchingView() : _form(),
      ),
    );
  }

  Widget _form() {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Welcome back', style: AuthType.title),
        const SizedBox(height: 4),
        Text('Sign in to continue your performance log.',
            style: AuthType.body.copyWith(color: AuthColors.inkSecondary)),
        const SizedBox(height: 18),
        AuthGoogleButton(onPressed: _google, loading: _googleLoading),
        const SizedBox(height: 16),
        const AuthOrDivider(),
        const SizedBox(height: 16),
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
          onSubmitted: (_) => _signIn(),
          cursorColor: AuthColors.ink,
          style: AuthType.body,
          decoration: authFieldDecoration(
            hint: '••••••••',
            prefixIcon:
                const Icon(LucideIcons.lock, size: 18, color: AuthColors.inkMuted),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18, color: AuthColors.inkMuted),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => context.push('/forgot-password'),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Forgot password?', style: AuthType.link),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(label: 'Sign in', onPressed: _signIn),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => context.push('/signup'),
            behavior: HitTestBehavior.opaque,
            child: Text.rich(
              TextSpan(
                text: 'New here?  ',
                style: AuthType.body
                    .copyWith(color: AuthColors.inkMuted, fontSize: 13.5),
                children: const [
                  TextSpan(text: 'Create account', style: AuthType.link),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: _devChip()),
        SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 6),
      ],
    );
  }

  Widget _devChip() {
    return GestureDetector(
      onTap: () => enterDevMode(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AuthColors.fieldBorder),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.terminal, size: 14, color: AuthColors.inkMuted),
            const SizedBox(width: 7),
            Text('Dev access',
                style: AuthType.label.copyWith(color: AuthColors.inkMuted)),
          ],
        ),
      ),
    );
  }

  Widget _launchingView() {
    return Padding(
      key: const ValueKey('launching'),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ATLAS', style: AuthType.title),
          const SizedBox(height: 20),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: AuthColors.accent),
          ),
          const SizedBox(height: 16),
          Text('Setting up your day…',
              style: AuthType.body.copyWith(color: AuthColors.inkSecondary)),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 6),
        ],
      ),
    );
  }
}

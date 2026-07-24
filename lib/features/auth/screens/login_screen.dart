import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/dev/dev_unlock.dart';
import '../../../core/utils/app_logger.dart';
import '../providers/auth_provider.dart';
import '../style/auth_style.dart';
import '../widgets/animated_gradient_canvas.dart';
import '../widgets/demo_video_placeholder.dart';
import '../widgets/glass_card.dart';
import '../widgets/headline_rotator.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/brand_mark.dart';

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
  final _emailFocus = FocusNode();
  bool _obscure = true;
  bool _googleLoading = false;
  bool _launching = false;
  // Progressive disclosure: the bottom unit rests as a compact chooser
  // (Google · email · create account) and only expands to the full
  // email/password form once the user opts into signing in with email.
  bool _emailMode = false;
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
    _emailFocus.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _openEmail() {
    setState(() => _emailMode = true);
    // Focus the email field once the expand settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

  void _closeEmail() {
    FocusScope.of(context).unfocus();
    setState(() => _emailMode = false);
  }

  // Staggered fade-rise entrance for a hero element at [order].
  Widget _rise(int order, Widget child) {
    final start = (order * 0.1).clamp(0.0, 0.5);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(
        start,
        (start + 0.5).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 18),
          child: c,
        ),
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

    // Demo account: the well-known demo credentials drop straight into the app
    // with sample data (dev mode) — no Supabase call, no real account needed.
    if (isDemoCredential(email, password)) {
      enterDevMode(context, ref);
      return;
    }

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
    } catch (e, st) {
      logError(e, st);
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
              // Hero owns the bulk of the screen — brand + a dominant demo
              // reel. Centred when there's room, scrollable when the viewport
              // (or keyboard) squeezes.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: _hero(box.maxHeight),
                    ),
                  ),
                ),
              ),
              // Pinned frosted login unit with a slide-up entrance. Compact at
              // rest; morphs taller only when the email form is revealed.
              AnimatedBuilder(
                animation: _entrance,
                builder: (_, child) {
                  final v = Curves.easeOutCubic.transform(_entrance.value);
                  return Transform.translate(
                    offset: Offset(0, (1 - v) * 44),
                    child: child,
                  );
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
  Widget _hero(double availH) {
    // Hand the demo reel the lion's share of the hero; clamp so it stays
    // sensible on very short and very tall devices.
    final demoH = (availH - 252).clamp(196.0, 460.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuthSpace.gutter,
        18,
        AuthSpace.gutter,
        14,
      ),
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
          _rise(0, const Text('STRIDE', style: AuthType.wordmark)),
          const SizedBox(height: 22),
          _rise(
            1,
            SizedBox(
              height: demoH,
              child: const DemoVideoPlaceholder(expand: true),
            ),
          ),
          const SizedBox(height: 22),
          _rise(2, const HeadlineRotator(phrases: _headlines)),
          const SizedBox(height: 8),
          _rise(
            2,
            Text(
              'Your daily system for training, fuel, and progress.',
              style: AuthType.body.copyWith(color: AuthColors.inkSecondary),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Bottom login unit ───────────────────────────────────────────
  // Three states share one frosted card; AnimatedSize morphs the height so
  // expanding into the email form feels like the card growing up from the
  // bottom edge, not a popup.
  Widget _loginUnit() {
    final Widget child = _launching
        ? _launchingView()
        : (_emailMode ? _emailForm() : _chooser());
    return GlassCard(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: child,
        ),
      ),
    );
  }

  // Resting state: a compact two-option chooser.
  Widget _chooser() {
    return Column(
      key: const ValueKey('chooser'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Welcome back', style: AuthType.title),
        const SizedBox(height: 12),
        AuthGoogleButton(onPressed: _google, loading: _googleLoading),
        const SizedBox(height: 10),
        AuthSecondaryButton(
          label: 'Continue with email',
          icon: LucideIcons.mail,
          onPressed: _openEmail,
        ),
        const SizedBox(height: 12),
        Center(child: _createAccountLink()),
        SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 2),
      ],
    );
  }

  // Expanded state: the full email / password form.
  Widget _emailForm() {
    return AutofillGroup(
      child: Column(
        key: const ValueKey('email'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _BackTap(onTap: _closeEmail),
              const SizedBox(width: 6),
              const Text('Sign in with email', style: AuthType.title),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Email', style: AuthType.label),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            cursorColor: AuthColors.ink,
            style: AuthType.body,
            decoration: authFieldDecoration(
              hint: 'you@example.com',
              prefixIcon: const Icon(
                LucideIcons.mail,
                size: 18,
                color: AuthColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Password', style: AuthType.label),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signIn(),
            cursorColor: AuthColors.ink,
            style: AuthType.body,
            decoration: authFieldDecoration(
              hint: '••••••••',
              prefixIcon: const Icon(
                LucideIcons.lock,
                size: 18,
                color: AuthColors.inkMuted,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                  color: AuthColors.inkMuted,
                ),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _PressLink(
              onTap: () => context.push('/forgot-password'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Forgot password?', style: AuthType.link),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AuthPrimaryButton(label: 'Sign in', onPressed: _signIn),
          const SizedBox(height: 12),
          Center(child: _createAccountLink()),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 4),
        ],
      ),
    );
  }

  Widget _createAccountLink() {
    return _PressLink(
      onTap: () => context.push('/signup'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text.rich(
          TextSpan(
            text: 'New here?  ',
            style: AuthType.body.copyWith(
              color: AuthColors.inkSecondary,
              fontSize: 13.5,
            ),
            children: const [
              TextSpan(text: 'Create account', style: AuthType.link),
            ],
          ),
        ),
      ),
    );
  }

  Widget _launchingView() {
    return Padding(
      key: const ValueKey('launching'),
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandSpinner(
            size: 62,
            ring: AuthColors.accent,
            track: AuthColors.fieldBorder,
            letter: AuthColors.ink,
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'STRIDE',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: AuthColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up your day…',
            style: AuthType.body.copyWith(color: AuthColors.inkSecondary),
          ),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 6),
        ],
      ),
    );
  }
}

/// Compact circular "back" affordance for collapsing the email form back to
/// the chooser. 48dp tap target (house floor) with a subtle surface + press-scale.
class _BackTap extends StatefulWidget {
  final VoidCallback onTap;
  const _BackTap({required this.onTap});

  @override
  State<_BackTap> createState() => _BackTapState();
}

class _BackTapState extends State<_BackTap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: AuthMotion.press,
        curve: Curves.easeOut,
        child: Semantics(
          label: 'Back to sign-in options',
          button: true,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x59FFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x261B1714), width: 1),
            ),
            child: const Icon(
              LucideIcons.arrowLeft,
              size: 20,
              color: AuthColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A text link with a gentle press-fade — gives the inline auth links the same
/// considered "give" as the buttons, without changing their layout.
class _PressLink extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressLink({required this.child, required this.onTap});

  @override
  State<_PressLink> createState() => _PressLinkState();
}

class _PressLinkState extends State<_PressLink> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _down ? 0.55 : 1.0,
        duration: AuthMotion.press,
        child: widget.child,
      ),
    );
  }
}

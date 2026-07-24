import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/models.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/widgets/offline_pill.dart';
import '../../shared/widgets/brand_mark.dart';
import '../dev/dev_mode.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/widgets/home_actions_sheet.dart';
import '../../features/habits/screens/habit_creation_screen.dart';
import '../../features/habits/widgets/habit_type_picker.dart';
import '../../features/habits/screens/habit_library_screen.dart';
import '../../features/habits/screens/habit_detail_screen.dart';
import '../../features/habits/screens/habit_focus_screen.dart';
import '../../features/habits/screens/habit_stats_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/habit_guide.dart';
import '../../features/food/providers/food_providers.dart';
import '../../features/food/screens/food_shell.dart';
import '../../features/food/screens/quick_add_sheet.dart' as food_quick;
import '../../features/stats/screens/stats_home_screen.dart';
import '../../features/stats/screens/score_screen.dart';
import '../../features/me/screens/todo_screen.dart';
import '../../features/stats/screens/progression_screen.dart';
import '../../features/xp/screens/prereq_picker_screen.dart';
import '../../features/stats/screens/ranks_screen.dart';
import '../../features/journal/screens/journal_screen.dart';
import '../../features/journal/screens/energy_checkin_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/me/screens/me_hub_screen.dart';
import '../../features/notes/domain/note.dart';
import '../../features/notes/screens/notes_screen.dart';
import '../../features/notes/screens/note_editor_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../core/theme/app_theme.dart';

/// Listens to provider invalidations so the router re-runs `redirect`
/// the moment auth, the user's onboarding flag, or dev-mode changes. This is
/// what drives re-routing — the [GoRouter] itself is built ONCE (never rewatched
/// into existence), so navigation state is preserved across auth/user updates.
class GoRouterRefreshListenable extends ChangeNotifier {
  GoRouterRefreshListenable(Ref ref) {
    ref.listen(appUserProvider, (_, _) => notifyListeners());
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(devModeProvider, (_, _) => notifyListeners());
  }
}

/// Fade page for the auth routes so login ↔ signup and the hand-off from
/// login to home crossfade instead of hard-cutting / platform-sliding.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    child: child,
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  // Build the router exactly once. Reactive state is read *inside* redirect via
  // `ref.read`, and re-evaluation is driven by [GoRouterRefreshListenable] — so
  // an auth/user change re-runs redirect without recreating the whole navigator
  // (which used to remount screens and flash the first onboarding pages).
  return GoRouter(
    // Launch on a neutral splash — never on /home — so a logged-in user whose
    // profile is still loading can't flash the home page before we know whether
    // to send them to onboarding (the "home shows, then the name screen" bug).
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshListenable(ref),
    redirect: (context, state) {
      if (ref.read(devModeProvider)) return null; // Skip gates in dev mode.
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/signup';
      final onOnboarding = loc == '/onboarding';
      final onSplash = loc == '/splash';
      // Recovery is reachable while logged out and its reset flow navigates
      // itself when done, so we never auto-redirect it.
      final onRecovery = loc == '/forgot-password';

      // Session is read synchronously — Supabase.initialize() (awaited in main)
      // has already restored it, so this is correct on the very first frame.
      final loggedIn = SupabaseService.auth.currentSession != null;

      if (!loggedIn) {
        return (isAuthRoute || onRecovery) ? null : '/login';
      }
      if (onRecovery) return null; // let the in-progress reset finish.

      final userAsync = ref.read(appUserProvider);
      final user = userAsync.valueOrNull;

      // Just authenticated (still on login/signup) → hand off to the splash so
      // the profile resolves before we commit to home or onboarding.
      if (isAuthRoute) return '/splash';

      if (onSplash) {
        // Hold on the splash while the profile loads, then route by onboarding
        // status. `isLoading` also covers the post-login refetch, whose retained
        // value is the stale signed-out null.
        if (userAsync.isLoading) return null;
        final needsSetup = user == null ? userAsync.hasValue : !user.isOnboarded;
        return needsSetup ? '/onboarding' : '/home';
      }

      // Already on a real route. Enforce the onboarding gate from the best-known
      // value; a background profile refetch (loading WITH a prior value — e.g. a
      // settings edit) must NOT bounce us to the splash.
      if (user != null) {
        if (!user.isOnboarded && !onOnboarding) return '/onboarding';
        if (user.isOnboarded && onOnboarding) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (_, state) => _fadePage(state, const SignupScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, state) =>
            _fadePage(state, const ForgotPasswordScreen()),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/habit-creation',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is Habit) {
            return HabitCreationScreen(existing: extra);
          }
          if (extra is Map && extra['type'] is HabitType) {
            return HabitCreationScreen(initialType: extra['type'] as HabitType);
          }
          return const HabitCreationScreen();
        },
      ),
      GoRoute(
        path: '/habit-type',
        builder: (_, _) => const HabitTypePickerScreen(),
      ),
      GoRoute(
        path: '/habits',
        pageBuilder: (_, s) =>
            _slidePage(s.pageKey, const HabitLibraryScreen()),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/todo', builder: (_, _) => const TodoScreen()),
      GoRoute(path: '/journal', builder: (_, _) => const JournalScreen()),
      GoRoute(
        path: '/energy-checkin',
        builder: (_, _) => const EnergyCheckinScreen(),
      ),
      GoRoute(
        path: '/level/prereq-picker/:level',
        builder: (_, state) {
          final l = int.tryParse(state.pathParameters['level'] ?? '2') ?? 2;
          return PrereqPickerScreen(level: l);
        },
      ),
      GoRoute(
        path: '/habit/:id',
        pageBuilder: (_, state) => _slidePage(
          state.pageKey,
          HabitDetailScreen(habitId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/habit/:id/focus',
        pageBuilder: (_, state) => _slidePage(
          state.pageKey,
          HabitFocusScreen(habitId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/habit/:id/stats',
        pageBuilder: (_, state) => _slidePage(
          state.pageKey,
          HabitStatsScreen(habitId: state.pathParameters['id']!),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/food', builder: (_, _) => const FoodShell()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (_, _) => const StatsHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'score',
                    pageBuilder: (_, s) =>
                        _slidePage(s.pageKey, const ScoreScreen()),
                  ),
                  GoRoute(
                    path: 'progression',
                    pageBuilder: (_, s) =>
                        _slidePage(s.pageKey, const ProgressionScreen()),
                  ),
                  GoRoute(
                    path: 'ranks',
                    pageBuilder: (_, s) =>
                        _slidePage(s.pageKey, const RanksScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (_, _) => const MeHubScreen(),
                routes: [
                  GoRoute(
                    path: 'about',
                    builder: (_, _) => const AboutMeScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'notes',
                    builder: (_, _) => const NotesScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => NoteEditorScreen(
                          noteId: state.pathParameters['id']!,
                          initial: state.extra is Note
                              ? state.extra as Note
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Shared deep-dive page transition — a quick fade + slight rise (300ms
/// easeOutCubic). Applied to pushed detail routes; the indexed-stack tab
/// branches stay instant.
Page<void> _slidePage(LocalKey key, Widget child) => CustomTransitionPage<void>(
  key: key,
  child: child,
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  transitionsBuilder: (context, animation, secondary, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);

/// Neutral launch / hand-off screen shown while the signed-in user's profile
/// resolves — so neither home nor onboarding flashes before we know which to
/// show. The live brand mark (ruby score-ring sweeping around the "S") is the
/// first thing a user sees, so it does the double duty of loader + logo; the
/// wordmark rises in beneath it. Theme-aware for both BENTO and OBSIDIAN.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final intro = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandSpinner(
              size: 78,
              ring: c.accent,
              track: c.border,
              letter: c.textPrimary,
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: intro,
              child: AnimatedBuilder(
                animation: intro,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 10 * (1 - intro.value)),
                  child: child,
                ),
                child: Column(
                  children: [
                    // Trailing tracking is compensated with matching left pad
                    // so the wordmark stays optically centred.
                    Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        'STRIDE',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 7,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.only(left: 3.4),
                      child: Text(
                        'PERFORMANCE OS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3.4,
                          color: c.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating pill nav. Per-tab labels, animated active indicator, and a
/// context-aware center FAB that adapts its primary action to whichever
/// tab is on screen (Home → 4-tile quick-add, Food → kcal quick-add,
/// Stats/Me → 4-tile quick-add).
class _ScaffoldWithNav extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldWithNav({required this.shell});

  // 4 tab destinations. Center "+" sits between Food and Stats.
  static const _items = [
    (icon: LucideIcons.home, label: 'Home'),
    (icon: LucideIcons.utensils, label: 'Food'),
    (icon: LucideIcons.lineChart, label: 'Stats'),
    (icon: LucideIcons.user, label: 'Me'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    // Hide the floating pill while the keyboard is up — otherwise it pins to
    // the keyboard and steals 76dp of real estate.
    final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;
    final guideStep = ref.watch(habitGuideProvider);
    final scaffold = Scaffold(
      backgroundColor: c.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const OfflinePill(),
            Expanded(child: shell),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: keyboardUp ? const Offset(0, 1.6) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: keyboardUp ? 0 : 1,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              14 + MediaQuery.of(context).viewPadding.bottom,
            ),
            child: SizedBox(
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: c.border, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, -2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _navIcon(context, 0),
                        _navIcon(context, 1),
                        const SizedBox(width: 56),
                        _navIcon(context, 2),
                        _navIcon(context, 3),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -10,
                    child: _CenterFab(
                      key: habitGuideFabKey,
                      onTap: () => _onCenterFab(context, ref),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // First-run habit guide, step 1: spotlight the `+` while on Home.
    if (guideStep == HabitGuideStep.fab && shell.currentIndex == 0) {
      return Stack(
        children: [
          scaffold,
          Positioned.fill(
            child: CoachmarkLayer(
              targetKey: habitGuideFabKey,
              circular: true,
              cutoutPadding: 12,
              title: 'Create your first habit',
              body: 'Tap the + to add a habit, meal, water, or note.',
              stepIndex: 0,
              stepCount: 2,
              onSkip: () => ref.read(habitGuideProvider.notifier).dismiss(),
            ),
          ),
        ],
      );
    }
    return scaffold;
  }

  void _onCenterFab(BuildContext context, WidgetRef ref) {
    switch (shell.currentIndex) {
      case 1: // Food → kcal quick-add for the diary date
        final date = ref.read(diaryDateProvider);
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => food_quick.QuickAddSheet(date: date),
        );
        return;
      case 0: // Home
      default: // Stats / Me — default to the 4-tile sheet too
        // If the first-run guide is on the `+`, advance it to the "Habit" tile
        // as the sheet opens, and end it cleanly if the sheet is dismissed.
        final guide = ref.read(habitGuideProvider.notifier);
        final guiding = ref.read(habitGuideProvider) == HabitGuideStep.fab;
        if (guiding) guide.advanceToTile();
        final future = showQuickAdd4Tile(context);
        if (guiding) {
          future.whenComplete(() {
            if (ref.read(habitGuideProvider) == HabitGuideStep.habitTile) {
              guide.dismiss();
            }
          });
        }
    }
  }

  Widget _navIcon(BuildContext context, int i) {
    final c = context.c;
    final active = shell.currentIndex == i;
    final label = _items[i].label;
    final icon = _items[i].icon;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          splashColor: c.accent.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: SizedBox(
            height: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  scale: active ? 1.08 : 1.0,
                  child: Icon(
                    icon,
                    size: 22,
                    color: active ? c.accent : c.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.2,
                    color: active ? c.accent : c.textMuted,
                    height: 1.0,
                  ),
                  child: Text(label),
                ),
                const SizedBox(height: 4),
                // Active-indicator dot. Fades in for the current tab.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: active ? 4 : 0,
                  height: active ? 4 : 0,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterFab extends StatefulWidget {
  final VoidCallback onTap;
  const _CenterFab({super.key, required this.onTap});

  @override
  State<_CenterFab> createState() => _CenterFabState();
}

class _CenterFabState extends State<_CenterFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 240),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapCancel: () => _ctrl.reverse(),
      onTapUp: (_) async {
        HapticFeedback.mediumImpact();
        await _ctrl.reverse();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final scale = 1.0 - _ctrl.value * 0.08;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.50),
                    blurRadius: 26,
                    spreadRadius: -2,
                    offset: const Offset(0, 9),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(LucideIcons.plus, size: 24, color: c.onAccent),
            ),
          );
        },
      ),
    );
  }
}

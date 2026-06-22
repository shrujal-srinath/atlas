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
import '../../shared/widgets/offline_pill.dart';
import '../dev/dev_mode.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/widgets/quick_add_sheet.dart';
import '../../features/habits/screens/habit_creation_screen.dart';
import '../../features/habits/widgets/habit_type_picker.dart';
import '../../features/habits/screens/habit_library_screen.dart';
import '../../features/habits/screens/habit_detail_screen.dart';
import '../../features/habits/screens/habit_focus_screen.dart';
import '../../features/habits/screens/habit_stats_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/food/providers/food_providers.dart';
import '../../features/food/screens/food_shell.dart';
import '../../features/food/screens/quick_add_sheet.dart' as food_quick;
import '../../features/analytics/screens/analytics_screen.dart';
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
/// the moment the user's onboarding flag changes.
class GoRouterRefreshListenable extends ChangeNotifier {
  GoRouterRefreshListenable(Ref ref) {
    ref.listen(appUserProvider, (_, _) => notifyListeners());
    ref.listen(authStateProvider, (_, _) => notifyListeners());
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
  final authState = ref.watch(authStateProvider);
  final userAsync = ref.watch(appUserProvider);
  final isDev = ref.watch(devModeProvider);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: GoRouterRefreshListenable(ref),
    redirect: (context, state) {
      if (isDev) return null; // Skip auth + onboarding in dev mode.
      final isLoggedIn =
          authState.whenData((s) => s.session != null).value ?? false;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/signup';
      final isOnboardingRoute = loc == '/onboarding';
      // Recovery is reachable while logged out, but (unlike login/signup) is
      // NOT auto-redirected home once the recovery session lands — so the
      // verify→set-new-password step can finish before we navigate.
      final isRecoveryRoute = loc == '/forgot-password';

      if (!isLoggedIn && !isAuthRoute && !isRecoveryRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';

      // Onboarding gate: once we know the user row, push onboarding for
      // anyone whose flag is false.
      final user = userAsync.valueOrNull;
      if (isLoggedIn && user != null) {
        if (!user.isOnboarded && !isOnboardingRoute) return '/onboarding';
        if (user.isOnboarded && isOnboardingRoute) return '/home';
      }
      return null;
    },
    routes: [
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
        builder: (_, _) => const HabitLibraryScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/todo',
        builder: (_, _) => const TodoScreen(),
      ),
      GoRoute(
        path: '/journal',
        builder: (_, _) => const JournalScreen(),
      ),
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
        builder: (_, state) =>
            HabitDetailScreen(habitId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/habit/:id/focus',
        builder: (_, state) =>
            HabitFocusScreen(habitId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/habit/:id/stats',
        builder: (_, state) =>
            HabitStatsScreen(habitId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/food', builder: (_, _) => const FoodShell())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/stats',
              builder: (_, _) => const StatsHomeScreen(),
              routes: [
                GoRoute(path: 'score', builder: (_, _) => const ScoreScreen()),
                GoRoute(path: 'progression', builder: (_, _) => const ProgressionScreen()),
                GoRoute(path: 'trends', builder: (_, _) => const AnalyticsScreen()),
                GoRoute(path: 'ranks', builder: (_, _) => const RanksScreen()),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/me',
              builder: (_, _) => const MeHubScreen(),
              routes: [
                GoRoute(path: 'about', builder: (_, _) => const AboutMeScreen()),
                GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
                GoRoute(
                  path: 'notes',
                  builder: (_, _) => const NotesScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (_, state) => NoteEditorScreen(
                        noteId: state.pathParameters['id']!,
                        initial: state.extra is Note ? state.extra as Note : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});

/// Floating pill nav. Per-tab labels, animated active indicator, and a
/// context-aware center FAB that adapts its primary action to whichever
/// tab is on screen (Home → 4-tile quick-add, Food → kcal quick-add,
/// Stats/Me → 4-tile quick-add).
class _ScaffoldWithNav extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldWithNav({required this.shell});

  // 4 tab destinations. Center "+" sits between Food and Stats.
  static const _items = [
    (icon: LucideIcons.home,      label: 'Home'),
    (icon: LucideIcons.utensils,  label: 'Food'),
    (icon: LucideIcons.lineChart, label: 'Stats'),
    (icon: LucideIcons.user,      label: 'Me'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    // Hide the floating pill while the keyboard is up — otherwise it pins to
    // the keyboard and steals 76dp of real estate.
    final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
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
        showQuickAdd4Tile(context);
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
  const _CenterFab({required this.onTap});

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

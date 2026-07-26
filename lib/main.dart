import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'features/achievements/achievement_overlay.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/food/widgets/nutrition_xp_listener.dart';
import 'features/home/providers/home_providers.dart';
import 'features/notifications/providers/reminder_runner_provider.dart';
import 'features/notifications/weather_nudge_provider.dart';
import 'features/notes/providers/note_reminders_runner_provider.dart';
import 'features/xp/level_up_overlay.dart';
import 'features/xp/leveling_providers.dart';
import 'shared/providers/connectivity_provider.dart';
import 'shared/services/hive_service.dart';
import 'shared/services/supabase_service.dart';
import 'shared/services/notification_service.dart';

void main() {
  // One guarded zone wraps startup + the running app so no error fails
  // silently. Framework, platform, and uncaught-async errors all funnel into
  // [logError] (see lib/core/utils/app_logger.dart).
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      logError(details.exception, details.stack);
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      logError(error, stack);
      return true;
    };
    // In release, show a calm branded fallback instead of the grey error box.
    if (kReleaseMode) {
      ErrorWidget.builder = (_) => const _ReleaseErrorFallback();
    }

    await HiveService.init();
    await SupabaseService.initialize();
    await NotificationService.instance.init();
    runApp(const ProviderScope(child: AtlasApp()));
  }, (error, stack) => logError(error, stack));
}

/// Lets mouse + trackpad drag-scroll every scrollable (PageView, lists) on web
/// and desktop — Flutter's default excludes the mouse, which makes swipe-based
/// widgets like the home week strip feel "stuck" in Chrome. No effect on the
/// touch-driven Android build.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

/// Minimal, theme-agnostic fallback rendered if a widget throws during build
/// in release. Uses raw values so it never depends on an inherited theme.
class _ReleaseErrorFallback extends StatelessWidget {
  const _ReleaseErrorFallback();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFF07090E),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong on this screen.\nTry going back or reopening the app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8D97AA),
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AtlasApp extends ConsumerStatefulWidget {
  const AtlasApp({super.key});

  @override
  ConsumerState<AtlasApp> createState() => _AtlasAppState();
}

class _AtlasAppState extends ConsumerState<AtlasApp> {
  /// Guards [DailySnapshotWriter.runOnce] so we never fire twice per app
  /// session — even though build() runs again for theme / router rebuilds.
  bool _snapshotsBackfilled = false;

  /// Guards the one-time cold-start deep-link (app launched via a tapped
  /// notification) so a router/theme rebuild can't re-route.
  bool _launchHandled = false;

  @override
  void initState() {
    super.initState();
    // Foreground/background taps surface here; cold-start taps are read once
    // from the launch details after the first frame.
    NotificationService.instance.tappedPayload.addListener(_onTappedPayload);
  }

  @override
  void dispose() {
    NotificationService.instance.tappedPayload.removeListener(_onTappedPayload);
    super.dispose();
  }

  void _onTappedPayload() =>
      _routeForPayload(NotificationService.instance.tappedPayload.value);

  void _maybeHandleLaunchPayload() {
    if (_launchHandled) return;
    _launchHandled = true;
    _routeForPayload(NotificationService.instance.consumeLaunchPayload());
  }

  /// Deep-links a tapped-notification payload to the right screen. Auth /
  /// onboarding redirects are handled by the router, so it's safe to call even
  /// when signed out.
  void _routeForPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    String location;
    if (payload.startsWith('habit:')) {
      final id = payload.substring('habit:'.length);
      location = id.isEmpty ? '/home' : '/habit/$id';
    } else if (payload.startsWith('note:')) {
      final id = payload.substring('note:'.length);
      location = id.isEmpty ? '/me/notes' : '/me/notes/$id';
    } else if (payload.startsWith('meal:')) {
      location = '/food';
    } else if (payload.startsWith('weather:')) {
      location = '/home';
    } else {
      location = switch (payload) {
        'water' || 'weight_nudge' => '/food',
        'streak_at_risk' => '/notifications',
        // Both the new energy nudge and any already-queued legacy mood nudge
        // open the quick 1–5 energy picker.
        'energy_checkin' || 'mood_checkin' => '/energy-checkin',
        _ => '/home',
      };
    }
    ref.read(routerProvider).go(location);
  }

  void _maybeBackfillSnapshots() {
    if (_snapshotsBackfilled) return;
    final session = ref.read(sessionProvider);
    if (session == null) return;
    _snapshotsBackfilled = true;
    // Triggering the provider kicks off `DailySnapshotWriter.runOnce` with a
    // Riverpod `Ref` (which has access to the same providers). The provider
    // is FutureProvider<void> so reading it just registers interest; the
    // writer swallows network/schema errors so app boot never blocks.
    ref.read(dailySnapshotBackfillProvider);
    // Same trick for the weather-nudge runner — best-effort, cooldown-guarded.
    ref.read(weatherNudgeRunnerProvider);
    // Keep the OS notification schedule in sync with the typed prefs.
    ref.read(reminderRunnerProvider);
    // Keep note reminders in sync with the notes table.
    ref.read(noteRemindersRunnerProvider);
    // Refresh diary/water reads once a sync-queue drain lands (SR-2).
    ref.read(syncDrainInvalidatorProvider);
    // Keep "today" correct across a midnight rollover (SR-3).
    ref.read(todayRolloverBootstrapProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);

    // Run after the frame so we don't trigger a provider mutation during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeBackfillSnapshots();
      _maybeHandleLaunchPayload();
    });

    // Status bar icons follow the mode.
    SystemChrome.setSystemUIOverlayStyle(
      mode == ThemeMode.light
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarIconBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
    );

    return MaterialApp.router(
      title: 'STRIDE',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      scrollBehavior: const _AppScrollBehavior(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => LevelUpOverlay(
        child: AchievementOverlay(
          child: NutritionXpListener(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

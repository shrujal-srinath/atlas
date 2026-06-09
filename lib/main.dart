import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'features/achievements/achievement_overlay.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/food/widgets/nutrition_xp_listener.dart';
import 'features/notifications/weather_nudge_provider.dart';
import 'features/xp/level_up_overlay.dart';
import 'features/xp/leveling_providers.dart';
import 'shared/services/supabase_service.dart';
import 'shared/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: AtlasApp()));
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
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);

    // Run after the frame so we don't trigger a provider mutation during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBackfillSnapshots());

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
      title: 'ATLAS',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => LevelUpOverlay(
        child: AchievementOverlay(
          child: NutritionXpListener(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

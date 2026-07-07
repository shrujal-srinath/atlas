import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dev_mode.dart';

/// Whether the dev-access bypass is compiled into the build. Defaults OFF so a
/// build that forgets to pass a flag never ships the backdoor — pass
/// `--dart-define=ATLAS_DEV_ACCESS=true` explicitly on dev/demo builds where
/// the shortcut is wanted. The user-facing entry point (the old "Dev access"
/// chip) has been removed from the auth UI; the demo-credential path in
/// [isDemoCredential] is the only way to reach [enterDevMode] now.
const bool kDevAccessEnabled =
    bool.fromEnvironment('ATLAS_DEV_ACCESS', defaultValue: false);

/// Drops straight into the app with sample data — no passcode. The visible
/// trigger (a "Dev access" chip on the login screen) has been removed; this and
/// the whole mock-data path are intentionally kept for future development. Wire
/// it to a button again to use it.
///
/// Flips [devModeProvider], which makes the data providers serve mock data and
/// the router skip the auth + onboarding gates, then lands on Home.
void enterDevMode(BuildContext context, WidgetRef ref) {
  if (!kDevAccessEnabled) return; // defense-in-depth: no-op when compiled out
  HapticFeedback.mediumImpact();
  ref.read(devModeProvider.notifier).state = true;
  context.go('/home');
}

/// Demo-account credentials. Typing these into the login form drops straight
/// into the app populated with sample data (the [enterDevMode] path) — no
/// network call, no real Supabase account — so anyone can preview ATLAS
/// without signing up. Guarded by [kDevAccessEnabled].
const String kDemoEmail = 'shrujal@gmail.com';
const String kDemoPassword = 'SHRUJAL@123';

/// True when [email]/[password] are the demo credentials and the demo path is
/// compiled in. Email is matched case-insensitively; password is exact.
bool isDemoCredential(String email, String password) =>
    kDevAccessEnabled &&
    email.trim().toLowerCase() == kDemoEmail &&
    password == kDemoPassword;

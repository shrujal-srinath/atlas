import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dev_mode.dart';

/// Drops straight into the app with sample data — no passcode. Wired to the
/// visible "Dev access" chip (and the hidden wordmark long-press) on the auth
/// screens, and **survives release APKs** (the old `kDebugMode` button was
/// compiled out of release).
///
/// Flips [devModeProvider], which makes the data providers serve mock data and
/// the router skip the auth + onboarding gates, then lands on Home.
void enterDevMode(BuildContext context, WidgetRef ref) {
  HapticFeedback.mediumImpact();
  ref.read(devModeProvider.notifier).state = true;
  context.go('/home');
}

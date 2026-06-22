import 'package:flutter/foundation.dart';

/// Central error sink. Every global handler (`FlutterError.onError`,
/// `PlatformDispatcher.onError`, the `runZonedGuarded` fallback in `main`)
/// funnels here, so there is a single place to add remote crash reporting.
///
/// In debug it prints with a stack trace. In release it is a quiet no-op today
/// — the marked hook below is where a remote sink (Supabase `client_errors`
/// table or Sentry) gets wired in before public launch.
void logError(Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    debugPrint('⛔ logError: $error');
    if (stack != null) debugPrint(stack.toString());
  }
  // TODO(deploy): forward to a remote crash sink here (Supabase / Sentry).
}

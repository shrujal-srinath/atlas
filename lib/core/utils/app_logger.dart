import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../shared/services/supabase_service.dart';

/// Central error sink. Every global handler (`FlutterError.onError`,
/// `PlatformDispatcher.onError`, the `runZonedGuarded` fallback in `main`)
/// funnels here, so there is a single place for crash reporting.
///
/// In debug it prints with a stack trace. In release it best-effort forwards to
/// the Supabase `client_errors` table so production failures are actually
/// visible instead of vanishing.
void logError(Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    debugPrint('⛔ logError: $error');
    if (stack != null) debugPrint(stack.toString());
    return;
  }
  _reportToSupabase(error, stack);
}

/// Fire-and-forget remote crash report. Fully guarded — logging must never
/// throw (it runs from inside the global error handlers, possibly before
/// Supabase is ready or while offline).
void _reportToSupabase(Object error, StackTrace? stack) {
  try {
    final client = SupabaseService.client;
    unawaited(
      client.from('client_errors').insert({
        'user_id': client.auth.currentUser?.id,
        'message': error.toString(),
        'stack': stack?.toString(),
        'platform': defaultTargetPlatform.name,
      }).then((_) {}, onError: (_) {}),
    );
  } catch (_) {
    // Supabase uninitialised / offline — drop it; a crash report must not crash.
  }
}

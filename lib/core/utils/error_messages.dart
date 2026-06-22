import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps any thrown error to a short, user-safe message.
///
/// Keeps raw exception and stack detail — Postgres internals, network stack
/// traces, JWT payloads — out of the UI, while still surfacing the genuinely
/// useful gotrue auth messages (which are already written for end users).
///
/// Use this anywhere an error reaches the UI (snackbars, error widgets,
/// `AsyncValue.when(error: …)`) instead of `error.toString()`.
String friendlyError(Object? error) {
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('invalid login') || m.contains('credentials')) {
      return 'Incorrect email or password.';
    }
    if (m.contains('already registered') ||
        m.contains('already been registered') ||
        m.contains('user already exists')) {
      return 'That email is already registered — try signing in.';
    }
    if (m.contains('not confirmed')) {
      return 'Verify your email first — check for the 6-digit code we sent.';
    }
    if (m.contains('token has expired') ||
        (m.contains('invalid') && m.contains('otp')) ||
        m.contains('token is invalid')) {
      return 'That code is wrong or expired — request a new one.';
    }
    // Remaining gotrue messages (password too short, rate limited, …) are
    // already end-user friendly.
    return error.message;
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is ClientException) {
    return 'Check your connection and try again.';
  }
  if (error is PostgrestException || error is StorageException) {
    return "Couldn't reach your data — please try again.";
  }
  return 'Something went wrong. Please try again.';
}

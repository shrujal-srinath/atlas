import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/hive_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../core/dev/dev_mode.dart';

/// Basic RFC-ish email check — one `@`, a dot in the domain, no spaces.
bool isValidEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.auth.onAuthStateChange;
});

final sessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenData((s) => s.session).value;
});

final appUserProvider = FutureProvider<AppUser?>((ref) async {
  if (ref.watch(devModeProvider)) return mockUser;
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final data = await SupabaseService.client
      .from('users')
      .select()
      .eq('id', session.user.id)
      .single();
  return AppUser.fromJson(data);
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );
    });
  }

  /// Registers the account and triggers Supabase to email a 6-digit signup
  /// code. Deliberately does NOT sign in — the caller advances to the verify
  /// step, where [verifySignup] confirms the code and lands the session.
  ///
  /// Requires the Supabase **"Confirm signup"** email template to expose
  /// `{{ .Token }}` (the 6-digit code) instead of `{{ .ConfirmationURL }}`.
  Future<void> signUp(String email, String password, String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
    });
  }

  /// Confirms the emailed signup [code]. On success the user holds a fresh
  /// session and the router advances to onboarding automatically.
  Future<void> verifySignup({
    required String email,
    required String code,
  }) async {
    await SupabaseService.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.signup,
    );
  }

  /// Re-sends the 6-digit signup confirmation code.
  Future<void> resendSignupCode(String email) {
    return SupabaseService.auth.resend(type: OtpType.signup, email: email);
  }

  /// Google OAuth sign-in. Requires the Google provider enabled in Supabase
  /// and the `redirectTo` deep link allow-listed (+ an Android intent-filter).
  /// Until configured this throws a gotrue error, surfaced to the user via a
  /// snackbar.
  Future<void> signInWithGoogle() async {
    await SupabaseService.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.atlas.app://login-callback/',
    );
  }

  /// Emails a password-recovery code. The Supabase recovery email template
  /// must expose `{{ .Token }}` so the user receives a 6-digit code to type.
  Future<void> sendPasswordReset(String email) {
    return SupabaseService.auth.resetPasswordForEmail(email);
  }

  /// Verifies the emailed recovery [code], then sets [newPassword]. On success
  /// the user holds a fresh session, so callers can route straight to home.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await SupabaseService.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
    await SupabaseService.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    // Clear local user residue BEFORE Supabase tears down the session so the
    // next signed-in user can't see the previous account's cached rows or
    // receive notifications scheduled for the old account.
    try {
      await NotificationService.instance.cancelAll();
    } catch (_) { /* best-effort */ }
    try {
      await HiveService.clearAll();
    } catch (_) { /* best-effort */ }
    await SupabaseService.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) => AuthNotifier());

/// Mutates the `users` row for the current session. Every call invalidates
/// [appUserProvider] so dependent widgets refetch.
class UserActionsNotifier extends StateNotifier<AsyncValue<void>> {
  UserActionsNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> update(Map<String, dynamic> patch) async {
    final session = _ref.read(sessionProvider);
    if (session == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService.client
          .from('users')
          .update(patch)
          .eq('id', session.user.id);
      _ref.invalidate(appUserProvider);
    });
  }

  Future<void> deleteAccount() async {
    final session = _ref.read(sessionProvider);
    if (session == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = session.user.id;
      final client = SupabaseService.client;

      // Proper account removal: a `delete_user` Postgres function
      // (SECURITY DEFINER — deletes the auth.users row, which cascades to
      // every user-scoped table) fully satisfies store account-deletion
      // rules. Best-effort + safe no-op until that function is deployed.
      try {
        await client.rpc('delete_user');
      } catch (_) {/* not deployed yet — fall through to the client wipe */}

      // Belt-and-braces client wipe of every personal, user-scoped table, in
      // case the server cascade isn't configured. Each delete is independent
      // so one failure never blocks the local clear + sign-out below.
      Future<void> wipe(String table, [String col = 'user_id']) async {
        try {
          await client.from(table).delete().eq(col, uid);
        } catch (_) {/* table absent on older deploys / no such column */}
      }
      await wipe('habit_logs');
      await wipe('habits');
      await wipe('food_logs');
      await wipe('water_logs');
      await wipe('mood_logs');
      await wipe('focus_sessions');
      await wipe('intentions');
      await wipe('measurements');
      await wipe('body_weight_logs');
      await wipe('daily_score_snapshots');
      await wipe('daily_journal');
      await wipe('notes');
      await wipe('notifications');
      await wipe('user_achievements');
      await wipe('phase_history');
      await wipe('meal_bundles');
      await wipe('users', 'id');

      // Always clear local state + sign out, even on partial server failure.
      try { await NotificationService.instance.cancelAll(); } catch (_) {}
      try { await HiveService.clearAll(); } catch (_) {}
      await SupabaseService.auth.signOut();
    });
  }
}

final userActionsProvider =
    StateNotifierProvider<UserActionsNotifier, AsyncValue<void>>(
  (ref) => UserActionsNotifier(ref),
);

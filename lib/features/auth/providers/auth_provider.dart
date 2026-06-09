import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../core/dev/dev_mode.dart';

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

  Future<void> signUp(String email, String password, String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signOut() async {
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
      // Soft-delete: wipe rows then sign out. Auth user removal requires
      // server-side / Edge Function; that's out of scope for this sprint.
      final uid = session.user.id;
      await SupabaseService.client.from('habit_logs').delete().eq('user_id', uid);
      await SupabaseService.client.from('habits').delete().eq('user_id', uid);
      await SupabaseService.client.from('food_logs').delete().eq('user_id', uid);
      await SupabaseService.client.from('water_logs').delete().eq('user_id', uid);
      await SupabaseService.client.from('users').delete().eq('id', uid);
      await SupabaseService.auth.signOut();
    });
  }
}

final userActionsProvider =
    StateNotifierProvider<UserActionsNotifier, AsyncValue<void>>(
  (ref) => UserActionsNotifier(ref),
);

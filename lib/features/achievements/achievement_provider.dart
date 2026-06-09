import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dev/dev_mode.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';

/// Set of achievement IDs the user has unlocked. Empty if the row is missing
/// or the table doesn't exist yet (graceful pre-migration fallback).
final unlockedAchievementsProvider = FutureProvider<Set<String>>((ref) async {
  if (ref.watch(devModeProvider)) return <String>{};
  final session = ref.watch(sessionProvider);
  if (session == null) return <String>{};
  try {
    final rows = await SupabaseService.client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', session.user.id);
    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['achievement_id'] as String)
        .toSet();
  } catch (_) {
    return <String>{};
  }
});

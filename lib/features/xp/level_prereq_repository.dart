/// DB access for the `level_prerequisites` table. Pure CRUD; no business
/// logic lives here. The progress-derivation lives in `prereq_providers.dart`.
library;

import '../../shared/services/supabase_service.dart';
import 'models/level_prereq.dart';

class LevelPrereqRepository {
  const LevelPrereqRepository();

  Future<List<LevelPrereq>> forLevel(String userId, int level) async {
    try {
      final rows = await SupabaseService.client
          .from('level_prerequisites')
          .select()
          .eq('user_id', userId)
          .eq('level', level)
          .order('created_at');
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(LevelPrereq.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> insert(LevelPrereq prereq) async {
    try {
      final row = await SupabaseService.client
          .from('level_prerequisites')
          .insert(prereq.toInsert())
          .select('id')
          .single();
      return row['id'] as String;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String id) async {
    try {
      await SupabaseService.client
          .from('level_prerequisites')
          .delete()
          .eq('id', id);
    } catch (_) {}
  }

  Future<void> markCompleted(String id) async {
    try {
      await SupabaseService.client
          .from('level_prerequisites')
          .update({'completed_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (_) {}
  }
}

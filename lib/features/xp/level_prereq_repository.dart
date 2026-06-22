/// DB access for the `level_prerequisites` table. Pure CRUD; no business
/// logic lives here. The progress-derivation lives in `prereq_providers.dart`.
///
/// NOTE: unlike the food repo, writes here go straight to Supabase and are
/// *not* queued through [OfflineWriter] — an offline insert/delete silently
/// no-ops (the screen invalidates + re-reads, so there's no UI desync, but the
/// change is lost). Acceptable while prereqs are configured online; revisit if
/// offline editing of prerequisites is needed.
library;

import 'package:flutter/foundation.dart';

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
    } catch (e, s) {
      if (kDebugMode) debugPrint('LevelPrereqRepository.insert failed: $e\n$s');
      return null;
    }
  }

  Future<void> delete(String id) async {
    try {
      await SupabaseService.client
          .from('level_prerequisites')
          .delete()
          .eq('id', id);
    } catch (e, s) {
      if (kDebugMode) debugPrint('LevelPrereqRepository.delete failed: $e\n$s');
    }
  }
}

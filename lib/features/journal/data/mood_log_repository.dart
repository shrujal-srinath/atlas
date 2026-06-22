import 'package:uuid/uuid.dart';

import '../../../shared/services/offline_writer.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/mood_log.dart';

/// CRUD for the `mood_logs` intraday timeseries. Writes go through
/// [OfflineWriter] for offline-first parity with the rest of the app.
class MoodLogRepository {
  static const _uuid = Uuid();

  /// Appends a check-in for *now*. Returns the persisted (or queued) row.
  /// At least one of [mood]/[energy] should be set — energy-only check-ins come
  /// from the notification energy picker; full mood+energy from the home card.
  Future<MoodLog> add({int? mood, int? energy, String? note}) async {
    final userId = SupabaseService.auth.currentUser!.id;
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
      'user_id': userId,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
      'mood': mood,
      'energy': energy,
      'note': (note != null && note.isNotEmpty) ? note : null,
    };
    final row = await OfflineWriter.insert(table: 'mood_logs', payload: payload);
    return MoodLog.fromJson(row);
  }

  /// All logs at/after [startLocal], oldest → newest.
  Future<List<MoodLog>> since(DateTime startLocal) async {
    final rows = await SupabaseService.client
        .from('mood_logs')
        .select()
        .gte('logged_at', startLocal.toUtc().toIso8601String())
        .order('logged_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MoodLog.fromJson)
        .toList();
  }
}

import 'package:uuid/uuid.dart';

import '../../../shared/services/offline_writer.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/note_folder.dart';

/// CRUD for `note_folders`. Offline-first like the rest of the notes feature.
class NoteFoldersRepository {
  static const _uuid = Uuid();

  String get _userId => SupabaseService.auth.currentUser!.id;

  Future<List<NoteFolder>> list() async {
    final rows = await SupabaseService.client
        .from('note_folders')
        .select()
        .order('position', ascending: true)
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(NoteFolder.fromJson)
        .toList();
  }

  Future<NoteFolder> create({
    required String name,
    String? icon,
    String? color,
    required int position,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
      'user_id': _userId,
      'name': name,
      'icon': icon,
      'color': color,
      'position': position,
      'created_at': nowIso,
      'updated_at': nowIso,
    };
    final row =
        await OfflineWriter.insert(table: 'note_folders', payload: payload);
    return NoteFolder.fromJson(row);
  }

  Future<void> update(String id,
      {String? name, String? icon, String? color}) {
    return OfflineWriter.update(
      table: 'note_folders',
      id: id,
      payload: {
        'name': ?name,
        'icon': ?icon,
        'color': ?color,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Deletes a folder. Notes filed under it have `folder_id` set null by the
  /// DB's `ON DELETE SET NULL`, so they fall back to "All notes".
  Future<void> delete(String id) =>
      OfflineWriter.delete(table: 'note_folders', id: id);
}

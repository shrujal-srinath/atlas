import 'package:uuid/uuid.dart';

import '../../../shared/services/offline_writer.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/note.dart';
import '../domain/note_item.dart';

/// CRUD for the `notes` + `note_items` tables. Mutations go through
/// [OfflineWriter] so they survive a network outage (offline-first parity with
/// the rest of the app).
class NotesRepository {
  static const _uuid = Uuid();

  String get _userId => SupabaseService.auth.currentUser!.id;

  /// All notes, newest-updated first, with checklist progress hydrated.
  Future<List<Note>> list() async {
    final rows = await SupabaseService.client
        .from('notes')
        .select()
        .order('updated_at', ascending: false);
    final notes = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Note.fromJson)
        .toList();

    // Join checklist counts in a single extra query, then fold into the notes.
    final checklistIds =
        notes.where((n) => n.isChecklist).map((n) => n.id).toList();
    if (checklistIds.isEmpty) return notes;

    final items = await SupabaseService.client
        .from('note_items')
        .select('note_id, done')
        .inFilter('note_id', checklistIds);
    final total = <String, int>{};
    final done = <String, int>{};
    for (final row in (items as List).cast<Map<String, dynamic>>()) {
      final id = row['note_id'] as String;
      total[id] = (total[id] ?? 0) + 1;
      if (row['done'] == true) done[id] = (done[id] ?? 0) + 1;
    }
    return [
      for (final n in notes)
        n.isChecklist
            ? n.copyWith(itemTotal: total[n.id] ?? 0, itemDone: done[n.id] ?? 0)
            : n,
    ];
  }

  Future<Note?> getById(String id) async {
    final row = await SupabaseService.client
        .from('notes')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Note.fromJson(row);
  }

  /// Creates an empty note/checklist and returns it (so the editor can open on
  /// it). Optionally files it under [folderId] straight away.
  Future<Note> create({
    NoteKind kind = NoteKind.note,
    String? folderId,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
      'user_id': _userId,
      'title': '',
      'body': '',
      'folder_id': folderId,
      'kind': kind.dbValue,
      'pinned': false,
      'created_at': nowIso,
      'updated_at': nowIso,
    };
    final row = await OfflineWriter.insert(table: 'notes', payload: payload);
    return Note.fromJson(row);
  }

  Future<void> save(String id, {required String title, required String body}) {
    return OfflineWriter.update(
      table: 'notes',
      id: id,
      payload: {
        'title': title,
        'body': body,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> setPinned(String id, bool pinned) {
    return OfflineWriter.update(
      table: 'notes',
      id: id,
      payload: {
        'pinned': pinned,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> setFolder(String id, String? folderId) {
    return OfflineWriter.update(
      table: 'notes',
      id: id,
      payload: {
        'folder_id': folderId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Sets or clears a note's reminder. Pass nulls to clear it. The OS schedule
  /// is reconciled separately by the note-reminder runner.
  Future<void> setReminder(
    String id, {
    required DateTime? at,
    required ReminderRule? rule,
  }) {
    return OfflineWriter.update(
      table: 'notes',
      id: id,
      payload: {
        'reminder_at': at?.toUtc().toIso8601String(),
        'reminder_rule': rule?.dbValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> delete(String id) =>
      OfflineWriter.delete(table: 'notes', id: id);

  // ── Checklist items ───────────────────────────────────────────────

  Future<List<NoteItem>> items(String noteId) async {
    final rows = await SupabaseService.client
        .from('note_items')
        .select()
        .eq('note_id', noteId)
        .order('position', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(NoteItem.fromJson)
        .toList();
  }

  Future<NoteItem> addItem(String noteId,
      {String text = '', required int position}) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
      'note_id': noteId,
      'user_id': _userId,
      'text': text,
      'done': false,
      'position': position,
      'created_at': nowIso,
      'updated_at': nowIso,
    };
    final row = await OfflineWriter.insert(table: 'note_items', payload: payload);
    return NoteItem.fromJson(row);
  }

  Future<void> updateItem(String id,
      {String? text, bool? done, int? position}) {
    return OfflineWriter.update(
      table: 'note_items',
      id: id,
      payload: {
        'text': ?text,
        'done': ?done,
        'position': ?position,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteItem(String id) =>
      OfflineWriter.delete(table: 'note_items', id: id);

  /// Persists a new ordering. Items keep their ids; only `position` changes.
  Future<void> reorderItems(List<NoteItem> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].position == i) continue;
      await updateItem(ordered[i].id, position: i);
    }
  }
}

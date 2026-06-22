import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/note_folders_repository.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';
import '../domain/note_folder.dart';

/// Sentinel folder id used by the list filter to mean "notes with no folder".
const kUnfiledFolderId = '__unfiled__';

final notesRepositoryProvider = Provider<NotesRepository>(
  (_) => NotesRepository(),
);

final noteFoldersRepositoryProvider = Provider<NoteFoldersRepository>(
  (_) => NoteFoldersRepository(),
);

/// All of the user's notes, newest-updated first, with checklist progress.
final notesListProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.list();
});

/// The user's folders, in manual order.
final noteFoldersProvider = FutureProvider.autoDispose<List<NoteFolder>>((
  ref,
) async {
  final repo = ref.watch(noteFoldersRepositoryProvider);
  return repo.list();
});

/// Active folder filter on the notes list. `null` = all notes;
/// [kUnfiledFolderId] = notes with no folder; otherwise a folder id.
final activeFolderProvider = StateProvider.autoDispose<String?>((_) => null);

/// Free-text search over note titles/bodies.
final notesSearchProvider = StateProvider.autoDispose<String>((_) => '');

/// Notes after applying the folder filter + search, with pinned ones first.
final visibleNotesProvider = Provider.autoDispose<AsyncValue<List<Note>>>((
  ref,
) {
  final notesAsync = ref.watch(notesListProvider);
  final folder = ref.watch(activeFolderProvider);
  final query = ref.watch(notesSearchProvider).trim().toLowerCase();

  return notesAsync.whenData((notes) {
    Iterable<Note> out = notes;
    if (folder == kUnfiledFolderId) {
      out = out.where((n) => n.folderId == null);
    } else if (folder != null) {
      out = out.where((n) => n.folderId == folder);
    }
    if (query.isNotEmpty) {
      out = out.where(
        (n) =>
            n.title.toLowerCase().contains(query) ||
            n.body.toLowerCase().contains(query),
      );
    }
    final list = out.toList();
    // Pinned first, then newest-updated (Dart's sort isn't stable, so the
    // secondary key is explicit rather than relying on query order).
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  });
});

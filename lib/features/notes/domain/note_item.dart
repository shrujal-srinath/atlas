/// One row in `public.note_items` — a single checkable line within a checklist
/// note.
class NoteItem {
  final String id;
  final String noteId;
  final String userId;
  final String text;
  final bool done;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteItem({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.text,
    required this.done,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  NoteItem copyWith({String? text, bool? done, int? position}) => NoteItem(
        id: id,
        noteId: noteId,
        userId: userId,
        text: text ?? this.text,
        done: done ?? this.done,
        position: position ?? this.position,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
        id: j['id'] as String,
        noteId: j['note_id'] as String,
        userId: j['user_id'] as String,
        text: (j['text'] as String?) ?? '',
        done: (j['done'] as bool?) ?? false,
        position: (j['position'] as int?) ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      );
}

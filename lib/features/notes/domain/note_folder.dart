/// One row in `public.note_folders` — a category used to file notes by use
/// (e.g. "Body rehab", "Pointers", "Groceries").
class NoteFolder {
  final String id;
  final String userId;
  final String name;
  final String? icon; // lucide icon key
  final String? color; // palette key, see folderColors
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteFolder({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.color,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => name.trim().isEmpty ? 'Untitled folder' : name.trim();

  factory NoteFolder.fromJson(Map<String, dynamic> j) => NoteFolder(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        name: (j['name'] as String?) ?? '',
        icon: j['icon'] as String?,
        color: j['color'] as String?,
        position: (j['position'] as int?) ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      );
}

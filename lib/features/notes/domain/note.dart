/// Whether a note is freeform prose or a checklist of items.
enum NoteKind {
  note,
  checklist;

  String get dbValue => name; // 'note' | 'checklist'

  static NoteKind fromDb(String? v) =>
      v == 'checklist' ? NoteKind.checklist : NoteKind.note;
}

/// How a note's reminder repeats. `once` fires a single time; the rest repeat
/// at the reminder's time-of-day (and, for [weekly], its weekday).
enum ReminderRule {
  once,
  daily,
  weekdays, // Mon–Fri
  weekends, // Sat–Sun
  weekly; // same weekday as the chosen date

  String get dbValue => name;

  String get label => switch (this) {
        ReminderRule.once => 'Once',
        ReminderRule.daily => 'Every day',
        ReminderRule.weekdays => 'Weekdays',
        ReminderRule.weekends => 'Weekends',
        ReminderRule.weekly => 'Weekly',
      };

  static ReminderRule? fromDb(String? v) {
    if (v == null) return null;
    for (final r in ReminderRule.values) {
      if (r.name == v) return r;
    }
    return null;
  }
}

/// One row in `public.notes` — a freeform note or a checklist, optionally
/// filed under a folder and/or carrying a reminder.
class Note {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? folderId;
  final NoteKind kind;
  final bool pinned;
  final DateTime? reminderAt;
  final ReminderRule? reminderRule;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Checklist progress, hydrated by the list query (0 for freeform notes and
  /// for the bare row before counts are joined in).
  final int itemTotal;
  final int itemDone;

  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.folderId,
    required this.kind,
    required this.pinned,
    required this.reminderAt,
    required this.reminderRule,
    required this.createdAt,
    required this.updatedAt,
    this.itemTotal = 0,
    this.itemDone = 0,
  });

  bool get isChecklist => kind == NoteKind.checklist;
  bool get hasReminder => reminderAt != null;

  /// True once a one-time reminder's moment has already passed.
  bool get reminderPassed =>
      reminderRule == ReminderRule.once &&
      reminderAt != null &&
      reminderAt!.isBefore(DateTime.now());

  /// First non-empty line, for the list row when no title is set.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (!isChecklist) {
      final firstLine = body.trim().split('\n').first.trim();
      if (firstLine.isNotEmpty) return firstLine;
    }
    return isChecklist ? 'Untitled list' : 'Untitled note';
  }

  Note copyWith({int? itemTotal, int? itemDone}) => Note(
        id: id,
        userId: userId,
        title: title,
        body: body,
        folderId: folderId,
        kind: kind,
        pinned: pinned,
        reminderAt: reminderAt,
        reminderRule: reminderRule,
        createdAt: createdAt,
        updatedAt: updatedAt,
        itemTotal: itemTotal ?? this.itemTotal,
        itemDone: itemDone ?? this.itemDone,
      );

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        folderId: j['folder_id'] as String?,
        kind: NoteKind.fromDb(j['kind'] as String?),
        pinned: (j['pinned'] as bool?) ?? false,
        reminderAt: j['reminder_at'] != null
            ? DateTime.parse(j['reminder_at'] as String).toLocal()
            : null,
        reminderRule: ReminderRule.fromDb(j['reminder_rule'] as String?),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      );
}

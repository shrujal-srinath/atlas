/// A single day-to-day to-do (e.g. "Buy groceries"). Belongs to one date; an
/// optional time gives it a slot in the day. Stored locally (Hive).
class TodoItem {
  final String id;
  final String text;
  final String date; // yyyy-MM-dd — the list's overall date
  final String? time; // "HH:mm" or null
  final bool done;
  final int sortOrder;

  const TodoItem({
    required this.id,
    required this.text,
    required this.date,
    this.time,
    this.done = false,
    this.sortOrder = 0,
  });

  TodoItem copyWith({
    String? text,
    String? time,
    bool clearTime = false,
    bool? done,
    int? sortOrder,
  }) =>
      TodoItem(
        id: id,
        text: text ?? this.text,
        date: date,
        time: clearTime ? null : (time ?? this.time),
        done: done ?? this.done,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'date': date,
        'time': time,
        'done': done,
        'sort': sortOrder,
      };

  factory TodoItem.fromMap(Map<String, dynamic> m) => TodoItem(
        id: m['id'] as String,
        text: m['text'] as String? ?? '',
        date: m['date'] as String? ?? '',
        time: m['time'] as String?,
        done: m['done'] as bool? ?? false,
        sortOrder: (m['sort'] as num?)?.toInt() ?? 0,
      );
}

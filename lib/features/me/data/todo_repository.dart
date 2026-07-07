import '../../../shared/services/hive_service.dart';
import '../domain/todo_item.dart';

/// Local-first to-do storage (Hive). Each date holds its own ordered list,
/// keyed `byDate:yyyy-mm-dd`. Synchronous reads/writes on the open box.
class TodoRepository {
  static const _box = HiveService.todosBox;

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _key(DateTime d) => 'byDate:${ymd(d)}';

  List<TodoItem> forDate(DateTime date) {
    final raw = HiveService.get<List>(_box, _key(date)) ?? const [];
    final items = raw
        .map((m) => TodoItem.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Future<void> _write(DateTime date, List<TodoItem> items) =>
      HiveService.put(_box, _key(date), [for (final t in items) t.toMap()]);

  Future<TodoItem> add(DateTime date, String text, {String? time}) async {
    final items = forDate(date);
    final item = TodoItem(
      id: 't_${DateTime.now().microsecondsSinceEpoch}',
      text: text.trim(),
      date: ymd(date),
      time: time,
      sortOrder: items.isEmpty
          ? 0
          : (items.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1),
    );
    await _write(date, [...items, item]);
    return item;
  }

  Future<void> toggle(DateTime date, String id) async {
    final items = forDate(date)
        .map((t) => t.id == id ? t.copyWith(done: !t.done) : t)
        .toList();
    await _write(date, items);
  }

  Future<void> update(DateTime date, TodoItem item) async {
    final items =
        forDate(date).map((t) => t.id == item.id ? item : t).toList();
    await _write(date, items);
  }

  Future<void> delete(DateTime date, String id) async {
    await _write(date, forDate(date).where((t) => t.id != id).toList());
  }

  /// Persist a new manual order (re-stamps `sortOrder` to the given sequence).
  Future<void> reorder(DateTime date, List<TodoItem> ordered) async {
    final stamped = [
      for (var i = 0; i < ordered.length; i++)
        ordered[i].copyWith(sortOrder: i),
    ];
    await _write(date, stamped);
  }
}

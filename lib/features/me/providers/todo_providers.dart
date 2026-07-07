import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/todo_repository.dart';
import '../domain/todo_item.dart';

final todoRepositoryProvider = Provider<TodoRepository>((_) => TodoRepository());

/// The date the to-do list is currently scoped to (defaults to today).
final selectedTodoDateProvider =
    StateProvider<DateTime>((_) => _dayOnly(DateTime.now()));

/// Bumped after every mutation so the list re-reads from Hive (which isn't
/// reactive on its own).
final todoRevisionProvider = StateProvider<int>((_) => 0);

/// The to-dos for the selected date, in the user's manual (drag) order.
final todosForDateProvider = Provider<List<TodoItem>>((ref) {
  ref.watch(todoRevisionProvider);
  final date = ref.watch(selectedTodoDateProvider);
  return ref.watch(todoRepositoryProvider).forDate(date);
});

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

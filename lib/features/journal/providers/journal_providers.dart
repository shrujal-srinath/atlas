import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/providers/habit_provider.dart';
import '../data/journal_repository.dart';
import '../domain/journal_entry.dart';

final journalRepositoryProvider =
    Provider<JournalRepository>((_) => JournalRepository());

/// Entry for the currently selected home date.
final journalForSelectedDateProvider =
    FutureProvider.autoDispose<JournalEntry?>((ref) async {
  final date = ref.watch(selectedDateProvider);
  final repo = ref.watch(journalRepositoryProvider);
  return repo.getForDate(date);
});

/// Last 30 days of entries — analytics + home insights.
final journalLast30Provider =
    FutureProvider.autoDispose<List<JournalEntry>>((ref) async {
  final repo = ref.watch(journalRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - 29);
  final end = DateTime(now.year, now.month, now.day);
  return repo.range(start, end);
});

/// Whether the user still needs to set a morning intent for today.
final needsMorningIntentProvider = Provider.autoDispose<bool>((ref) {
  final hour = DateTime.now().hour;
  if (hour < 4 || hour >= 12) return false;
  final entry = ref.watch(journalForSelectedDateProvider).valueOrNull;
  return (entry?.morningIntent ?? '').trim().isEmpty;
});

/// Whether the user still needs to write a night review for today.
final needsNightReviewProvider = Provider.autoDispose<bool>((ref) {
  final hour = DateTime.now().hour;
  if (hour < 20) return false;
  final entry = ref.watch(journalForSelectedDateProvider).valueOrNull;
  return (entry?.nightReview ?? '').trim().isEmpty;
});

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Consecutive days (ending today, or yesterday as grace) with a non-empty
/// journal entry — the journaling streak. Capped by the 30-day window.
final journalingStreakProvider = Provider.autoDispose<int>((ref) {
  final entries = ref.watch(journalLast30Provider).valueOrNull ?? const [];
  final days = <String>{
    for (final e in entries)
      if (e.hasContent) _dayKey(e.date),
  };
  if (days.isEmpty) return 0;
  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  // Grace: if today has nothing yet, the streak counts back from yesterday.
  if (!days.contains(_dayKey(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(_dayKey(cursor))) return 0;
  }
  var streak = 0;
  while (days.contains(_dayKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});

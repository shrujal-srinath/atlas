import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
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

/// Entry for an arbitrary date (used by the editor sheet).
final journalForDateProvider =
    FutureProvider.autoDispose.family<JournalEntry?, DateTime>((ref, date) async {
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

/// Empty stub used when no entry yet — backed by current user id.
JournalEntry emptyEntryFor({required String userId, required DateTime date}) =>
    JournalEntry.empty(userId, date);

/// Convenience: today's entry-or-empty for the current user.
final todayOrEmptyJournalProvider = Provider.autoDispose<JournalEntry?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  final date = ref.watch(selectedDateProvider);
  final existing = ref.watch(journalForSelectedDateProvider).valueOrNull;
  if (existing != null) return existing;
  if (user == null) return null;
  return emptyEntryFor(userId: user.id, date: date);
});

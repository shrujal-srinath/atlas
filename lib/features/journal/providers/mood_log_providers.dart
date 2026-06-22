import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mood_log_repository.dart';
import '../domain/mood_log.dart';

final moodLogRepositoryProvider = Provider<MoodLogRepository>(
  (_) => MoodLogRepository(),
);

/// Today's mood check-ins (oldest → newest). Powers the latest-checkin chip
/// and the mood-through-the-day sparkline. Empty on error/offline.
final moodTodayLogsProvider = FutureProvider.autoDispose<List<MoodLog>>((
  ref,
) async {
  final repo = ref.watch(moodLogRepositoryProvider);
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  try {
    return await repo.since(startOfToday);
  } catch (_) {
    return const [];
  }
});

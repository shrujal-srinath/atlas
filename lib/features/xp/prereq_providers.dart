/// Providers for the user's level pre-requisites + their derived progress.
///
/// Each pre-req kind has its own derivation strategy. All progress numbers
/// are computed from existing data (habit_logs, daily_score_snapshots) — the
/// user never manually edits a counter. This keeps pre-reqs interlinked with
/// the daily tasks they tick off.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dev/dev_mode.dart';
import '../../shared/models/models.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../food/providers/food_providers.dart';
import '../habits/providers/habit_provider.dart';
import '../home/providers/home_providers.dart';
import 'leveling_engine.dart';
import 'leveling_providers.dart';
import 'level_prereq_repository.dart';
import 'models/level_prereq.dart';

const int _kPrereqScanDays = 90;

final levelPrereqRepoProvider =
    Provider<LevelPrereqRepository>((_) => const LevelPrereqRepository());

/// The user's chosen pre-requisites for a given target level (e.g., level 2 =
/// "pre-reqs to reach Level 2 from L1").
final userPrereqsProvider =
    FutureProvider.family<List<LevelPrereq>, int>((ref, level) async {
  if (ref.watch(devModeProvider)) {
    return ref.watch(_devPrereqStoreProvider)[level] ?? const [];
  }
  final session = ref.watch(sessionProvider);
  if (session == null) return const [];
  final repo = ref.watch(levelPrereqRepoProvider);
  return repo.forLevel(session.user.id, level);
});

/// In-memory pre-req store for dev mode — the picker writes here instead of
/// the DB. Survives hot reload, dies on cold restart.
final _devPrereqStoreProvider =
    StateProvider<Map<int, List<LevelPrereq>>>((_) => {});

/// Test-only / dev-only mutator used by the picker UI.
void addPrereqDevMode(WidgetRef ref, LevelPrereq prereq) {
  final cur = Map<int, List<LevelPrereq>>.from(
      ref.read(_devPrereqStoreProvider));
  final list = List<LevelPrereq>.from(cur[prereq.level] ?? const []);
  list.add(prereq);
  cur[prereq.level] = list;
  ref.read(_devPrereqStoreProvider.notifier).state = cur;
  ref.invalidate(userPrereqsProvider);
}

void removePrereqDevMode(WidgetRef ref, String id, int level) {
  final cur = Map<int, List<LevelPrereq>>.from(
      ref.read(_devPrereqStoreProvider));
  final list = List<LevelPrereq>.from(cur[level] ?? const []);
  list.removeWhere((p) => p.id == id);
  cur[level] = list;
  ref.read(_devPrereqStoreProvider.notifier).state = cur;
  ref.invalidate(userPrereqsProvider);
}

/// Per-pre-req current progress (derived) for the given target level.
final prereqProgressProvider =
    FutureProvider.family<List<PrereqProgress>, int>((ref, level) async {
  final defs = await ref.watch(userPrereqsProvider(level).future);
  if (defs.isEmpty) return const [];

  final results = <PrereqProgress>[];
  for (final d in defs) {
    final current = await _progressFor(ref, d);
    results.add(PrereqProgress(
      def: d,
      currentProgress: current,
      target: d.target,
      isMet: d.target > 0 && current >= d.target,
    ));
  }
  return results;
});

/// True iff the user has both the XP and all pre-reqs to advance to L+1.
/// If no pre-reqs are defined, only the XP gate applies.
final canLevelUpProvider = FutureProvider<bool>((ref) async {
  final cur = ref.watch(currentLevelProvider);
  final xp = ref.watch(cumulativeLevelXpProvider).valueOrNull ?? 0;
  final nextLevel = cur.level + 1;
  if (xp < xpForLevel(nextLevel)) return false;

  final progress = await ref.watch(prereqProgressProvider(nextLevel).future);
  return progress.every((p) => p.isMet);
});

// ────────────────────────────────────────────────────────────────────
// progress derivation
// ────────────────────────────────────────────────────────────────────

Future<int> _progressFor(Ref ref, LevelPrereq def) async {
  switch (def.kind) {
    case PrereqKind.habitCompletions:
      return _habitCompletionCount(ref, def.habitId);
    case PrereqKind.streakDays:
      return _currentStreakFor(ref, def.habitId);
    case PrereqKind.perfectDays:
      return _perfectDaysCount(ref, def.scoreThreshold);
    case PrereqKind.nutritionDays:
      return _nutritionDaysCount(ref, def.ratioThreshold);
  }
}

Future<int> _habitCompletionCount(Ref ref, String? habitId) async {
  if (habitId == null) return 0;
  if (ref.read(devModeProvider)) {
    final today = DateTime.now();
    int count = 0;
    for (int i = _kPrereqScanDays; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final logs =
          await ref.read(habitLogsForDateProvider(key).future);
      if (logs.any((l) => l.habitId == habitId && l.completed)) count++;
    }
    return count;
  }
  final session = ref.read(sessionProvider);
  if (session == null) return 0;
  try {
    final rows = await SupabaseService.client
        .from('habit_logs')
        .select('id')
        .eq('user_id', session.user.id)
        .eq('habit_id', habitId)
        .eq('completed', true);
    return (rows as List).length;
  } catch (_) {
    return 0;
  }
}

Future<int> _currentStreakFor(Ref ref, String? habitId) async {
  if (habitId == null) return 0;
  // Walk back from today; count consecutive days the habit was completed.
  final today = DateTime.now();
  int streak = 0;
  for (int i = 0; i < _kPrereqScanDays; i++) {
    final d = today.subtract(Duration(days: i));
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final logs = await ref.read(habitLogsForDateProvider(key).future);
    final done = logs.any((l) => l.habitId == habitId && l.completed);
    if (done) {
      streak++;
    } else {
      // Allow today to be incomplete without breaking the streak yet (the day
      // is in progress) — but break on any past day.
      if (i == 0) continue;
      break;
    }
  }
  return streak;
}

Future<int> _perfectDaysCount(Ref ref, int scoreThreshold) async {
  final today = DateTime.now();
  int count = 0;
  for (int i = _kPrereqScanDays; i >= 0; i--) {
    final d = today.subtract(Duration(days: i));
    final s = await ref.read(homeScoreProvider(d).future);
    if (s.score >= scoreThreshold) count++;
  }
  return count;
}

Future<int> _nutritionDaysCount(Ref ref, double ratioThreshold) async {
  // For dev mode and current day, derive live from food + targets.
  // For real mode + past days we'd ideally read from
  // `daily_score_snapshots.nutrition_ratio` — wired below as a fallback.
  if (ref.read(devModeProvider)) {
    // We only have mock food entries for today, so this returns 0 or 1.
    final r = ref.read(nutritionRatioProvider);
    return r >= ratioThreshold ? 1 : 0;
  }
  final session = ref.read(sessionProvider);
  if (session == null) return 0;
  try {
    final rows = await SupabaseService.client
        .from('daily_score_snapshots')
        .select('nutrition_ratio')
        .eq('user_id', session.user.id)
        .gte('nutrition_ratio', ratioThreshold);
    return (rows as List).length;
  } catch (_) {
    return 0;
  }
}

// ────────────────────────────────────────────────────────────────────
// Pretty labels (used by the picker UI + progression checklist)
// ────────────────────────────────────────────────────────────────────

/// Short, human-readable description of a pre-req (e.g.,
/// "5 gym sessions" or "21-day streak on No Phone After 10").
String describePrereq(LevelPrereq p, List<Habit> habits) {
  String habitName() {
    final h = habits.where((h) => h.id == p.habitId).firstOrNull;
    return h?.name ?? 'this habit';
  }

  switch (p.kind) {
    case PrereqKind.habitCompletions:
      return '${p.targetCount} ${habitName()} sessions';
    case PrereqKind.streakDays:
      return '${p.targetDays}-day streak on ${habitName()}';
    case PrereqKind.perfectDays:
      return '${p.targetCount} days at ≥${p.scoreThreshold}% score';
    case PrereqKind.nutritionDays:
      final pct = (p.ratioThreshold * 100).round();
      return '${p.targetCount} days at ≥$pct% nutrition';
  }
}

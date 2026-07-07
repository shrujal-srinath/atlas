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

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Which linked habits are negatives — so the derivation counts "clean days"
  // (no slip) instead of completions.
  final habits = await ref.watch(habitsProvider.future);
  final negativeIds = <String>{
    for (final h in habits)
      if (h.type == HabitType.negative) h.id,
  };

  final results = <PrereqProgress>[];
  for (final d in defs) {
    final current = await _progressFor(ref, d, negativeIds);
    final isMet = d.target > 0 && current >= d.target;
    int? daysLeft;
    final dl = d.deadline;
    if (dl != null) {
      final diff = dl.difference(today).inDays;
      daysLeft = diff < 0 ? 0 : diff;
    }
    results.add(PrereqProgress(
      def: d,
      currentProgress: current,
      target: d.target,
      isMet: isMet,
      daysLeft: daysLeft,
    ));
  }
  return results;
});

/// True iff the user has both the XP and all pre-reqs to advance from the
/// *confirmed* level to the next one. If no pre-reqs are defined, only the
/// XP gate applies. When this flips true the level-up overlay confirms the
/// transition (persisting `users.confirmed_level`), which recomputes this
/// provider — banked XP spanning several levels chains naturally.
final canLevelUpProvider = FutureProvider<bool>((ref) async {
  final confirmed = await ref.watch(confirmedLevelProvider.future);
  final xp = await ref.watch(cumulativeLevelXpProvider.future);
  final nextLevel = confirmed + 1;
  if (xp < xpForLevel(nextLevel)) return false;

  final progress = await ref.watch(prereqProgressProvider(nextLevel).future);
  return progress.every((p) => p.isMet);
});

// ────────────────────────────────────────────────────────────────────
// progress derivation
// ────────────────────────────────────────────────────────────────────

Future<int> _progressFor(Ref ref, LevelPrereq def, Set<String> negativeIds) async {
  // When a timeframe is set, only count activity on/after the start day.
  final since = def.hasWindow ? _dateKey(def.startedAt!) : null;
  final isNeg = def.habitId != null && negativeIds.contains(def.habitId);
  switch (def.kind) {
    case PrereqKind.habitCompletions:
      return _habitCompletionCount(ref, def.habitId, since, isNeg);
    case PrereqKind.streakDays:
      // A streak is inherently "current run"; the timeframe is a deadline only.
      // For a negative, the "streak" is consecutive clean (no-slip) days.
      return _currentStreakFor(ref, def.habitId, isNeg);
    case PrereqKind.perfectDays:
      return _perfectDaysCount(ref, def.scoreThreshold, since);
    case PrereqKind.nutritionDays:
      return _nutritionDaysCount(ref, def.ratioThreshold, since);
  }
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<int> _habitCompletionCount(
    Ref ref, String? habitId, String? since, bool isNegative) async {
  if (habitId == null) return 0;

  // Negative: "completions" = clean days (no slip) over the window.
  if (isNegative) {
    final today = _todayDate();
    if (ref.read(devModeProvider)) {
      int count = 0;
      for (int i = _kPrereqScanDays; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        final key = _dateKey(d);
        if (since != null && key.compareTo(since) < 0) continue;
        final logs = await ref.read(habitLogsForDateProvider(key).future);
        if (!logs.any((l) => l.habitId == habitId && !l.completed)) count++;
      }
      return count;
    }
    final session = ref.read(sessionProvider);
    if (session == null) return 0;
    final start = since != null
        ? DateTime.parse(since)
        : today.subtract(const Duration(days: _kPrereqScanDays));
    final elapsed =
        today.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    int slipDays = 0;
    try {
      var q = SupabaseService.client
          .from('habit_logs')
          .select('date')
          .eq('user_id', session.user.id)
          .eq('habit_id', habitId)
          .eq('completed', false);
      if (since != null) q = q.gte('date', since);
      final rows = await q;
      slipDays = (rows as List).map((r) => r['date'] as String).toSet().length;
    } catch (_) {}
    final clean = elapsed - slipDays;
    return clean < 0 ? 0 : clean;
  }

  if (ref.read(devModeProvider)) {
    final today = DateTime.now();
    int count = 0;
    for (int i = _kPrereqScanDays; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key = _dateKey(d);
      if (since != null && key.compareTo(since) < 0) continue;
      final logs =
          await ref.read(habitLogsForDateProvider(key).future);
      if (logs.any((l) => l.habitId == habitId && l.completed)) count++;
    }
    return count;
  }
  final session = ref.read(sessionProvider);
  if (session == null) return 0;
  try {
    var q = SupabaseService.client
        .from('habit_logs')
        .select('id')
        .eq('user_id', session.user.id)
        .eq('habit_id', habitId)
        .eq('completed', true);
    if (since != null) q = q.gte('date', since);
    final rows = await q;
    return (rows as List).length;
  } catch (_) {
    return 0;
  }
}

Future<int> _currentStreakFor(Ref ref, String? habitId, bool isNegative) async {
  if (habitId == null) return 0;
  // Walk back from today. Positive: consecutive *completed* days. Negative:
  // consecutive *clean* days (no logged slip) — a slip resets the clean streak.
  final today = DateTime.now();
  int streak = 0;
  for (int i = 0; i < _kPrereqScanDays; i++) {
    final d = today.subtract(Duration(days: i));
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final logs = await ref.read(habitLogsForDateProvider(key).future);
    final ok = isNegative
        ? !logs.any((l) => l.habitId == habitId && !l.completed) // no slip
        : logs.any((l) => l.habitId == habitId && l.completed);
    if (ok) {
      streak++;
    } else {
      // Positive today-incomplete is in-progress grace; a negative slip (even
      // today) breaks the clean run immediately.
      if (!isNegative && i == 0) continue;
      break;
    }
  }
  return streak;
}

Future<int> _perfectDaysCount(Ref ref, int scoreThreshold, String? since) async {
  final today = DateTime.now();
  // Dev mode: no snapshot table — recompute from mock scores.
  if (ref.read(devModeProvider)) {
    int count = 0;
    for (int i = _kPrereqScanDays; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      if (since != null && _dateKey(d).compareTo(since) < 0) continue;
      final s = await ref.read(homeScoreProvider(d).future);
      if (s.score >= scoreThreshold) count++;
    }
    return count;
  }
  // Real mode: past days come from the snapshot ledger; today is live.
  final session = ref.read(sessionProvider);
  if (session == null) return 0;
  int count = 0;
  try {
    var q = SupabaseService.client
        .from('daily_score_snapshots')
        .select('id')
        .eq('user_id', session.user.id)
        .lt('date', _todayKey())
        .gte('score', scoreThreshold);
    if (since != null) q = q.gte('date', since);
    count = (await q as List).length;
  } catch (_) {}
  try {
    final t = await ref.read(homeScoreProvider(_todayDate()).future);
    if (t.score >= scoreThreshold) count++;
  } catch (_) {}
  return count;
}

DateTime _todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _todayKey() {
  final d = _todayDate();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<int> _nutritionDaysCount(
    Ref ref, double ratioThreshold, String? since) async {
  // Past days come from the `nutrition_ratio` cached on each snapshot row
  // by the writer; today is derived live from the food log.
  if (ref.read(devModeProvider)) {
    // We only have mock food entries for today, so this returns 0 or 1.
    final r = ref.read(todayNutritionRatioProvider);
    return r >= ratioThreshold ? 1 : 0;
  }
  final session = ref.read(sessionProvider);
  if (session == null) return 0;
  int count = 0;
  try {
    var q = SupabaseService.client
        .from('daily_score_snapshots')
        .select('id')
        .eq('user_id', session.user.id)
        .lt('date', _todayKey())
        .gte('nutrition_ratio', ratioThreshold);
    if (since != null) q = q.gte('date', since);
    count = (await q as List).length;
  } catch (_) {}
  if (ref.read(todayNutritionRatioProvider) >= ratioThreshold) count++;
  return count;
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

  final base = switch (p.kind) {
    PrereqKind.habitCompletions => '${p.targetCount} ${habitName()} sessions',
    PrereqKind.streakDays => '${p.targetDays}-day streak on ${habitName()}',
    PrereqKind.perfectDays => '${p.targetCount} days at ≥${p.scoreThreshold}% score',
    PrereqKind.nutritionDays =>
      '${p.targetCount} days at ≥${(p.ratioThreshold * 100).round()}% nutrition',
  };
  final w = p.windowDays;
  return w == null ? base : '$base · in $w days';
}

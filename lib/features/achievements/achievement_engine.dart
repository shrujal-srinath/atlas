/// Achievement evaluation engine. Pure functions that take an aggregated
/// [UserStats] snapshot and return per-rule progress. The provider layer
/// detects newly-unlocked achievements, persists them, awards XP, and pushes
/// a notification row — see [achievementUnlockerProvider] below.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/dev/dev_mode.dart';
import '../../shared/models/models.dart';
import '../../shared/services/supabase_service.dart';
import '../auth/providers/auth_provider.dart';
import '../habits/providers/habit_provider.dart';
import '../journal/providers/journal_providers.dart';
import '../xp/leveling_providers.dart';
import 'achievement_catalog.dart';
import 'achievement_provider.dart';

class AchievementProgress {
  final String id;
  final int current;
  final int target;
  final bool unlocked;
  const AchievementProgress({
    required this.id,
    required this.current,
    required this.target,
    required this.unlocked,
  });
  double get fraction => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
}

class UserStats {
  final int totalCompletions;
  final int meditationStreak;
  final int longestHabitStreak;
  final int eveningCompletions;
  final int journalEntries;
  final int trifectaDays;
  final int perfectDayStreak;
  /// User's current XP level (from `currentLevelProvider`). Drives
  /// `level_5/10/20` unlocks.
  final int currentLevel;
  /// Number of active habits the user has created. Drives the architect
  /// `architect_5/10/25` unlocks.
  final int habitCount;
  const UserStats({
    this.totalCompletions = 0,
    this.meditationStreak = 0,
    this.longestHabitStreak = 0,
    this.eveningCompletions = 0,
    this.journalEntries = 0,
    this.trifectaDays = 0,
    this.perfectDayStreak = 0,
    this.currentLevel = 1,
    this.habitCount = 0,
  });
}

// ────────────────────────────────────────────────────────────────────
// STATS AGGREGATION
// ────────────────────────────────────────────────────────────────────

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  if (ref.watch(devModeProvider)) return const UserStats();

  final habits = await ref.watch(habitsProvider.future);
  final logs = await ref.watch(recentHabitLogsProvider.future);
  final journalEntries = await ref.watch(journalLast30Provider.future);

  final habitById = {for (final h in habits) h.id: h};

  // Per-habit completion log map.
  final logsByHabit = <String, List<HabitLog>>{};
  for (final l in logs) {
    if (!l.completed) continue;
    (logsByHabit[l.habitId] ??= []).add(l);
  }

  // Longest streak across all habits.
  int longestStreak = 0;
  for (final entry in logsByHabit.entries) {
    final dates = entry.value.map((l) => l.date).toSet().toList()..sort();
    if (dates.isEmpty) continue;
    int run = 1, best = 1;
    for (int i = 1; i < dates.length; i++) {
      final prev = DateTime.parse(dates[i - 1]);
      final cur = DateTime.parse(dates[i]);
      if (cur.difference(prev).inDays == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    if (best > longestStreak) longestStreak = best;
  }

  // Meditation streak — habits whose name contains 'meditat' or icon='moon'.
  int meditationStreak = 0;
  for (final entry in logsByHabit.entries) {
    final h = habitById[entry.key];
    if (h == null) continue;
    final isMeditation = h.name.toLowerCase().contains('meditat') ||
        h.icon.contains('moon');
    if (!isMeditation) continue;
    final dates = entry.value.map((l) => l.date).toSet().toList()..sort();
    int best = 0, run = 0;
    DateTime? last;
    for (final d in dates) {
      final cur = DateTime.parse(d);
      if (last == null || cur.difference(last).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      last = cur;
    }
    if (best > meditationStreak) meditationStreak = best;
  }

  // Evening habit completions.
  int eveningCompletions = 0;
  for (final l in logs) {
    if (!l.completed) continue;
    final h = habitById[l.habitId];
    if (h == null) continue;
    if (h.timePeriod == TimePeriod.evening) eveningCompletions++;
  }

  // Trifecta + perfect-day-streak: walk last 30 days, compute per-day sections done.
  int trifectaDays = 0, perfectStreak = 0, perfectRun = 0;
  for (int i = 0; i < 30; i++) {
    final d = DateTime.now().subtract(Duration(days: i));
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final dayLogs = logs.where((l) => l.date == key && l.completed).toList();
    if (dayLogs.isEmpty) {
      perfectRun = 0;
      continue;
    }
    final sectionsCovered = <HabitSection>{};
    final eligibleHabits = habits
        .where((h) => !h.isArchived && _appliesOn(h, d))
        .toList();
    final perfect = eligibleHabits.isNotEmpty &&
        eligibleHabits.every((h) =>
            dayLogs.any((l) => l.habitId == h.id));
    for (final l in dayLogs) {
      final h = habitById[l.habitId];
      if (h != null) sectionsCovered.add(h.section);
    }
    if (sectionsCovered.length == HabitSection.values.length) trifectaDays++;
    if (perfect) {
      perfectRun++;
      if (perfectRun > perfectStreak) perfectStreak = perfectRun;
    } else if (i == 0) {
      // Today not yet perfect — still in-progress, don't reset.
    } else {
      perfectRun = 0;
    }
  }

  return UserStats(
    totalCompletions: logs.where((l) => l.completed).length,
    meditationStreak: meditationStreak,
    longestHabitStreak: longestStreak,
    eveningCompletions: eveningCompletions,
    journalEntries: journalEntries.length,
    trifectaDays: trifectaDays,
    perfectDayStreak: perfectStreak,
    currentLevel: ref.watch(currentLevelProvider).level,
    habitCount: habits.length,
  );
});

bool _appliesOn(Habit h, DateTime date) {
  if (h.isArchived) return false;
  if (h.type == HabitType.todo) return true;
  switch (h.frequencyMode) {
    case FrequencyMode.everyDay:
      return true;
    case FrequencyMode.specificDays:
      return h.daysOfWeek.contains(date.weekday);
    case FrequencyMode.timesPerWeek:
      return true;
  }
}

// ────────────────────────────────────────────────────────────────────
// PER-RULE EVALUATORS
// ────────────────────────────────────────────────────────────────────

AchievementProgress _eval(String id, UserStats s) {
  switch (id) {
    case 'first_light':
      return AchievementProgress(
        id: id,
        current: s.totalCompletions.clamp(0, 1),
        target: 1,
        unlocked: s.totalCompletions >= 1,
      );
    case 'zen_mind':
      return AchievementProgress(
        id: id,
        current: s.meditationStreak,
        target: 30,
        unlocked: s.meditationStreak >= 30,
      );
    case 'iron_will':
      return AchievementProgress(
        id: id,
        current: s.perfectDayStreak,
        target: 7,
        unlocked: s.perfectDayStreak >= 7,
      );
    case 'streakzilla':
      return AchievementProgress(
        id: id,
        current: s.longestHabitStreak,
        target: 60,
        unlocked: s.longestHabitStreak >= 60,
      );
    case 'night_owl':
      return AchievementProgress(
        id: id,
        current: s.eveningCompletions,
        target: 30,
        unlocked: s.eveningCompletions >= 30,
      );
    case 'reflector':
      return AchievementProgress(
        id: id,
        current: s.journalEntries,
        target: 30,
        unlocked: s.journalEntries >= 30,
      );
    case 'trifecta':
      return AchievementProgress(
        id: id,
        current: s.trifectaDays.clamp(0, 1),
        target: 1,
        unlocked: s.trifectaDays >= 1,
      );
    case 'perfectionist':
      return AchievementProgress(
        id: id,
        current: s.perfectDayStreak,
        target: 30,
        unlocked: s.perfectDayStreak >= 30,
      );
    // ── New: streak tiers (powered by longestHabitStreak)
    case 'streak_3':
      return AchievementProgress(
        id: id,
        current: s.longestHabitStreak,
        target: 3,
        unlocked: s.longestHabitStreak >= 3,
      );
    case 'streak_7':
      return AchievementProgress(
        id: id,
        current: s.longestHabitStreak,
        target: 7,
        unlocked: s.longestHabitStreak >= 7,
      );
    case 'streak_30':
      return AchievementProgress(
        id: id,
        current: s.longestHabitStreak,
        target: 30,
        unlocked: s.longestHabitStreak >= 30,
      );
    case 'streak_100':
      return AchievementProgress(
        id: id,
        current: s.longestHabitStreak,
        target: 100,
        unlocked: s.longestHabitStreak >= 100,
      );
    // ── New: level milestones
    case 'level_5':
      return AchievementProgress(
        id: id,
        current: s.currentLevel,
        target: 5,
        unlocked: s.currentLevel >= 5,
      );
    case 'level_10':
      return AchievementProgress(
        id: id,
        current: s.currentLevel,
        target: 10,
        unlocked: s.currentLevel >= 10,
      );
    case 'level_20':
      return AchievementProgress(
        id: id,
        current: s.currentLevel,
        target: 20,
        unlocked: s.currentLevel >= 20,
      );
    // ── New: architect (habit count)
    case 'architect_5':
      return AchievementProgress(
        id: id,
        current: s.habitCount,
        target: 5,
        unlocked: s.habitCount >= 5,
      );
    case 'architect_10':
      return AchievementProgress(
        id: id,
        current: s.habitCount,
        target: 10,
        unlocked: s.habitCount >= 10,
      );
    case 'architect_25':
      return AchievementProgress(
        id: id,
        current: s.habitCount,
        target: 25,
        unlocked: s.habitCount >= 25,
      );
    // Stubs — wired when their data sources land.
    case 'early_bird':
    case 'centurion':
    case 'bookworm':
    case 'unbroken':
    case 'hydromancer':
    case 'macro_boss':
    case 'marathon_mind':
    case 'iron_lift':
    case 'phoenix':
    case 'bowlers_arm':
    case 'comeback':
    case 'veteran':
    default:
      return AchievementProgress(id: id, current: 0, target: 1, unlocked: false);
  }
}

/// Progress across the full catalog. Watched by Progression screen + unlocker.
final achievementProgressProvider =
    FutureProvider<List<AchievementProgress>>((ref) async {
  final s = await ref.watch(userStatsProvider.future);
  return achievementCatalog.map((def) => _eval(def.id, s)).toList();
});

// ────────────────────────────────────────────────────────────────────
// UNLOCK SIDE-EFFECT
// ────────────────────────────────────────────────────────────────────

/// Watches [achievementProgressProvider] and persists any newly-passed
/// thresholds. Best-effort — failures swallowed so the rest of the app keeps
/// working if the migration hasn't run.
final achievementUnlockerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<AchievementProgress>>>(
    achievementProgressProvider,
    (_, next) {
      final list = next.valueOrNull;
      if (list == null) return;
      final session = ref.read(sessionProvider);
      if (session == null) return;
      final unlocked = ref.read(unlockedAchievementsProvider).valueOrNull ??
          const <String>{};
      for (final p in list) {
        if (!p.unlocked) continue;
        if (unlocked.contains(p.id)) continue;
        _persistUnlock(ref, p.id, session.user.id);
      }
    },
    fireImmediately: true,
  );
});

Future<void> _persistUnlock(Ref ref, String id, String userId) async {
  final def = achievementCatalog.firstWhere((a) => a.id == id);
  try {
    await SupabaseService.client.from('user_achievements').insert({
      'user_id': userId,
      'achievement_id': id,
    });
    // v2: bonus XP is added to today's `daily_score_snapshots.bonus_xp` so it
    // flows into the cumulative level XP via the same source-of-truth table
    // that score-derived XP uses. No more parallel `xp_events` writes.
    await DailySnapshotWriter.addTodayBonus(
      userId: userId,
      xp: def.xpReward,
    );
    try {
      await SupabaseService.client.from('notifications').insert({
        'user_id': userId,
        'type': 'achievement',
        'title': 'Achievement unlocked',
        'body': '${def.name} · +${def.xpReward} XP',
        'payload': {'achievement_id': id},
      });
    } catch (_) {}
    ref.invalidate(unlockedAchievementsProvider);
    ref.invalidate(cumulativeLevelXpProvider);
  } catch (_) {
    // Likely duplicate-key (race) or missing migration. Safe to ignore.
  }
}

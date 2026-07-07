/// Achievement evaluation engine. Pure functions that take an aggregated
/// [UserStats] snapshot and return per-rule progress. The provider layer
/// detects newly-unlocked achievements, persists them, awards XP, and pushes
/// a notification row — see [achievementUnlockerProvider] below.
library;

import 'package:flutter/foundation.dart';
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
  // ── Lifetime cumulative + domain stats (from lifetimeCompletedLogsProvider).
  /// Completed sessions of strength/gym habits → `centurion`.
  final int gymSessions;
  /// Cumulative pages from reading habits' actual values → `bookworm`.
  final int pagesRead;
  /// Cumulative km from distance-goal running habits → `marathon_mind`.
  final int kmRun;
  /// Cumulative kg volume from lifting habits → `iron_lift`.
  final int kgLifted;
  /// Cumulative deliveries from bowling habits → `bowlers_arm`.
  final int deliveries;
  /// Completed morning-period running sessions → `early_bird`.
  final int dawnRuns;
  /// Consecutive recent days with no missed Critical-priority habit → `unbroken`.
  final int criticalAdherenceStreak;
  /// Longest consecutive run of active days (any completion) → `veteran`.
  final int activeDayStreak;
  /// A habit was revived after a ≥14-day broken streak → `phoenix`.
  final bool phoenixResume;
  /// Longest consecutive-day run hitting the water target → `hydromancer`.
  final int hydrationStreak;
  /// Longest consecutive-day run hitting the protein target → `macro_boss`.
  final int proteinStreak;
  /// A day's score beat the prior day by ≥10 points → `comeback`.
  final bool comebackHit;
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
    this.gymSessions = 0,
    this.pagesRead = 0,
    this.kmRun = 0,
    this.kgLifted = 0,
    this.deliveries = 0,
    this.dawnRuns = 0,
    this.criticalAdherenceStreak = 0,
    this.activeDayStreak = 0,
    this.phoenixResume = false,
    this.hydrationStreak = 0,
    this.proteinStreak = 0,
    this.comebackHit = false,
  });
}

/// Coarse activity domain inferred from a habit's name, icon, and goal type.
/// Used to attribute completions/values to the right cumulative achievement.
enum _Domain { gym, lifting, reading, running, bowling, other }

_Domain _domainOf(Habit h) {
  final n = h.name.toLowerCase();
  final ic = h.icon.toLowerCase();
  bool has(List<String> kws) => kws.any(n.contains);
  if (has(['bowl', 'deliver', 'spell', 'net session', 'over rate'])) {
    return _Domain.bowling;
  }
  if (has(['read', 'book', 'pages', 'chapter']) || ic.contains('book')) {
    return _Domain.reading;
  }
  if (has(['run', 'jog', 'sprint', 'marathon', '5k', '10k']) ||
      ic.contains('footprint') ||
      h.goalType == GoalType.distanceKm) {
    return _Domain.running;
  }
  if (has(['lift', 'deadlift', 'squat', 'bench', 'press', 'volume'])) {
    return _Domain.lifting;
  }
  if (has(['gym', 'workout', 'strength', 'training', 'wod', 'crossfit']) ||
      ic.contains('dumbbell')) {
    return _Domain.gym;
  }
  return _Domain.other;
}

/// Longest run of consecutive calendar days present in [isoDates] (yyyy-MM-dd).
int _longestConsecutiveRun(Iterable<String> isoDates) {
  final days = isoDates.toSet().toList()..sort();
  if (days.isEmpty) return 0;
  int best = 1, run = 1;
  for (int i = 1; i < days.length; i++) {
    final prev = DateTime.parse(days[i - 1]);
    final cur = DateTime.parse(days[i]);
    if (cur.difference(prev).inDays == 1) {
      run++;
      if (run > best) best = run;
    } else if (cur.difference(prev).inDays != 0) {
      run = 1;
    }
  }
  return best;
}

// ────────────────────────────────────────────────────────────────────
// STATS AGGREGATION
// ────────────────────────────────────────────────────────────────────

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  if (ref.watch(devModeProvider)) return const UserStats();

  final habits = await ref.watch(habitsProvider.future);
  // Lifetime (not 60-day) completed logs — cumulative totals and long streaks
  // need the full history to ever cross their thresholds.
  final logs = await ref.watch(lifetimeCompletedLogsProvider.future);
  final journalEntries = await ref.watch(journalLast30Provider.future);
  final user = ref.watch(appUserProvider).valueOrNull;

  final habitById = {for (final h in habits) h.id: h};

  // Per-habit completion log map (logs are already completed-only).
  final logsByHabit = <String, List<HabitLog>>{};
  for (final l in logs) {
    (logsByHabit[l.habitId] ??= []).add(l);
  }

  // Longest streak across all habits.
  int longestStreak = 0;
  for (final entry in logsByHabit.entries) {
    final best = _longestConsecutiveRun(entry.value.map((l) => l.date));
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
    final best = _longestConsecutiveRun(entry.value.map((l) => l.date));
    if (best > meditationStreak) meditationStreak = best;
  }

  // Evening completions + lifetime per-domain cumulative stats.
  int eveningCompletions = 0, gymSessions = 0, dawnRuns = 0;
  double pages = 0, km = 0, kg = 0, deliveries = 0;
  for (final l in logs) {
    final h = habitById[l.habitId];
    if (h == null) continue;
    if (h.timePeriod == TimePeriod.evening) eveningCompletions++;
    final v = l.actualValue ?? 0;
    switch (_domainOf(h)) {
      case _Domain.gym:
        gymSessions++;
      case _Domain.lifting:
        gymSessions++;
        kg += v;
      case _Domain.reading:
        pages += v;
      case _Domain.running:
        if (h.goalType == GoalType.distanceKm) km += v;
        if (h.timePeriod == TimePeriod.morning) dawnRuns++;
      case _Domain.bowling:
        deliveries += v;
      case _Domain.other:
        break;
    }
  }

  // Longest run of active days (any completion) → veteran.
  final activeDayStreak = _longestConsecutiveRun(logs.map((l) => l.date));

  // Phoenix — a habit revived after a ≥14-day broken streak (gap ≥ 15 days
  // between two completions means 14+ missed days in between).
  bool phoenix = false;
  for (final entry in logsByHabit.entries) {
    final dates = entry.value.map((l) => l.date).toSet().toList()..sort();
    for (int i = 1; i < dates.length && !phoenix; i++) {
      final gap = DateTime.parse(dates[i])
          .difference(DateTime.parse(dates[i - 1]))
          .inDays;
      if (gap >= 15) phoenix = true;
    }
    if (phoenix) break;
  }

  // Trifecta + perfect-day-streak: walk last 30 days, compute per-day sections.
  int trifectaDays = 0, perfectStreak = 0, perfectRun = 0;
  for (int i = 0; i < 30; i++) {
    final d = DateTime.now().subtract(Duration(days: i));
    final key = _dateKey(d);
    final dayLogs = logs.where((l) => l.date == key).toList();
    if (dayLogs.isEmpty) {
      perfectRun = 0;
      continue;
    }
    final sectionsCovered = <HabitSection>{};
    final eligibleHabits =
        habits.where((h) => !h.isArchived && _appliesOn(h, d)).toList();
    final perfect = eligibleHabits.isNotEmpty &&
        eligibleHabits.every((h) => dayLogs.any((l) => l.habitId == h.id));
    for (final l in dayLogs) {
      final h = habitById[l.habitId];
      if (h != null) sectionsCovered.add(h.sectionId.toSectionEnum());
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

  // Unbroken — consecutive recent days with no *missed* Critical habit. Only
  // meaningful once the user actually has a Critical habit.
  int criticalStreak = 0;
  final hasCritical = habits
      .any((h) => !h.isArchived && h.priority == HabitPriority.critical);
  if (hasCritical) {
    for (int i = 0; i < 120; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = _dateKey(d);
      final eligible = habits.where((h) =>
          !h.isArchived &&
          h.priority == HabitPriority.critical &&
          _appliesOn(h, d));
      if (eligible.isEmpty) continue; // nothing scheduled → nothing to miss
      final allDone = eligible
          .every((h) => logs.any((l) => l.habitId == h.id && l.date == key));
      if (allDone) {
        criticalStreak++;
      } else if (i == 0) {
        // Today still in progress — don't break the run yet.
      } else {
        break;
      }
    }
  }

  // Nutrition + score streaks come from their own tables. Best-effort: if a
  // migration is missing or the user is offline, leave them at zero.
  int hydrationStreak = 0, proteinStreak = 0;
  bool comeback = false;
  try {
    hydrationStreak =
        await _targetStreak('water_logs', 'ml', (user?.waterTargetMl ?? 0).toDouble());
  } catch (_) {}
  try {
    proteinStreak = await _targetStreak(
        'food_logs', 'protein', (user?.dailyProteinTarget ?? 0).toDouble());
  } catch (_) {}
  try {
    comeback = await _comebackHit();
  } catch (_) {}

  return UserStats(
    totalCompletions: logs.length,
    meditationStreak: meditationStreak,
    longestHabitStreak: longestStreak,
    eveningCompletions: eveningCompletions,
    journalEntries: journalEntries.length,
    trifectaDays: trifectaDays,
    perfectDayStreak: perfectStreak,
    currentLevel: ref.watch(currentLevelProvider).level,
    habitCount: habits.length,
    gymSessions: gymSessions,
    pagesRead: pages.round(),
    kmRun: km.round(),
    kgLifted: kg.round(),
    deliveries: deliveries.round(),
    dawnRuns: dawnRuns,
    criticalAdherenceStreak: criticalStreak,
    activeDayStreak: activeDayStreak,
    phoenixResume: phoenix,
    hydrationStreak: hydrationStreak,
    proteinStreak: proteinStreak,
    comebackHit: comeback,
  );
});

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Longest consecutive-day run where [table]'s per-day sum of [valueCol] meets
/// [target]. Used for the hydration (water_logs.ml) and protein
/// (food_logs.protein) streak achievements.
Future<int> _targetStreak(String table, String valueCol, double target) async {
  if (target <= 0) return 0;
  final rows =
      await SupabaseService.client.from(table).select('date, $valueCol');
  final perDay = <String, double>{};
  for (final r in (rows as List)) {
    final d = r['date'] as String?;
    if (d == null) continue;
    perDay[d] = (perDay[d] ?? 0) + ((r[valueCol] as num?)?.toDouble() ?? 0);
  }
  return _longestConsecutiveRun(
      perDay.entries.where((e) => e.value >= target).map((e) => e.key));
}

/// True if any day's score beat the immediately-prior recorded day by ≥10.
Future<bool> _comebackHit() async {
  final rows = await SupabaseService.client
      .from('daily_score_snapshots')
      .select('date, score')
      .order('date');
  int? prev;
  for (final r in (rows as List)) {
    final s = (r['score'] as num?)?.toInt() ?? 0;
    if (prev != null && s - prev >= 10) return true;
    prev = s;
  }
  return false;
}

bool _appliesOn(Habit h, DateTime date) {
  if (h.isArchived) return false;
  // Days before the habit existed aren't scheduled — so a pre-creation day
  // never breaks a "perfect run" style achievement.
  if (!h.existedOn(date)) return false;
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
    // ── Lifetime cumulative + domain achievements.
    case 'early_bird':
      return _p(id, s.dawnRuns, 14);
    case 'centurion':
      return _p(id, s.gymSessions, 100);
    case 'bookworm':
      return _p(id, s.pagesRead, 1000);
    case 'marathon_mind':
      return _p(id, s.kmRun, 200);
    case 'iron_lift':
      return _p(id, s.kgLifted, 10000);
    case 'bowlers_arm':
      return _p(id, s.deliveries, 5000);
    case 'unbroken':
      return _p(id, s.criticalAdherenceStreak, 30);
    case 'veteran':
      return _p(id, s.activeDayStreak, 365);
    case 'hydromancer':
      return _p(id, s.hydrationStreak, 14);
    case 'macro_boss':
      return _p(id, s.proteinStreak, 30);
    case 'phoenix':
      return AchievementProgress(
        id: id,
        current: s.phoenixResume ? 1 : 0,
        target: 1,
        unlocked: s.phoenixResume,
      );
    case 'comeback':
      return AchievementProgress(
        id: id,
        current: s.comebackHit ? 1 : 0,
        target: 1,
        unlocked: s.comebackHit,
      );
    default:
      return AchievementProgress(id: id, current: 0, target: 1, unlocked: false);
  }
}

/// Threshold progress helper: clamps [current] to [target] for the bar while
/// unlocking once [current] reaches [target].
AchievementProgress _p(String id, int current, int target) => AchievementProgress(
      id: id,
      current: current.clamp(0, target),
      target: target,
      unlocked: current >= target,
    );

/// Test seam for the pure per-rule evaluator.
@visibleForTesting
AchievementProgress evalAchievement(String id, UserStats s) => _eval(id, s);

/// Test seam for the consecutive-day run counter.
@visibleForTesting
int longestConsecutiveRun(Iterable<String> isoDates) =>
    _longestConsecutiveRun(isoDates);

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

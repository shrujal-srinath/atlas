import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/hive_service.dart';
import '../../../shared/services/offline_writer.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/services/sync_queue.dart';
import '../../../core/dev/dev_mode.dart';
import '../../auth/providers/auth_provider.dart';
import '../../food/providers/food_providers.dart';

/// Date-only (no time-of-day) so family providers keyed by [DateTime]
/// (`homeScoreProvider`, `homeTasksProvider`) share a cache key with the week
/// strip / day rail, which always write date-only values here. A seed with a
/// full timestamp used to cause today's tasks/score to compute twice.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Demo/dev only: in-memory habit-log overrides keyed by `'habitId|date'`. The
/// demo has no Supabase session, so [HabitActionsNotifier.toggleHabit] writes
/// here and the log providers merge these over the generated mock logs — so
/// finishing a task in the demo actually closes it AND moves the score/level.
final devLogOverridesProvider = StateProvider<Map<String, HabitLog>>((_) => {});

/// Merges any [devLogOverridesProvider] entries over [base] (override wins on a
/// matching habit+date). No-op when there are no overrides.
List<HabitLog> _withDevOverrides(Ref ref, List<HabitLog> base) {
  final ov = ref.watch(devLogOverridesProvider);
  if (ov.isEmpty) return base;
  final byKey = {for (final l in base) '${l.habitId}|${l.date}': l};
  byKey.addAll(ov);
  return byKey.values.toList();
}

final habitsProvider = FutureProvider<List<Habit>>((ref) async {
  if (ref.watch(devModeProvider)) return mockHabits;
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final data = await SupabaseService.client
      .from('habits')
      .select()
      .eq('user_id', session.user.id)
      .eq('is_archived', false)
      .order('sort_order')
      .order('created_at');
  return (data as List).map((e) => Habit.fromJson(e)).toList();
});

/// All habits including archived. Used by the library screen.
final allHabitsProvider = FutureProvider<List<Habit>>((ref) async {
  if (ref.watch(devModeProvider)) return mockHabits;
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final data = await SupabaseService.client
      .from('habits')
      .select()
      .eq('user_id', session.user.id)
      .order('sort_order')
      .order('created_at');
  return (data as List).map((e) => Habit.fromJson(e)).toList();
});

/// Read-through the `habit_logs_cache` Hive box + the pending `SyncQueue`
/// (HABITS_AUDIT §3.7, same pattern as food_repository.dart's SR-1 fix): a
/// fetch failure (offline) falls back to the last-good cached rows instead
/// of throwing, and any not-yet-synced upsert for [date] is merged in either
/// way, so toggling a habit offline is reflected immediately instead of
/// waiting for the queue to drain.
final habitLogsForDateProvider = FutureProvider.family<List<HabitLog>, String>((
  ref,
  date,
) async {
  if (ref.watch(devModeProvider)) {
    final base = generateMockLogs().where((l) => l.date == date).toList();
    return _withDevOverrides(ref, base).where((l) => l.date == date).toList();
  }
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final cacheKey = 'byDate:$date';
  List<Map<String, dynamic>> rows;
  try {
    final data = await SupabaseService.client
        .from('habit_logs')
        .select()
        .eq('user_id', session.user.id)
        .eq('date', date);
    rows = (data as List).cast<Map<String, dynamic>>();
    unawaited(HiveService.put(HiveService.habitLogsBox, cacheKey, rows));
  } catch (_) {
    rows = _readCachedHabitLogs(cacheKey);
  }
  final merged = _mergePendingHabitLogOps(rows, date: date);
  return merged.map((e) => HabitLog.fromJson(e)).toList();
});

/// Last 60 days of completed logs — used for streak calculation across all
/// habits. Same read-through treatment as [habitLogsForDateProvider], cached
/// as one blob (a 60-day range doesn't map to a single `byDate` key).
final recentHabitLogsProvider = FutureProvider<List<HabitLog>>((ref) async {
  if (ref.watch(devModeProvider)) {
    return _withDevOverrides(ref, generateMockLogs());
  }
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final since = DateTime.now().subtract(const Duration(days: 60));
  final sinceStr =
      '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
  const cacheKey = 'recent60';
  List<Map<String, dynamic>> rows;
  try {
    final data = await SupabaseService.client
        .from('habit_logs')
        .select()
        .eq('user_id', session.user.id)
        .gte('date', sinceStr);
    rows = (data as List).cast<Map<String, dynamic>>();
    unawaited(HiveService.put(HiveService.habitLogsBox, cacheKey, rows));
  } catch (_) {
    rows = _readCachedHabitLogs(cacheKey);
  }
  final merged = _mergePendingHabitLogOps(rows);
  return merged.map((e) => HabitLog.fromJson(e)).toList();
});

List<Map<String, dynamic>> _readCachedHabitLogs(String cacheKey) {
  final cached = HiveService.get<List>(HiveService.habitLogsBox, cacheKey);
  if (cached == null) return const [];
  return cached.cast<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

/// Overlays pending `habit_logs` [SyncQueue] ops onto [base] rows — unsynced
/// upserts appear/patch in place, unsynced deletes are hidden — whether
/// [base] came from a live fetch or the cache. Keyed by `habit_id|date`
/// (the natural identity for a habit log) rather than row `id`, since a
/// queued upsert doesn't carry a client-generated id (see toggleHabit).
/// [date] narrows the merge to one day; omit it for a multi-day range.
List<Map<String, dynamic>> _mergePendingHabitLogOps(
  List<Map<String, dynamic>> base, {
  String? date,
}) {
  final ops = SyncQueue.instance.pendingOpsFor('habit_logs');
  if (ops.isEmpty) return base;
  String keyOf(Map<String, dynamic> r) => '${r['habit_id']}|${r['date']}';
  final byKey = {for (final r in base) keyOf(r): r};
  for (final op in ops) {
    switch (op.op) {
      case 'upsert':
      case 'insert':
        if (date == null || op.payload['date'] == date) {
          final key = keyOf(op.payload);
          byKey[key] = {...?byKey[key], ...op.payload};
        }
      case 'update':
        final id = op.matchId;
        final existing = byKey.values.where((r) => r['id'] == id).firstOrNull;
        if (existing != null) {
          byKey[keyOf(existing)] = {...existing, ...op.payload};
        }
      case 'delete':
        byKey.removeWhere((_, r) => r['id'] == op.matchId);
    }
  }
  return byKey.values.toList();
}

/// All habit logs over the last [days] days in ONE query — powers the stats
/// score series. Lets the dashboard compute a 30/90-day trend locally instead
/// of firing [habitLogsForDateProvider] per date (the old N+1).
final statsLogsProvider = FutureProvider.family<List<HabitLog>, int>((
  ref,
  days,
) async {
  if (ref.watch(devModeProvider)) {
    return _withDevOverrides(ref, generateMockLogs());
  }
  final session = ref.watch(sessionProvider);
  if (session == null) return const [];
  final since = DateTime.now().subtract(Duration(days: days));
  final sinceStr =
      '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
  final data = await SupabaseService.client
      .from('habit_logs')
      .select()
      .eq('user_id', session.user.id)
      .gte('date', sinceStr);
  return (data as List).map((e) => HabitLog.fromJson(e)).toList();
});

/// All-time *completed* habit logs. Powers cumulative and long-streak
/// achievement stats that the 60-day [recentHabitLogsProvider] window can't
/// see — lifetime totals (100 gym sessions, 1,000 pages) and streaks longer
/// than 60 days (`streak_100`, `streakzilla`, veteran active-day runs).
final lifetimeCompletedLogsProvider = FutureProvider<List<HabitLog>>((
  ref,
) async {
  if (ref.watch(devModeProvider)) {
    return _withDevOverrides(
      ref,
      generateMockLogs(),
    ).where((l) => l.completed).toList();
  }
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final data = await SupabaseService.client
      .from('habit_logs')
      .select()
      .eq('user_id', session.user.id)
      .eq('completed', true);
  return (data as List).map((e) => HabitLog.fromJson(e)).toList();
});

/// All logs for a single habit over the last ~366 days — powers the per-task
/// stats screen. A longer window than the 60-day [recentHabitLogsProvider] but
/// scoped to one habit, so it stays tiny. Ordered oldest → newest.
final habitLogHistoryProvider = FutureProvider.family<List<HabitLog>, String>((
  ref,
  habitId,
) async {
  if (ref.watch(devModeProvider)) {
    return _withDevOverrides(
      ref,
      generateMockLogs(),
    ).where((l) => l.habitId == habitId).toList();
  }
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final since = DateTime.now().subtract(const Duration(days: 366));
  final sinceStr =
      '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
  final data = await SupabaseService.client
      .from('habit_logs')
      .select()
      .eq('user_id', session.user.id)
      .eq('habit_id', habitId)
      .gte('date', sinceStr)
      .order('date');
  return (data as List).map((e) => HabitLog.fromJson(e)).toList();
});

class HabitActionsNotifier extends StateNotifier<AsyncValue<void>> {
  HabitActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Inserts a habit and returns its server-side `id`.
  Future<String> addHabit(Map<String, dynamic> habitData) async {
    state = const AsyncValue.loading();
    try {
      final row = await SupabaseService.client
          .from('habits')
          .insert(habitData)
          .select('id')
          .single();
      _ref.invalidate(habitsProvider);
      // allHabitsProvider backs the detail screen + library; without this a
      // freshly created habit is missing from its cache → "Not found".
      _ref.invalidate(allHabitsProvider);
      state = const AsyncValue.data(null);
      return row['id'] as String;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateHabit(String habitId, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService.client
          .from('habits')
          .update(data)
          .eq('id', habitId);
      _ref.invalidate(habitsProvider);
      // Keep the detail screen + library cache in sync with the edit.
      _ref.invalidate(allHabitsProvider);
    });
  }

  Future<void> deleteHabit(String habitId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService.client
          .from('habits')
          .update({'is_archived': true})
          .eq('id', habitId);
      _ref.invalidate(habitsProvider);
      _ref.invalidate(allHabitsProvider);
    });
  }

  Future<void> restoreHabit(String habitId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService.client
          .from('habits')
          .update({'is_archived': false})
          .eq('id', habitId);
      _ref.invalidate(habitsProvider);
      _ref.invalidate(allHabitsProvider);
    });
  }

  /// Permanently removes a habit and all its logs.
  Future<void> hardDeleteHabit(String habitId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService.client
          .from('habit_logs')
          .delete()
          .eq('habit_id', habitId);
      await SupabaseService.client.from('habits').delete().eq('id', habitId);
      _ref.invalidate(habitsProvider);
      _ref.invalidate(allHabitsProvider);
    });
  }

  /// Persists new sort order. [orderedIds] is the final on-screen order.
  /// The per-row updates are independent, so fire them concurrently — one
  /// round-trip of latency instead of N (the old serial loop).
  Future<void> reorderHabits(List<String> orderedIds) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await Future.wait([
        for (int i = 0; i < orderedIds.length; i++)
          SupabaseService.client
              .from('habits')
              .update({'sort_order': i})
              .eq('id', orderedIds[i]),
      ]);
      _ref.invalidate(habitsProvider);
      _ref.invalidate(allHabitsProvider);
    });
  }

  Future<void> toggleHabit(
    String habitId,
    String date, {
    bool? completed,
    int? effortRating,
    String? note,
    String? triggerTag,
    bool urgeOnly = false,
    // Partial-progress value for numeric goal habits (reps/min/km/L).
    // Null means "don't change actual_value"; pass 0 to explicitly clear.
    double? actualValue,
  }) async {
    // Demo/dev: no session — write to the in-memory override store so the task
    // closes and the score/level recompute (the providers merge these in).
    if (_ref.read(devModeProvider)) {
      final key = '$habitId|$date';
      final ov = {..._ref.read(devLogOverridesProvider)};
      HabitLog? existing = ov[key];
      if (existing == null) {
        for (final l in generateMockLogs()) {
          if (l.habitId == habitId && l.date == date) {
            existing = l;
            break;
          }
        }
      }
      final isCompleted =
          completed ?? (existing != null ? !existing.completed : true);
      ov[key] = HabitLog(
        id: 'dev|$key',
        habitId: habitId,
        userId: 'dev-user-000',
        date: date,
        completed: isCompleted,
        urgeOnly: urgeOnly,
        actualValue: actualValue ?? existing?.actualValue,
        effortRating: effortRating ?? existing?.effortRating,
        // Toggling completion is not a rest — clears any rest mark.
      );
      _ref.read(devLogOverridesProvider.notifier).state = ov;
      _ref.invalidate(habitLogsForDateProvider(date));
      _ref.invalidate(recentHabitLogsProvider);
      return;
    }

    final session = _ref.read(sessionProvider);
    if (session == null) return;

    // HABITS_AUDIT §3.7: this read used to throw outright when offline,
    // losing the completion entirely before the write was even attempted.
    // Fall back to the last-good cache + pending queue ops for this date so
    // a toggle offline still knows the current state to invert.
    Map<String, dynamic>? existing;
    try {
      existing = await SupabaseService.client
          .from('habit_logs')
          .select()
          .eq('habit_id', habitId)
          .eq('date', date)
          .maybeSingle();
    } catch (_) {
      final cached = _mergePendingHabitLogOps(
        _readCachedHabitLogs('byDate:$date'),
        date: date,
      );
      existing = cached.where((r) => r['habit_id'] == habitId).firstOrNull;
    }

    final isCompleted =
        completed ??
        (existing != null ? !(existing['completed'] as bool) : true);

    final payload = <String, dynamic>{
      'habit_id': habitId,
      'user_id': session.user.id,
      'date': date,
      'completed': isCompleted,
      'urge_only': urgeOnly,
      // Completing / toggling a habit is never a rest — clear any rest mark.
      'rest_day': false,
      if (effortRating != null && effortRating > 0)
        'effort_rating': effortRating,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'trigger_tag': ?triggerTag,
      'actual_value': ?actualValue,
    };

    // Upsert on the (habit_id, date) unique constraint (SR-6) rather than
    // branching on the `existing` read above: two rapid taps (or two
    // devices) can both see "no existing row" and both take the insert
    // branch, leaving duplicate log rows that all future reads then have to
    // reconcile with `.any()`. An upsert is atomic at the DB level
    // regardless of what either caller read beforehand. Routed through
    // OfflineWriter (§3.7) so a failed/offline write queues instead of
    // throwing — toggleHabit is the app's highest-frequency write.
    await OfflineWriter.upsert(
      table: 'habit_logs',
      payload: payload,
      onConflict: 'habit_id,date',
    );

    // Auto-log / un-log any linked food for this task on this date.
    await _syncFoodLink(habitId: habitId, date: date, completed: isCompleted);

    // Level XP for v2 is derived entirely from the daily score (see
    // lib/features/xp/leveling_engine.dart). Per-task XP is no longer written
    // to xp_events — the activity feed now shows `contributedPts` directly
    // from the score engine. This keeps per-task feedback perfectly in sync
    // with the day's actual score movement (no drift between toast totals
    // and the level bar).

    _invalidateLogCaches(date, habitId);
  }

  /// Invalidate every habit-log cache a completion/rest touches. The live home
  /// score reads [habitLogsForDateProvider]/[recentHabitLogsProvider], but the
  /// Stats dashboard + contribution heatmap ([statsLogsProvider]), the
  /// achievement engine ([lifetimeCompletedLogsProvider]) and the per-task stats
  /// screen ([habitLogHistoryProvider]) each read their own query — so without
  /// this they show stale data (and achievements never unlock live) until the
  /// app is relaunched.
  void _invalidateLogCaches(String date, String habitId) {
    _ref.invalidate(habitLogsForDateProvider(date));
    _ref.invalidate(recentHabitLogsProvider);
    _ref.invalidate(statsLogsProvider);
    _ref.invalidate(lifetimeCompletedLogsProvider);
    _ref.invalidate(habitLogHistoryProvider(habitId));
  }

  /// Mark (or clear) a deliberate **rest day** for a flexible-count habit on
  /// [date]. A rest is neutral — not completed — so it also clears any linked
  /// food that a prior completion logged.
  Future<void> setRestDay(
    String habitId,
    String date, {
    required bool rest,
  }) async {
    if (_ref.read(devModeProvider)) {
      final key = '$habitId|$date';
      final ov = {..._ref.read(devLogOverridesProvider)};
      ov[key] = HabitLog(
        id: 'dev|$key',
        habitId: habitId,
        userId: 'dev-user-000',
        date: date,
        completed: false,
        urgeOnly: false,
        restDay: rest,
      );
      _ref.read(devLogOverridesProvider.notifier).state = ov;
      _ref.invalidate(habitLogsForDateProvider(date));
      _ref.invalidate(recentHabitLogsProvider);
      return;
    }

    final session = _ref.read(sessionProvider);
    if (session == null) return;

    final payload = <String, dynamic>{
      'habit_id': habitId,
      'user_id': session.user.id,
      'date': date,
      'completed': false,
      'rest_day': rest,
      'actual_value': null,
    };

    // Atomic upsert (SR-6), offline-queued if it fails (§3.7) — see the
    // comment in toggleHabit above.
    await OfflineWriter.upsert(
      table: 'habit_logs',
      payload: payload,
      onConflict: 'habit_id,date',
    );

    // A rest is not a completion — drop any auto-logged food for the day.
    await _syncFoodLink(habitId: habitId, date: date, completed: false);

    _invalidateLogCaches(date, habitId);
  }

  /// Mirror a task's food link into the diary when it's completed (and remove
  /// it when un-completed). Best-effort: a food-log failure never blocks the
  /// habit toggle. Invalidating [diaryEntriesProvider] keeps both the diary and
  /// today's home/nutrition score live (see food_providers.dart:215-223).
  Future<void> _syncFoodLink({
    required String habitId,
    required String date,
    required bool completed,
  }) async {
    if (_ref.read(devModeProvider)) return;
    final habits = _ref.read(habitsProvider).valueOrNull ?? const <Habit>[];
    Habit? habit;
    for (final h in habits) {
      if (h.id == habitId) {
        habit = h;
        break;
      }
    }
    final link = habit?.foodLinkRaw;
    if (link == null) return;

    try {
      final repo = _ref.read(foodRepositoryProvider);
      final d = DateTime.parse(date);
      if (completed) {
        await repo.logHabitLink(habitId: habitId, link: link, date: d);
      } else {
        await repo.removeHabitLink(habitId: habitId, date: d);
      }
      _ref.invalidate(diaryEntriesProvider);
    } catch (e, st) {
      if (kDebugMode) debugPrint('food link sync failed: $e\n$st');
    }
  }
}

final habitActionsProvider =
    StateNotifierProvider<HabitActionsNotifier, AsyncValue<void>>(
      (ref) => HabitActionsNotifier(ref),
    );

int _dayOfWeek(DateTime date) => date.weekday;

List<Habit> habitsForDate(List<Habit> all, DateTime date) {
  final dow = _dayOfWeek(date);
  // `existedOn` keeps a newly-created habit off days before it was created, so
  // it never retroactively counts against past-day stats.
  return all
      .where((h) => h.existedOn(date) && h.daysOfWeek.contains(dow))
      .toList();
}

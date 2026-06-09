import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../core/dev/dev_mode.dart';
import '../../auth/providers/auth_provider.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

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

final habitLogsForDateProvider = FutureProvider.family<List<HabitLog>, String>((ref, date) async {
  if (ref.watch(devModeProvider)) {
    return generateMockLogs().where((l) => l.date == date).toList();
  }
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final data = await SupabaseService.client
      .from('habit_logs')
      .select()
      .eq('user_id', session.user.id)
      .eq('date', date);
  return (data as List).map((e) => HabitLog.fromJson(e)).toList();
});

/// Last 60 days of completed logs — used for streak calculation across all habits.
final recentHabitLogsProvider = FutureProvider<List<HabitLog>>((ref) async {
  if (ref.watch(devModeProvider)) return generateMockLogs();
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final since = DateTime.now().subtract(const Duration(days: 60));
  final sinceStr =
      '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
  final data = await SupabaseService.client
      .from('habit_logs')
      .select()
      .eq('user_id', session.user.id)
      .gte('date', sinceStr);
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
  Future<void> reorderHabits(List<String> orderedIds) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await SupabaseService.client
            .from('habits')
            .update({'sort_order': i})
            .eq('id', orderedIds[i]);
      }
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
    final session = _ref.read(sessionProvider);
    if (session == null) return;

    final existing = await SupabaseService.client
        .from('habit_logs')
        .select()
        .eq('habit_id', habitId)
        .eq('date', date)
        .maybeSingle();

    final isCompleted = completed ?? (existing != null ? !(existing['completed'] as bool) : true);

    final payload = <String, dynamic>{
      'habit_id': habitId,
      'user_id': session.user.id,
      'date': date,
      'completed': isCompleted,
      'urge_only': urgeOnly,
      if (effortRating != null && effortRating > 0) 'effort_rating': effortRating,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (triggerTag != null) 'trigger_tag': triggerTag,
      if (actualValue != null) 'actual_value': actualValue,
    };

    if (existing != null) {
      await SupabaseService.client
          .from('habit_logs')
          .update(payload)
          .eq('id', existing['id'] as String);
    } else {
      await SupabaseService.client.from('habit_logs').insert(payload);
    }

    // Level XP for v2 is derived entirely from the daily score (see
    // lib/features/xp/leveling_engine.dart). Per-task XP is no longer written
    // to xp_events — the activity feed now shows `contributedPts` directly
    // from the score engine. This keeps per-task feedback perfectly in sync
    // with the day's actual score movement (no drift between toast totals
    // and the level bar).

    _ref.invalidate(habitLogsForDateProvider(date));
    _ref.invalidate(recentHabitLogsProvider);
  }
}

final habitActionsProvider =
    StateNotifierProvider<HabitActionsNotifier, AsyncValue<void>>(
  (ref) => HabitActionsNotifier(ref),
);

int _dayOfWeek(DateTime date) => date.weekday;

List<Habit> habitsForDate(List<Habit> all, DateTime date) {
  final dow = _dayOfWeek(date);
  return all.where((h) => h.daysOfWeek.contains(dow)).toList();
}

/// Returns the effective time period for a habit.
/// Uses explicit timePeriod if set; falls back to section as proxy.
TimePeriod effectivePeriod(Habit h) {
  if (h.timePeriod != null) return h.timePeriod!;
  return switch (h.section) {
    HabitSection.athletic => TimePeriod.morning,
    HabitSection.mind => TimePeriod.afternoon,
    HabitSection.body => TimePeriod.evening,
  };
}

/// Groups habits by time period, sorted by scheduledTime within each period.
Map<TimePeriod, List<Habit>> groupByPeriod(List<Habit> habits) {
  final map = <TimePeriod, List<Habit>>{
    TimePeriod.morning: [],
    TimePeriod.afternoon: [],
    TimePeriod.evening: [],
  };
  for (final h in habits) {
    map[effectivePeriod(h)]!.add(h);
  }
  // Sort by scheduledTime within each period
  for (final list in map.values) {
    list.sort((a, b) {
      if (a.scheduledTime == null && b.scheduledTime == null) return 0;
      if (a.scheduledTime == null) return 1;
      if (b.scheduledTime == null) return -1;
      return a.scheduledTime!.compareTo(b.scheduledTime!);
    });
  }
  return map;
}

/// Returns which period is currently active based on the hour.
TimePeriod activePeriodNow() {
  final h = DateTime.now().hour;
  if (h < 12) return TimePeriod.morning;
  if (h < 18) return TimePeriod.afternoon;
  return TimePeriod.evening;
}

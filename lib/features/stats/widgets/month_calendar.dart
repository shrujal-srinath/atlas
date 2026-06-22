import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day_quality.dart';
import '../../../shared/models/models.dart';
import '../../habits/providers/habit_provider.dart';
import 'streak_calendar.dart';

/// The Stats-hub month calendar. A day "wins" when it's a **good day** — no
/// negative-habit slips and ≥85% of scheduled positive/todo habits done (see
/// [computeDayQuality]). Renders through the shared [StreakCalendar], which
/// flips between the streak ribbon and the completion-intensity heatmap.
class MonthCalendarCard extends ConsumerStatefulWidget {
  const MonthCalendarCard({super.key});

  @override
  ConsumerState<MonthCalendarCard> createState() => _MonthCalendarCardState();
}

class _MonthCalendarCardState extends ConsumerState<MonthCalendarCard> {
  late DateTime _month; // first-of-month

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month, 1);
  }

  DateTime get _currentMonth {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  bool get _canNext => _month.isBefore(_currentMonth);
  // The completion data comes from the ~60-day log cache.
  bool get _canPrev =>
      _month.isAfter(DateTime(_currentMonth.year, _currentMonth.month - 2, 1));

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final logs = ref.watch(recentHabitLogsProvider).valueOrNull ?? const <HabitLog>[];

    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    // Win/rest/miss state over the cache window → streak math.
    final byState = <DateTime, bool?>{};
    for (int i = 0; i < 70; i++) {
      final d = today.subtract(Duration(days: i));
      final key = DateTime(d.year, d.month, d.day);
      final q = computeDayQuality(habits, logs, d);
      byState[key] = q.isRestDay ? null : q.isGoodDay;
    }
    final streak = streakSummary(byState, today: today);
    final runs = streakRuns(byState, today: today);

    // This month's cells.
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final byDay = <int, CalendarDay>{};
    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(_month.year, _month.month, day);
      final key = DateTime(d.year, d.month, d.day);
      final q = computeDayQuality(habits, logs, d);
      byDay[day] = CalendarDay(
        date: d,
        scheduled: !q.isRestDay,
        win: q.isGoodDay,
        rate: q.rate,
        inCurrentRun: runs.current.contains(key),
        runLength: runs.runLength[key] ?? 0,
      );
    }

    return StreakCalendar(
      title: 'THE MONTH',
      month: _month,
      byDay: byDay,
      current: streak.current,
      best: streak.best,
      accent: c.accent,
      canPrev: _canPrev,
      canNext: _canNext,
      onPage: _shift,
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/utils/day_quality.dart';
import '../../../shared/models/models.dart';
import '../../stats/widgets/streak_calendar.dart';

/// Per-task month calendar. A day "wins" when the task was completed that day;
/// goal-bearing tasks keep a proportional [CalendarDay.rate] for the intensity
/// shading. Renders through the shared [StreakCalendar] (streak ribbon ⇄
/// intensity heatmap), themed to the habit's [accent].
class HabitMonthHeatmap extends StatefulWidget {
  final Habit habit;
  final List<HabitLog> logs;
  final Color accent;
  const HabitMonthHeatmap({
    super.key,
    required this.habit,
    required this.logs,
    required this.accent,
  });

  @override
  State<HabitMonthHeatmap> createState() => _HabitMonthHeatmapState();
}

class _HabitMonthHeatmapState extends State<HabitMonthHeatmap> {
  late DateTime _month;

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
  bool get _canPrev =>
      _month.isAfter(DateTime(_currentMonth.year, _currentMonth.month - 11, 1));

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  static String _ds(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _scheduled(DateTime d) => widget.habit.daysOfWeek.contains(d.weekday);

  @override
  Widget build(BuildContext context) {
    final completed = <String, HabitLog>{
      for (final l in widget.logs)
        if (l.completed) l.date: l,
    };
    final goal = widget.habit.goalValue ?? 0;
    final useGoal = widget.habit.goalType != null && goal > 0;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    double rateFor(HabitLog? log) {
      if (log == null) return 0;
      if (useGoal) {
        return log.actualValue != null
            ? (log.actualValue! / goal).clamp(0.0, 1.0)
            : 1.0;
      }
      return 1.0;
    }

    // Streak state over the fetched window.
    final byState = <DateTime, bool?>{};
    for (int i = 0; i < 366; i++) {
      final d = today.subtract(Duration(days: i));
      final key = DateTime(d.year, d.month, d.day);
      if (!_scheduled(d)) {
        byState[key] = null;
      } else {
        byState[key] = completed.containsKey(_ds(d));
      }
    }
    final streak = streakSummary(byState, today: today);
    final runs = streakRuns(byState, today: today);

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final byDay = <int, CalendarDay>{};
    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(_month.year, _month.month, day);
      final key = DateTime(d.year, d.month, d.day);
      final scheduled = _scheduled(d) && !d.isAfter(today);
      final log = completed[_ds(d)];
      byDay[day] = CalendarDay(
        date: d,
        scheduled: scheduled,
        win: scheduled && log != null,
        rate: scheduled ? rateFor(log) : 0,
        inCurrentRun: runs.current.contains(key),
        runLength: runs.runLength[key] ?? 0,
      );
    }

    return StreakCalendar(
      title: 'CALENDAR',
      month: _month,
      byDay: byDay,
      current: streak.current,
      best: streak.best,
      accent: widget.accent,
      canPrev: _canPrev,
      canNext: _canNext,
      onPage: _shift,
    );
  }
}

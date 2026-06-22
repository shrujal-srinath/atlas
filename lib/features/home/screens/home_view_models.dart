part of 'home_screen.dart';

class _DayVM {
  final String d;
  final int n;
  final int score;
  final int done;
  final int total;
  final Map<String, int> cats; // ATH / MIND / BODY
  const _DayVM({
    required this.d,
    required this.n,
    required this.score,
    required this.done,
    required this.total,
    required this.cats,
  });
}

class _TaskVM {
  final String id;
  final String period;
  final String name;
  final String time;
  final String cat;
  final String type;
  final int? duration;
  final double? target;
  final double? current;
  final int streak;
  final bool done;
  final IconData icon;
  final HabitPriority priority;
  /// Underlying habit (null for the seed mock data).
  final Habit? habitRef;
  final HabitLog? logRef;
  /// Numeric-goal unit label ('reps', 'min', 'km', 'L') — used for the
  /// "12 / 20 reps · 60%" sub-line on numeric task cards.
  final String? unitLabel;
  const _TaskVM({
    required this.id,
    required this.period,
    required this.name,
    required this.time,
    required this.cat,
    required this.type,
    this.duration,
    this.target,
    this.current,
    this.streak = 0,
    this.done = false,
    required this.icon,
    this.priority = HabitPriority.normal,
    this.habitRef,
    this.logRef,
    this.unitLabel,
  });

  /// Completion ratio in `[0, 1.1]`. 0 if numeric and no target, 1 if done.
  double get ratio {
    if (target != null && target! > 0 && current != null) {
      final r = current! / target!;
      if (r >= 1.10) return 1.10;
      if (r < 0) return 0;
      return r;
    }
    return done ? 1.0 : 0.0;
  }

  bool get isNumeric => target != null && target! > 0;
}

const _kPeriods = ['MORNING', 'AFTERNOON', 'EVENING', 'NIGHT'];

Color _catColor(BuildContext context, String key) {
  final c = context.c;
  return switch (key) {
    'ATH' => c.athletic,
    'MIND' => c.mind,
    'BODY' => c.body,
    _ => c.textMuted,
  };
}

/// Icon for the high/critical priority marker on a task card. Returns null for
/// low/normal — we deliberately hide the indicator there to keep the card calm.
IconData? _priorityIcon(HabitPriority p) => switch (p) {
      HabitPriority.high => LucideIcons.chevronsUp,
      HabitPriority.critical => LucideIcons.alertTriangle,
      _ => null,
    };

Color _priorityColor(BuildContext context, HabitPriority p) {
  final c = context.c;
  return switch (p) {
    HabitPriority.high => c.amber,
    HabitPriority.critical => c.negative,
    _ => c.textMuted,
  };
}

String _catKeyFor(HabitSection s) => switch (s) {
      HabitSection.athletic => 'ATH',
      HabitSection.mind => 'MIND',
      HabitSection.body => 'BODY',
    };

_DayVM _weekDayToMock(HomeWeekDay d) => _DayVM(
      d: d.dowLabel,
      n: d.dayNum,
      score: d.score,
      done: d.done,
      total: d.total,
      cats: {
        'ATH': d.sectionPct[HabitSection.athletic] ?? 0,
        'MIND': d.sectionPct[HabitSection.mind] ?? 0,
        'BODY': d.sectionPct[HabitSection.body] ?? 0,
      },
    );

/// Zeroed 7-day window with *correct* dates, shown only while
/// [homeWeekProvider] is still loading. Mirrors the provider's −3..+3 window
/// so the layout doesn't thrash — but never renders fabricated scores.
List<_DayVM> _placeholderWeek(DateTime anchor) {
  final base = DateTime(anchor.year, anchor.month, anchor.day);
  return [for (int i = -3; i <= 3; i++) _zeroDay(base.add(Duration(days: i)))];
}

_DayVM _zeroDay(DateTime d) => _DayVM(
      d: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][(d.weekday - 1).clamp(0, 6)],
      n: d.day,
      score: 0,
      done: 0,
      total: 0,
      cats: const {'ATH': 0, 'MIND': 0, 'BODY': 0},
    );

_TaskVM _homeTaskToMock(HomeTask t) {
  final h = t.habit;
  final type = switch (h.goalType) {
    GoalType.reps => 'reps',
    GoalType.durationMin => 'timer',
    _ => 'check',
  };
  // Numeric tasks expose the live actual_value so the card can show "12 / 20".
  final isNumeric = h.goalType != null && (h.goalValue ?? 0) > 0;
  return _TaskVM(
    id: h.id,
    period: t.period,
    name: h.name,
    time: t.time,
    cat: _catKeyFor(h.section),
    type: type,
    duration: h.goalType == GoalType.durationMin ? h.goalValue?.toInt() : null,
    target: isNumeric ? h.goalValue : null,
    current: isNumeric ? (t.log?.actualValue ?? (t.isCompleted ? h.goalValue : 0)) : null,
    streak: t.streak,
    done: t.isCompleted,
    icon: habitIcon(h.icon),
    priority: h.priority,
    habitRef: h,
    logRef: t.log,
    unitLabel: h.goalType == null ? null : _unitLabelFor(h.goalType!),
  );
}

String _unitLabelFor(GoalType t) => switch (t) {
      GoalType.reps => 'reps',
      GoalType.durationMin => 'min',
      GoalType.distanceKm => 'km',
      GoalType.litres => 'L',
      GoalType.custom => '',
    };

String _catName(String key) => switch (key) {
      'ATH' => 'Athletic',
      'MIND' => 'Mind',
      'BODY' => 'Body',
      _ => '',
    };

IconData _periodIcon(String p) => switch (p) {
      'MORNING' => LucideIcons.sunrise,
      'AFTERNOON' => LucideIcons.sun,
      _ => LucideIcons.moon,
    };

String _greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Still up';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 21) return 'Good evening';
  return 'Good night';
}

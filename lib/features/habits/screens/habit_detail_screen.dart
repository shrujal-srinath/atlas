import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_controls.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/streak_engine.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/notification_service.dart';
import '../../food/domain/meal_entry.dart'; // MealTimeSlotX.label
import '../models/habit_food_link.dart';
import '../providers/habit_provider.dart';

/// Per-habit detail: stats, schedule summary, edit/archive/delete actions.
class HabitDetailScreen extends ConsumerWidget {
  final String habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final habitsAsync = ref.watch(allHabitsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Habit', style: t.h2),
      ),
      body: habitsAsync.when(
        data: (habits) {
          final habit = habits.where((h) => h.id == habitId).firstOrNull;
          if (habit == null) {
            return Center(
              child: Text('Not found',
                  style: t.body.copyWith(color: c.textMuted)),
            );
          }
          return _Body(habit: habit);
        },
        loading: () => Center(
            child: CircularProgressIndicator(color: c.accent, strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text(friendlyError(e),
              style: TextStyle(color: c.negative, fontSize: 13)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final Habit habit;
  const _Body({required this.habit});

  Color _accent(BuildContext context) {
    if (habit.colorKey != null && kHabitColorSwatch[habit.colorKey] != null) {
      return Color(kHabitColorSwatch[habit.colorKey]!);
    }
    return habit.section.color(context.c);
  }

  ({int current, int best, double rate30d, double trendDelta, double health})
      _stats(List<HabitLog> recent) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    // Current streak
    final current = calculateStreak(habit, recent);

    // Walk back 365 days to compute best streak.
    int best = current;
    int run = 0;
    for (int i = 0; i < 365; i++) {
      final day = start.subtract(Duration(days: i));
      if (!habit.daysOfWeek.contains(day.weekday)) continue;
      final ds = _fmt(day);
      final hit = recent
          .any((l) => l.habitId == habit.id && l.date == ds && l.completed);
      if (hit) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }

    // 30d rate (only counts scheduled days in window).
    int sched30 = 0, done30 = 0;
    for (int i = 0; i < 30; i++) {
      final day = start.subtract(Duration(days: i));
      if (!habit.daysOfWeek.contains(day.weekday)) continue;
      sched30++;
      final ds = _fmt(day);
      if (recent.any((l) =>
          l.habitId == habit.id && l.date == ds && l.completed)) {
        done30++;
      }
    }
    final rate30d = sched30 == 0 ? 0.0 : done30 / sched30;

    // Trend: rate last 7 vs prior 7.
    double rateWindow(int from, int to) {
      int s = 0, d = 0;
      for (int i = from; i < to; i++) {
        final day = start.subtract(Duration(days: i));
        if (!habit.daysOfWeek.contains(day.weekday)) continue;
        s++;
        final ds = _fmt(day);
        if (recent.any((l) =>
            l.habitId == habit.id && l.date == ds && l.completed)) {
          d++;
        }
      }
      return s == 0 ? 0.0 : d / s;
    }

    final r0 = rateWindow(0, 7);
    final r1 = rateWindow(7, 14);
    final trendDelta = r0 - r1;

    // Health = 50% recent rate + 30% streak/best + 20% trend.
    final streakComp = best == 0 ? 0.0 : current / best;
    final trendComp = ((trendDelta + 1) / 2).clamp(0.0, 1.0);
    final health = (0.5 * rate30d + 0.3 * streakComp + 0.2 * trendComp) * 100;

    return (
      current: current,
      best: best,
      rate30d: rate30d * 100,
      trendDelta: trendDelta * 100,
      health: health,
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final accent = _accent(context);
    final recent = ref.watch(recentHabitLogsProvider).valueOrNull ?? const [];
    final s = _stats(recent);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screenH, 12, AppSpace.screenH, 32),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 9,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Icon(habitIcon(habit.icon), size: 24, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name, style: t.h2),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TypePill(type: habit.type, color: accent),
                        const SizedBox(width: 6),
                        if (!habit.isArchived)
                          Text(
                            habit.section.name[0].toUpperCase() +
                                habit.section.name.substring(1),
                            style: t.meta,
                          )
                        else
                          Text('Archived',
                              style: t.meta.copyWith(color: c.amber)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats grid (Current / Best / 30d rate)
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'CURRENT',
                value: '${s.current}',
                suffix: 'days',
                icon: LucideIcons.flame,
                color: c.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'BEST',
                value: '${s.best}',
                suffix: 'days',
                icon: LucideIcons.trophy,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: '30D RATE',
                value: '${s.rate30d.round()}',
                suffix: '%',
                icon: LucideIcons.activity,
                color: c.positive,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Deep-dive into this task's history (week/month/year, charts, calendar).
        AtlasButton(
          label: 'Full stats',
          icon: LucideIcons.barChart2,
          variant: AtlasButtonVariant.secondary,
          height: 50,
          onPressed: () => context.push('/habit/${habit.id}/stats'),
        ),
        const SizedBox(height: 16),

        // 7-day mini heatmap
        _SevenDayHeatmap(habit: habit, recent: recent, accent: accent),
        const SizedBox(height: 16),

        // Health score card
        _HealthCard(
          score: s.health,
          trend: s.trendDelta,
          accent: accent,
        ),
        const SizedBox(height: 16),

        // Schedule summary
        _InfoCard(rows: _scheduleRows(context)),
        const SizedBox(height: 12),

        // Reminder summary
        if (habit.reminderEnabled && habit.reminderTime != null)
          _InfoCard(rows: [
            (
              icon: LucideIcons.bell,
              label: 'Reminder',
              value: 'Daily · ${habit.reminderTime}',
            ),
          ]),

        // Food link summary — what completing this auto-logs.
        if (HabitFoodLink.fromRaw(habit.foodLinkRaw) case final link?) ...[
          const SizedBox(height: 12),
          _FoodLinkCard(link: link, accent: accent),
        ],

        const SizedBox(height: 20),

        // Actions
        Row(
          children: [
            Expanded(
              child: AtlasButton(
                label: 'Edit',
                icon: LucideIcons.pencil,
                variant: AtlasButtonVariant.secondary,
                height: 50,
                onPressed: () => context.push('/habit-creation', extra: habit),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AtlasButton(
                label: habit.isArchived ? 'Restore' : 'Archive',
                icon: habit.isArchived
                    ? LucideIcons.refreshCw
                    : LucideIcons.archive,
                variant: AtlasButtonVariant.tonal,
                color: c.amber,
                height: 50,
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  if (habit.isArchived) {
                    await ref
                        .read(habitActionsProvider.notifier)
                        .restoreHabit(habit.id);
                  } else {
                    await ref
                        .read(habitActionsProvider.notifier)
                        .deleteHabit(habit.id);
                    await NotificationService.instance.cancelHabit(habit.id);
                  }
                  if (context.mounted) context.pop();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _confirmHardDelete(context, ref),
          icon: Icon(LucideIcons.trash2, size: 14, color: c.negative),
          label: Text(
            'Delete permanently',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.negative,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmHardDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cc = ctx.c;
        final tt = ctx.t;
        return AlertDialog(
          backgroundColor: cc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            side: BorderSide(color: cc.border),
          ),
          title: Text('Delete forever?', style: tt.h2),
          content: Text(
            'All history for this habit will be erased. This cannot be undone.',
            style: tt.body.copyWith(color: cc.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Delete',
                style:
                    TextStyle(color: cc.negative, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await ref
          .read(habitActionsProvider.notifier)
          .hardDeleteHabit(habit.id);
      await NotificationService.instance.cancelHabit(habit.id);
      if (context.mounted) context.pop();
    }
  }

  List<({IconData icon, String label, String value})> _scheduleRows(
      BuildContext context) {
    final rows = <({IconData icon, String label, String value})>[];
    final freq = switch (habit.frequencyMode) {
      FrequencyMode.everyDay => 'Every day',
      FrequencyMode.specificDays =>
        habit.daysOfWeek.map(_dayLabel).join(' · '),
      FrequencyMode.timesPerWeek => '${habit.timesPerWeek ?? "?"} × / week',
    };
    rows.add((
      icon: LucideIcons.calendarDays,
      label: 'Repeat',
      value: freq,
    ));
    if (habit.timePeriod != null) {
      rows.add((
        icon: LucideIcons.clock,
        label: 'Time',
        value: habit.timePeriod!.name[0].toUpperCase() +
            habit.timePeriod!.name.substring(1) +
            (habit.scheduledTime != null ? ' · ${habit.scheduledTime}' : ''),
      ));
    }
    if (habit.goalType != null && habit.goalValue != null) {
      rows.add((
        icon: LucideIcons.target,
        label: 'Goal',
        value:
            '${habit.goalValue!.toStringAsFixed(0)} ${_goalUnit(habit.goalType!)}',
      ));
    }
    if (habit.skillCategory != null) {
      rows.add((
        icon: LucideIcons.bookOpen,
        label: 'Skill',
        value: habit.skillCategory!,
      ));
    }
    if (habit.endMode != EndMode.off) {
      final endLabel = switch (habit.endMode) {
        EndMode.date => habit.endDate == null
            ? 'On date'
            : 'On ${_fmt(habit.endDate!)}',
        EndMode.afterDays => 'After ${habit.endAfterDays ?? "?"} days',
        EndMode.off => 'Off',
      };
      rows.add((icon: LucideIcons.flag, label: 'Ends', value: endLabel));
    }
    return rows;
  }

  String _dayLabel(int d) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d];

  String _goalUnit(GoalType g) => switch (g) {
        GoalType.reps => 'reps',
        GoalType.durationMin => 'min',
        GoalType.distanceKm => 'km',
        GoalType.litres => 'L',
        GoalType.custom => 'units',
      };
}

/// Compact 7-day heatmap. Renders 7 day columns (Mon-aligned, oldest left)
/// each showing a dot: filled = completed, hollow = scheduled but not, blank
/// = not scheduled.
class _SevenDayHeatmap extends StatelessWidget {
  final Habit habit;
  final List<HabitLog> recent;
  final Color accent;
  const _SevenDayHeatmap({
    required this.habit,
    required this.recent,
    required this.accent,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const dows = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Build 7 columns, oldest first (today - 6 .. today).
    final cells = <(DateTime, bool, bool, bool)>[]; // date, scheduled, done, isToday
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final scheduled = habit.daysOfWeek.contains(d.weekday);
      final ds = _fmt(d);
      final done = recent.any((l) =>
          l.habitId == habit.id && l.date == ds && l.completed);
      cells.add((d, scheduled, done, i == 0));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: c.textMuted,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final cell in cells) ...[
                Expanded(
                  child: Column(
                    children: [
                      _HeatCell(
                        scheduled: cell.$2,
                        done: cell.$3,
                        accent: accent,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dows[(cell.$1.weekday - 1).clamp(0, 6)],
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: cell.$4
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: cell.$4 ? c.accent : c.textMuted,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  final bool scheduled;
  final bool done;
  final Color accent;
  const _HeatCell({
    required this.scheduled,
    required this.done,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Color bg;
    Color border;
    if (!scheduled) {
      bg = c.surfaceElevated;
      border = c.border;
    } else if (done) {
      bg = accent.withValues(alpha: 0.65);
      border = accent;
    } else {
      bg = c.surface;
      border = c.borderStrong;
    }
    return Container(
      width: double.infinity,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.8),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final HabitType type;
  final Color color;
  const _TypePill({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      HabitType.positive => 'REGULAR',
      HabitType.negative => 'BREAK',
      HabitType.todo => 'TODO',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              Text(suffix,
                  style: t.meta.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: t.label.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final double score;
  final double trend;
  final Color accent;
  const _HealthCard({
    required this.score,
    required this.trend,
    required this.accent,
  });

  Color _band(BuildContext context) {
    final c = context.c;
    if (score >= 70) return c.positive;
    if (score >= 40) return c.amber;
    return c.negative;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final band = _band(context);
    final pct = (score / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('HABIT HEALTH', style: t.label),
              const Spacer(),
              Icon(
                trend >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                size: 14,
                color: trend >= 0 ? c.positive : c.negative,
              ),
              const SizedBox(width: 4),
              Text(
                '${trend >= 0 ? '+' : ''}${trend.round()}% vs last week',
                style: t.meta.copyWith(
                  color: trend >= 0 ? c.positive : c.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.round()}',
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(' / 100', style: t.meta),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: c.borderStrong.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(band),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary of the foods a task auto-logs when completed.
class _FoodLinkCard extends StatelessWidget {
  final HabitFoodLink link;
  final Color accent;
  const _FoodLinkCard({required this.link, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.utensils, size: 14, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Auto-logs to ${link.slot.label}',
                  style: t.body.copyWith(color: c.textSecondary),
                ),
              ),
              Text('${link.totalKcal.round()} kcal', style: t.bodyStrong),
            ],
          ),
          for (final item in link.items) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    item.name,
                    style: t.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.portionLabel} · ${item.totals.kcal.round()} kcal',
                  style: t.meta.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<({IconData icon, String label, String value})> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(rows[i].icon, size: 14, color: c.textMuted),
                  const SizedBox(width: 10),
                  Text(rows[i].label,
                      style: t.body.copyWith(color: c.textSecondary)),
                  const Spacer(),
                  Text(rows[i].value, style: t.bodyStrong),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/task_stats.dart';
import '../../../shared/models/models.dart';
import '../../home/scoring/section_def.dart';
import '../../habits/providers/habit_provider.dart';
import 'stats_primitives.dart';

/// PER-HABIT — the single, browsable board of every recurring habit: streak,
/// 30-day completion rate and a trend sparkline in one row, ranked by streak.
/// Merges the old "active streaks" and "per-task" lists into one canonical
/// place. Caps at [_kInitial] rows with a "Show all" expander so a big library
/// never overwhelms. Tapping a row opens that habit's full analytics.
class StatsPerTask extends ConsumerStatefulWidget {
  const StatsPerTask({super.key});

  @override
  ConsumerState<StatsPerTask> createState() => _StatsPerTaskState();
}

class _StatsPerTaskState extends ConsumerState<StatsPerTask> {
  static const _kInitial = 6;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final habits = ref.watch(habitsProvider).valueOrNull ?? const [];
    final logs = ref.watch(recentHabitLogsProvider).valueOrNull ?? const [];

    final active =
        habits.where((h) => !h.isArchived && h.type != HabitType.todo).toList();
    if (active.isEmpty) {
      return StatsCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Add a recurring habit to track its performance here.',
              style: AppType.meta.copyWith(color: c.textMuted)),
        ),
      );
    }

    final all = [
      for (final h in active)
        (
          h,
          computeTaskStats(
            habit: h,
            logs: logs.where((l) => l.habitId == h.id).toList(),
            range: StatRange.month,
          ),
        ),
    ]..sort((a, b) {
        final s = b.$2.currentStreak.compareTo(a.$2.currentStreak);
        return s != 0 ? s : b.$2.completionRate.compareTo(a.$2.completionRate);
      });

    final capped = _showAll || all.length <= _kInitial;
    final rows = capped ? all : all.sublist(0, _kInitial);

    return StatsCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _TaskRow(habit: rows[i].$1, stats: rows[i].$2),
            if (i < rows.length - 1)
              Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 56,
                  color: c.border.withValues(alpha: 0.5)),
          ],
          if (all.length > _kInitial) ...[
            Divider(
                height: 1,
                thickness: 0.5,
                color: c.border.withValues(alpha: 0.5)),
            InkWell(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_showAll ? 'Show less' : 'Show all ${all.length} habits',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.accent)),
                    const SizedBox(width: 4),
                    Icon(_showAll ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 16, color: c.accent),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Habit habit;
  final TaskStats stats;
  const _TaskRow({required this.habit, required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = habit.sectionId.sectionColor(c);
    final rate = (stats.completionRate * 100).round();
    final spark = [for (final b in stats.rateTrend) b.rate];

    return PressableScale(
      onTap: () => context.push('/habit/${habit.id}/stats'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Center(child: Icon(habitIcon(habit.icon), size: 17, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text('30-day · $rate%',
                      style: AppType.meta.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              child: Sparkline(
                points: spark,
                color: color,
                height: 24,
                fill: false,
                showDot: false,
                minY: 0,
                maxY: 1,
              ),
            ),
            const SizedBox(width: 10),
            if (stats.currentStreak > 0) ...[
              Icon(LucideIcons.flame, size: 12, color: c.amber),
              const SizedBox(width: 2),
              Text('${stats.currentStreak}',
                  style: AppType.numMd.copyWith(color: c.amber, fontSize: 13)),
              const SizedBox(width: 6),
            ],
            Icon(LucideIcons.chevronRight, size: 15, color: c.textDim),
          ],
        ),
      ),
    );
  }
}

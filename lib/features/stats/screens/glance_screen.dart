import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../habits/providers/habit_provider.dart';
import '../../home/providers/home_providers.dart';

/// Today at a Glance — heatmap + still-to-do + upcoming reminders.
/// Sketch reference: home master plan §2C.
class GlanceScreen extends ConsumerWidget {
  const GlanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final selDate = ref.watch(selectedDateProvider);
    final tasksAsync = ref.watch(homeTasksProvider(selDate));
    final logsAsync = ref.watch(recentHabitLogsProvider);
    final habitsAsync = ref.watch(habitsProvider);

    final tasks = tasksAsync.valueOrNull ?? const <HomeTask>[];
    final stillTodo = tasks.where((t) => !t.isCompleted).toList();
    final logs = logsAsync.valueOrNull ?? const <HabitLog>[];
    final habits = habitsAsync.valueOrNull ?? const <Habit>[];

    final heatmap = _buildHeatmap(logs, habits);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text('Today at a Glance', style: t.h2),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.calendar, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 12, AppSpace.screenH, 118),
          children: [
            _Section(label: 'CONSISTENCY · 5 WEEKS'),
            const SizedBox(height: 8),
            _ConsistencyCard(heatmap: heatmap),
            const SizedBox(height: 22),
            _Section(label: 'STILL TO DO · ${stillTodo.length} LEFT'),
            const SizedBox(height: 8),
            _StillToDoCard(
              tasks: stillTodo,
              onToggle: (id) async {
                HapticFeedback.lightImpact();
                final dateKey =
                    '${selDate.year}-${selDate.month.toString().padLeft(2, '0')}-${selDate.day.toString().padLeft(2, '0')}';
                await ref
                    .read(habitActionsProvider.notifier)
                    .toggleHabit(id, dateKey);
              },
            ),
            const SizedBox(height: 22),
            _Section(label: 'UPCOMING REMINDERS · NEXT 7 DAYS'),
            const SizedBox(height: 8),
            _UpcomingRemindersCard(habits: habits),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<_HeatCell> _buildHeatmap(List<HabitLog> logs, List<Habit> habits) {
    final byDate = <String, int>{};
    for (final l in logs) {
      if (l.completed) byDate[l.date] = (byDate[l.date] ?? 0) + 1;
    }
    final today = DateTime.now();
    final cells = <_HeatCell>[];
    for (int i = 34; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final count = byDate[key] ?? 0;
      final intensity = habits.isEmpty
          ? 0.0
          : (count / habits.length).clamp(0.0, 1.0);
      cells.add(_HeatCell(date: d, count: count, intensity: intensity));
    }
    return cells;
  }
}

class _HeatCell {
  final DateTime date;
  final int count;
  final double intensity; // 0..1
  const _HeatCell({required this.date, required this.count, required this.intensity});
}

// ────────────────────────────────────────────────────────────────────
// CONSISTENCY
// ────────────────────────────────────────────────────────────────────

class _ConsistencyCard extends StatelessWidget {
  final List<_HeatCell> heatmap;
  const _ConsistencyCard({required this.heatmap});

  int get _completionRate {
    if (heatmap.isEmpty) return 0;
    final any = heatmap.where((c) => c.intensity > 0).length;
    return ((any / heatmap.length) * 100).round();
  }

  int get _currentStreak {
    int s = 0;
    for (int i = heatmap.length - 1; i >= 0; i--) {
      if (heatmap[i].intensity > 0.5) {
        s++;
      } else {
        break;
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_completionRate%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: c.textPrimary,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'completion rate',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.flame, size: 12, color: c.amber),
                    const SizedBox(width: 4),
                    Text(
                      '$_currentStreak-day streak',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.amber,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HeatmapGrid(cells: heatmap),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '5 weeks ago',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: c.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                'less',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: c.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              ...List.generate(4, (i) {
                final alpha = 0.18 + (i * 0.22);
                return Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
              Text(
                'more',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<_HeatCell> cells;
  const _HeatmapGrid({required this.cells});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        childAspectRatio: 1.0,
      ),
      itemCount: cells.length,
      itemBuilder: (_, i) {
        final cell = cells[i];
        final alpha = cell.intensity == 0 ? 0.08 : 0.20 + cell.intensity * 0.80;
        return Container(
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// STILL TO DO
// ────────────────────────────────────────────────────────────────────

class _StillToDoCard extends StatelessWidget {
  final List<HomeTask> tasks;
  final ValueChanged<String> onToggle;
  const _StillToDoCard({required this.tasks, required this.onToggle});

  Color _catColor(BuildContext context, HabitSection s) {
    final c = context.c;
    return switch (s) {
      HabitSection.athletic => c.athletic,
      HabitSection.mind => c.mind,
      HabitSection.body => c.body,
    };
  }

  String _catLabel(HabitSection s) => switch (s) {
        HabitSection.athletic => 'Athletic',
        HabitSection.mind => 'Mind',
        HabitSection.body => 'Body',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(LucideIcons.check, size: 22, color: c.positive),
            const SizedBox(height: 6),
            Text(
              'All done for today',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < tasks.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: c.border, thickness: 0.5, indent: 14, endIndent: 14),
            _StillToDoRow(
              task: tasks[i],
              catColor: _catColor(context, tasks[i].habit.section),
              catLabel: _catLabel(tasks[i].habit.section),
              onTap: () => onToggle(tasks[i].habit.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _StillToDoRow extends StatelessWidget {
  final HomeTask task;
  final Color catColor;
  final String catLabel;
  final VoidCallback onTap;
  const _StillToDoRow({
    required this.task,
    required this.catColor,
    required this.catLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = task.habit;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(habitIcon(h.icon), size: 18, color: catColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (task.time.isNotEmpty) ...[
                      Text(
                        task.time,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      catLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.borderStrong, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// UPCOMING REMINDERS
// ────────────────────────────────────────────────────────────────────

class _UpcomingRemindersCard extends StatelessWidget {
  final List<Habit> habits;
  const _UpcomingRemindersCard({required this.habits});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reminders = habits
        .where((h) => h.reminderEnabled && h.reminderTime != null)
        .toList()
      ..sort((a, b) => (a.reminderTime ?? '').compareTo(b.reminderTime ?? ''));

    if (reminders.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          'No reminders set up',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < reminders.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: c.border, thickness: 0.5, indent: 14, endIndent: 14),
            ListTile(
              dense: true,
              leading: Icon(LucideIcons.bell, size: 18, color: c.textSecondary),
              title: Text(
                reminders[i].name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Text(
                reminders[i].reminderTime ?? '',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: c.textMuted,
          height: 1.0,
        ),
      ),
    );
  }
}

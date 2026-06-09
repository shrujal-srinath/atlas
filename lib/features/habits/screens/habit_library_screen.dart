import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/streak_engine.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/notification_service.dart';
import '../providers/habit_provider.dart';
import '../widgets/habit_type_picker.dart';

/// Library / management screen for every habit a user owns — active and
/// archived. Grouped by section, supports drag-to-reorder, swipe-to-archive,
/// and routes into per-habit detail.
class HabitLibraryScreen extends ConsumerStatefulWidget {
  const HabitLibraryScreen({super.key});

  @override
  ConsumerState<HabitLibraryScreen> createState() => _HabitLibraryScreenState();
}

class _HabitLibraryScreenState extends ConsumerState<HabitLibraryScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final habitsAsync = ref.watch(allHabitsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Habits', style: t.h2),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, size: 20, color: c.accent),
            onPressed: () => showHabitTypePicker(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: habitsAsync.when(
        data: (habits) => _buildBody(context, habits),
        loading: () => Center(
            child: CircularProgressIndicator(color: c.accent, strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: TextStyle(color: c.negative, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Habit> habits) {
    final c = context.c;
    final t = context.t;
    if (habits.isEmpty) {
      return _EmptyState();
    }
    final active = habits.where((h) => !h.isArchived).toList();
    final archived = habits.where((h) => h.isArchived).toList();

    final bySection = <HabitSection, List<Habit>>{
      for (final s in HabitSection.values)
        s: active.where((h) => h.section == s).toList(),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.screenH, 12, AppSpace.screenH, 32),
      children: [
        _LibrarySummary(active: active, archived: archived),
        const SizedBox(height: 18),
        for (final s in HabitSection.values)
          if (bySection[s]!.isNotEmpty) ...[
            _SectionHeader(section: s, count: bySection[s]!.length),
            const SizedBox(height: 8),
            _ReorderableHabitList(habits: bySection[s]!),
            const SizedBox(height: 20),
          ],
        if (archived.isNotEmpty) ...[
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: () => setState(() => _showArchived = !_showArchived),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(LucideIcons.archive, size: 14, color: c.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Archived · ${archived.length}',
                    style: t.label,
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showArchived ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(LucideIcons.chevronDown,
                        size: 18, color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (_showArchived) ...[
            const SizedBox(height: 6),
            for (final h in archived) _ArchivedRow(habit: h),
          ],
        ],
      ],
    );
  }
}

/// BENTO summary card at the top of the library: total habits, active count,
/// and the user's best-running streak across all of them.
class _LibrarySummary extends ConsumerWidget {
  final List<Habit> active;
  final List<Habit> archived;
  const _LibrarySummary({required this.active, required this.archived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final recent = ref.watch(recentHabitLogsProvider).valueOrNull ?? const [];
    int bestStreak = 0;
    for (final h in active) {
      final s = calculateStreak(h, recent);
      if (s > bestStreak) bestStreak = s;
    }
    final total = active.length + archived.length;

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
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              label: 'Habits',
              value: total.toString(),
              accent: c.textPrimary,
            ),
          ),
          _SummaryDivider(),
          Expanded(
            child: _SummaryStat(
              label: 'Active',
              value: active.length.toString(),
              accent: c.accent,
            ),
          ),
          _SummaryDivider(),
          Expanded(
            child: _SummaryStat(
              label: 'Best streak',
              value: '${bestStreak}d',
              accent: bestStreak > 0 ? c.amber : c.textMuted,
              icon: bestStreak > 0 ? LucideIcons.flame : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final IconData? icon;
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: c.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: accent,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 32,
      color: context.c.border,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final HabitSection section;
  final int count;
  const _SectionHeader({required this.section, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final color = switch (section) {
      HabitSection.athletic => c.athletic,
      HabitSection.body => c.body,
      HabitSection.mind => c.mind,
    };
    final label = section.name[0].toUpperCase() + section.name.substring(1);
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label.toUpperCase(),
            style: t.label.copyWith(letterSpacing: 0.8)),
        const SizedBox(width: 8),
        Text('· $count', style: t.meta),
      ],
    );
  }
}

class _ReorderableHabitList extends ConsumerWidget {
  final List<Habit> habits;
  const _ReorderableHabitList({required this.habits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: habits.length,
      itemBuilder: (ctx, i) => _HabitRow(
        key: ValueKey(habits[i].id),
        habit: habits[i],
        index: i,
      ),
      onReorder: (oldIndex, newIndex) async {
        HapticFeedback.mediumImpact();
        if (newIndex > oldIndex) newIndex -= 1;
        final reordered = List<Habit>.of(habits);
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        // Persist on the entire active set in this section.
        await ref
            .read(habitActionsProvider.notifier)
            .reorderHabits(reordered.map((h) => h.id).toList());
      },
      proxyDecorator: (child, _, _) => Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  final Habit habit;
  final int index;
  const _HabitRow({super.key, required this.habit, required this.index});

  Color _accent(BuildContext context) {
    if (habit.colorKey != null && kHabitColorSwatch[habit.colorKey] != null) {
      return Color(kHabitColorSwatch[habit.colorKey]!);
    }
    final c = context.c;
    return switch (habit.section) {
      HabitSection.athletic => c.athletic,
      HabitSection.body => c.body,
      HabitSection.mind => c.mind,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final accent = _accent(context);
    final recent = ref.watch(recentHabitLogsProvider).valueOrNull ?? const [];
    final streak = calculateStreak(habit, recent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('${habit.id}-dismiss'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: c.negative.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(LucideIcons.archive, color: c.negative, size: 16),
              const SizedBox(width: 6),
              Text(
                'Archive',
                style: TextStyle(
                    fontFamily: 'Inter',
                    color: c.negative,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();
          await ref
              .read(habitActionsProvider.notifier)
              .deleteHabit(habit.id);
          await NotificationService.instance.cancelHabit(habit.id);
          return true;
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () => context.push('/habit/${habit.id}'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
              border: Border(
                  left: BorderSide(color: accent, width: 3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Icon(habitIcon(habit.icon),
                      size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.name, style: t.bodyStrong),
                      const SizedBox(height: 2),
                      Text(
                        _summary(habit),
                        style: t.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (streak > 0) ...[
                  Icon(LucideIcons.flame, size: 14, color: c.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${streak}d',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(LucideIcons.gripVertical,
                        size: 16, color: c.textDim),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _summary(Habit h) {
    final parts = <String>[];
    switch (h.frequencyMode) {
      case FrequencyMode.everyDay:
        parts.add('Daily');
        break;
      case FrequencyMode.timesPerWeek:
        parts.add('${h.timesPerWeek ?? "?"}× / wk');
        break;
      case FrequencyMode.specificDays:
        parts.add('${h.daysOfWeek.length} days / wk');
        break;
    }
    if (h.scheduledTime != null) parts.add(h.scheduledTime!);
    if (h.reminderEnabled) parts.add('Reminder on');
    return parts.join(' · ');
  }
}

class _ArchivedRow extends ConsumerWidget {
  final Habit habit;
  const _ArchivedRow({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(habitIcon(habit.icon), size: 16, color: c.textDim),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                habit.name,
                style: t.body.copyWith(color: c.textMuted),
              ),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.selectionClick();
                await ref
                    .read(habitActionsProvider.notifier)
                    .restoreHabit(habit.id);
              },
              child: Text(
                'Restore',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.layoutList, size: 28, color: c.textDim),
            const SizedBox(height: 12),
            Text('No habits yet', style: t.h2),
            const SizedBox(height: 6),
            Text(
              'Tap the + to create your first one.',
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.onAccent,
              ),
              onPressed: () => showHabitTypePicker(context),
              child: const Text(
                'Create a habit',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

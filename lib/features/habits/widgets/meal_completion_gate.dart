import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/today_provider.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../food/domain/meal_entry.dart';
import '../../food/providers/food_providers.dart';
import '../../food/screens/food_search_sheet.dart';
import '../../food/screens/quick_add_sheet.dart';
import '../../food/widgets/log_confirmation_toast.dart';
import '../models/habit_food_link.dart';
import '../providers/habit_provider.dart';

/// Parses [habit]'s food link and returns the meal slot only when it's a
/// **Flexible** meal (no preset foods — completing it opens the decision
/// gate below instead of auto-logging anything).
MealTimeSlot? flexibleMealSlotOf(Habit habit) {
  final link = HabitFoodLink.fromRaw(habit.foodLinkRaw);
  return (link != null && link.isFlexible) ? link.slot : null;
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// True when [habit] is a Flexible meal, completed today, with nothing
/// logged yet in its slot — the "you marked this done but haven't logged
/// calories" state. Deliberately **not** tied to any tagging: however the
/// user eventually resolves it (Enter calories, Log food, or logging
/// something in that slot completely independently later), this clears on
/// its own with zero new schema.
bool isMealHabitPending(
  Habit habit,
  HabitLog? todayLog,
  List<MealEntry> todayEntries,
) {
  if (todayLog?.completed != true) return false;
  final slot = flexibleMealSlotOf(habit);
  if (slot == null) return false;
  return !todayEntries.any((e) => e.slot == slot);
}

/// Every Flexible meal habit that's completed today with no calories logged
/// yet. Powers both the day-rail badge and the fuel-card pending section —
/// one source, no duplicate queries.
///
/// Lives here rather than food_providers.dart because it needs both
/// habitsProvider/habitLogsForDateProvider (habits) and todayEntriesProvider
/// (food); habit_provider.dart already imports food_providers.dart, so the
/// reverse import would cycle (same reasoning as
/// shared/providers/today_provider.dart's rollover bootstrap).
final pendingMealHabitsProvider = Provider.autoDispose<List<Habit>>((ref) {
  final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
  if (habits.isEmpty) return const [];
  final todayKey = _dateKey(ref.watch(todayDateProvider));
  final logs = ref.watch(habitLogsForDateProvider(todayKey)).valueOrNull ??
      const <HabitLog>[];
  final entries =
      ref.watch(todayEntriesProvider).valueOrNull ?? const <MealEntry>[];
  final logByHabit = {for (final l in logs) l.habitId: l};
  return habits
      .where((h) => isMealHabitPending(h, logByHabit[h.id], entries))
      .toList();
});

/// The one function every completion call site uses **instead of** calling
/// `toggleHabit` directly. If [habit] is a Flexible meal and this is a
/// genuine new completion for *today* (not un-completing, not backfilling a
/// past date — attributing today's food to a different day's habit-log
/// would be wrong), shows the decision gate first. Whichever choice is
/// made, completion then proceeds exactly as `toggleHabit` always has —
/// "did you eat" and "what did you eat" are independent questions.
///
/// [habit] is nullable so dev-mode call sites (mock `_TaskVM.habitRef`) can
/// pass null to skip the gate entirely and fall straight through to
/// `toggleHabit`, same guard `_syncFoodLink` already uses.
Future<void> completeHabitGated(
  BuildContext context,
  WidgetRef ref,
  String habitId,
  String dateStr, {
  Habit? habit,
  required bool wasCompleted,
  bool? completed,
  int? effortRating,
  String? note,
  String? triggerTag,
  bool urgeOnly = false,
  double? actualValue,
}) async {
  final targetCompleted = completed ?? !wasCompleted;
  // The mounted-check only guards *showing the sheet* (a disposed context
  // can't present UI) — it must never skip the toggleHabit call below, or a
  // fire-and-forget completion from dispose() (see _ExpandedRowState._persist)
  // would silently drop the write instead of just skipping the popup.
  if (habit != null && targetCompleted && !wasCompleted && context.mounted) {
    final slot = flexibleMealSlotOf(habit);
    final today = ref.read(todayDateProvider);
    if (slot != null && dateStr == _dateKey(today)) {
      await showMealCompletionGateSheet(
        context,
        ref,
        habit: habit,
        slot: slot,
        date: today,
      );
    }
  }
  await ref.read(habitActionsProvider.notifier).toggleHabit(
        habitId,
        dateStr,
        completed: completed,
        effortRating: effortRating,
        note: note,
        triggerTag: triggerTag,
        urgeOnly: urgeOnly,
        actualValue: actualValue,
      );
}

enum _GateMode { completing, resolving }

/// Shown from `completeHabitGated` at the moment of completion — 3 choices
/// (Enter calories / Log food / Skip).
Future<void> showMealCompletionGateSheet(
  BuildContext context,
  WidgetRef ref, {
  required Habit habit,
  required MealTimeSlot slot,
  required DateTime date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MealDecisionSheet(
      habit: habit,
      slot: slot,
      date: date,
      mode: _GateMode.completing,
    ),
  );
}

/// Shown from the day-rail pending badge / fuel-card pending section to
/// resolve an *already-completed* Flexible meal's missing calories — same
/// two logging choices, no "Skip" (nothing to skip, it's already done), and
/// never touches the habit's completion state.
Future<void> showMealResolveSheet(
  BuildContext context,
  WidgetRef ref, {
  required Habit habit,
  required MealTimeSlot slot,
  required DateTime date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MealDecisionSheet(
      habit: habit,
      slot: slot,
      date: date,
      mode: _GateMode.resolving,
    ),
  );
}

class _MealDecisionSheet extends ConsumerWidget {
  final Habit habit;
  final MealTimeSlot slot;
  final DateTime date;
  final _GateMode mode;
  const _MealDecisionSheet({
    required this.habit,
    required this.slot,
    required this.date,
    required this.mode,
  });

  Future<void> _enterCalories(BuildContext context, WidgetRef ref) async {
    final entry = await showModalBottomSheet<MealEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) =>
          QuickAddSheet(date: date, initialSlot: slot, lockSlot: true),
    );
    if (!context.mounted) return;
    ref.invalidate(diaryEntriesProvider);
    ref.invalidate(pendingMealHabitsProvider);
    if (entry != null) Navigator.of(context).pop();
  }

  Future<void> _logFood(BuildContext context, WidgetRef ref) async {
    final logged = await showModalBottomSheet<MealEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.c.background,
      builder: (_) => FoodSearchSheet(slot: slot, date: date),
    );
    if (!context.mounted) return;
    ref.invalidate(diaryEntriesProvider);
    ref.invalidate(pendingMealHabitsProvider);
    if (logged != null) {
      LogConfirmationToast.show(context, logged.totals, slotLabel: slot.label);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final completing = mode == _GateMode.completing;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.screenH,
        16,
        AppSpace.screenH,
        MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            completing ? habit.name : 'Add calories for ${habit.name}',
            style: t.h2,
          ),
          const SizedBox(height: 4),
          Text(
            completing
                ? 'How do you want to log ${slot.label.toLowerCase()}?'
                : "You marked this done but haven't logged calories yet.",
            style: t.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 18),
          _GateTile(
            icon: LucideIcons.flame,
            label: 'Enter calories',
            sub: 'Quick number, no food search',
            onTap: () => _enterCalories(context, ref),
          ),
          const SizedBox(height: 10),
          _GateTile(
            icon: LucideIcons.search,
            label: 'Log food',
            sub: 'Search and log what you actually ate',
            onTap: () => _logFood(context, ref),
          ),
          if (completing) ...[
            const SizedBox(height: 10),
            _GateTile(
              icon: LucideIcons.clock,
              label: 'Skip for now',
              sub: "Add calories later — won't affect your streak",
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }
}

class _GateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _GateTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.body.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sub, style: t.meta.copyWith(color: c.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

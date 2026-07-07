import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../data/meal_bundle_repository.dart';
import '../domain/food.dart';
import '../domain/meal_entry.dart';
import '../domain/targets.dart';
import '../providers/food_providers.dart';
import '../widgets/date_strip.dart';
import '../widgets/diary_nutrition_summary.dart';
import '../widgets/log_confirmation_toast.dart';
import '../widgets/meal_section.dart';
import '../widgets/streak_strip.dart';
import '../../../shared/widgets/atlas_error.dart';
import '../../../shared/widgets/atlas_skeleton.dart';
import 'edit_entry_sheet.dart';
import 'food_search_sheet.dart';
import 'goal_settings_hub.dart';
import 'meal_picker_sheet.dart';
import 'micros_sheet.dart';
import 'quick_add_sheet.dart';
import 'saved_meals_sheet.dart';

/// Today's logging surface. Streak strip → date strip → hero card → water →
/// 6 meal sections. Hosts the dual FAB. Extracted from the old FoodScreen.
class DiaryTab extends ConsumerWidget {
  const DiaryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final date = ref.watch(diaryDateProvider);
    final entriesAsync = ref.watch(diaryEntriesProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenH, 8, AppSpace.screenH, 4),
              child: const StreakStrip(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenH, 6, AppSpace.screenH, 6),
              child: DateStrip(
                date: date,
                onChanged: (d) =>
                    ref.read(diaryDateProvider.notifier).state = d,
              ),
            ),
            Expanded(
              child: entriesAsync.when(
                data: (entries) {
                  final bySlot = <MealTimeSlot, List<MealEntry>>{
                    for (final s in kDiarySlotOrder) s: [],
                  };
                  for (final e in entries) {
                    bySlot[e.slot]!.add(e);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.screenH, 8, AppSpace.screenH, 100),
                    children: [
                      DiaryNutritionSummary(
                        onMicrosTap: () => _openMicros(
                            context,
                            ref.read(diaryTotalsProvider),
                            ref.read(dailyTargetsProvider)),
                        onGoalTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const GoalSettingsHub()),
                        ),
                        onAddMeal: () => _openMealPicker(context, ref, date),
                        onQuickAdd: () => _openQuickAdd(context, ref, date),
                      ),
                      const SizedBox(height: 14),
                      // Meal list — the hero of the diary. Show the meals on the
                      // user's schedule, plus any off-schedule slot that already
                      // has logged entries so nothing logged is ever hidden.
                      for (final slot in kDiarySlotOrder)
                        if (ref
                                .watch(mealPlanProvider)
                                .forSlot(slot)
                                .enabled ||
                            bySlot[slot]!.isNotEmpty) ...[
                        MealSection(
                          slot: slot,
                          date: date,
                          entries: bySlot[slot]!,
                          onAdd: () => _openSearch(context, ref, slot, date),
                          onEdit: (e) => _openEdit(context, ref, e),
                          onDelete: (e) async {
                            final repo = ref.read(foodRepositoryProvider);
                            await repo.deleteEntry(e.id);
                            ref.invalidate(diaryEntriesProvider);
                          },
                          onCopyMeal: () => _copyMeal(
                              context, ref, slot, date, bySlot[slot]!),
                          onSaveAsMeal: () =>
                              _saveAsMeal(context, ref, slot, bySlot[slot]!),
                          onLoadSavedMeal: () =>
                              _loadSavedMeal(context, ref, slot, date),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
                loading: () => Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.screenH, 8, AppSpace.screenH, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      AtlasSkeleton.card(cardHeight: 300),
                      SizedBox(height: 16),
                      AtlasSkeleton.listRow(rows: 4),
                    ],
                  ),
                ),
                error: (e, _) => AtlasError(
                  error: e,
                  title: 'Couldn\'t load diary',
                  onRetry: () => ref.invalidate(diaryEntriesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSearch(
    BuildContext context,
    WidgetRef ref,
    MealTimeSlot slot,
    DateTime date,
  ) {
    showModalBottomSheet<MealEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.c.background,
      builder: (_) => FoodSearchSheet(slot: slot, date: date),
    ).then((logged) {
      ref.invalidate(diaryEntriesProvider);
      if (logged != null && context.mounted) {
        LogConfirmationToast.show(context, logged.totals, slotLabel: slot.label);
      }
    });
  }

  void _openMealPicker(BuildContext context, WidgetRef ref, DateTime date) {
    showModalBottomSheet<MealTimeSlot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const MealPickerSheet(),
    ).then((slot) {
      if (slot != null && context.mounted) {
        _openSearch(context, ref, slot, date);
      }
    });
  }

  void _openEdit(BuildContext context, WidgetRef ref, MealEntry entry) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.background,
      builder: (_) => EditEntrySheet(entry: entry),
    ).then((changed) {
      if (changed == true) ref.invalidate(diaryEntriesProvider);
    });
  }

  void _openQuickAdd(BuildContext context, WidgetRef ref, DateTime date) {
    showModalBottomSheet<MealEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.background,
      builder: (_) => QuickAddSheet(date: date),
    ).then((logged) {
      ref.invalidate(diaryEntriesProvider);
      if (logged != null && context.mounted) {
        LogConfirmationToast.show(context, logged.totals,
            slotLabel: logged.slot.label);
      }
    });
  }

  void _openMicros(
      BuildContext context, Nutrients totals, DailyTargets targets) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.c.background,
      builder: (_) => MicrosSheet(totals: totals, targets: targets),
    );
  }

  void _copyMeal(
    BuildContext context,
    WidgetRef ref,
    MealTimeSlot slot,
    DateTime date,
    List<MealEntry> entries,
  ) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to copy')),
      );
      return;
    }
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final isSameDay = date == todayOnly;

    final picked = isSameDay
        ? await showDatePicker(
            context: context,
            initialDate: todayOnly.add(const Duration(days: 1)),
            firstDate: todayOnly,
            lastDate: todayOnly.add(const Duration(days: 30)),
          )
        : todayOnly;
    if (picked == null && isSameDay) return;

    final dest = picked ?? todayOnly;
    final repo = ref.read(foodRepositoryProvider);
    await repo.copyMeal(
      srcSlot: slot,
      srcDate: date,
      destSlot: slot,
      destDate: dest,
    );
    ref.invalidate(diaryEntriesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Copied ${slot.label} (${entries.length} items) to ${isSameDay ? "selected date" : "today"}')),
      );
    }
  }

  void _saveAsMeal(
    BuildContext context,
    WidgetRef ref,
    MealTimeSlot slot,
    List<MealEntry> entries,
  ) async {
    if (entries.isEmpty) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: slot.label);
        return AlertDialog(
          title: const Text('Save as meal'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Meal name'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                child: const Text('Save')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final repo = MealBundleRepository();
    await repo.saveFromEntries(name: name, entries: entries);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" saved (${entries.length} items)')),
      );
    }
  }

  void _loadSavedMeal(
    BuildContext context,
    WidgetRef ref,
    MealTimeSlot slot,
    DateTime date,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SavedMealsSheet(slot: slot, date: date),
    );
  }
}


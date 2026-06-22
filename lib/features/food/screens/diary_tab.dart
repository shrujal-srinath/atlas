import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
import 'goal_setting_screen.dart';
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
    final waterAsync = ref.watch(waterIntakeProvider);
    final waterTarget = ref.watch(waterTargetProvider);

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
                              builder: (_) => const GoalSettingScreen()),
                        ),
                        onAddMeal: () => _openMealPicker(context, ref, date),
                        onQuickAdd: () => _openQuickAdd(context, ref, date),
                      ),
                      const SizedBox(height: 14),
                      // Meal list — the hero of the diary.
                      for (final slot in kDiarySlotOrder) ...[
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
                      const SizedBox(height: 4),
                      _WaterCard(
                        ml: waterAsync.valueOrNull ?? 0,
                        targetMl: waterTarget,
                        onAdd: () async {
                          final repo = ref.read(foodRepositoryProvider);
                          await repo.addWater(250, date);
                          ref.invalidate(waterIntakeProvider);
                          HapticFeedback.lightImpact();
                        },
                        onRemove: () async {
                          final repo = ref.read(foodRepositoryProvider);
                          await repo.removeLastWater(date);
                          ref.invalidate(waterIntakeProvider);
                        },
                      ),
                    ],
                  );
                },
                loading: () => Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.screenH, 8, AppSpace.screenH, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      AtlasSkeleton.card(cardHeight: 220),
                      SizedBox(height: 12),
                      AtlasSkeleton.card(cardHeight: 90),
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

// ── Water tracker ───────────────────────────────────────────────

class _WaterCard extends StatelessWidget {
  final int ml;
  final int targetMl;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _WaterCard({
    required this.ml,
    required this.targetMl,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final glasses = (ml / 250).ceil();
    final targetGlasses = (targetMl / 250).ceil();
    final pct = targetMl <= 0 ? 0.0 : (ml / targetMl).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.droplets, size: 16, color: c.athletic),
              const SizedBox(width: 8),
              Expanded(
                child: Text('WATER',
                    style: AppType.overline.copyWith(color: c.textMuted)),
              ),
              Text(
                '${(ml / 1000).toStringAsFixed(1)} / ${(targetMl / 1000).toStringAsFixed(1)} L',
                style: AppType.numMd.copyWith(color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 6, color: c.surfaceElevated),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(height: 6, color: c.athletic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(
                    targetGlasses.clamp(0, 14),
                    (i) => Icon(
                      LucideIcons.glassWater,
                      size: 16,
                      color: i < glasses ? c.athletic : c.textDim,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: ml > 0 ? onRemove : null,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(LucideIcons.minus,
                      size: 14,
                      color: ml > 0 ? c.textSecondary : c.textDim),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    border: Border.all(color: c.athletic),
                  ),
                  child: Icon(LucideIcons.plus, size: 14, color: c.athletic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


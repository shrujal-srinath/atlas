import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../domain/meal_entry.dart';
import '../food_colors.dart';
import '../providers/food_providers.dart';
import '../providers/health_score_providers.dart';
import 'food_score_info_sheet.dart';
import 'health_score_chip.dart';
import 'quick_log_chips.dart';

/// One meal slot card on the diary — per-slot tinted header, health-score
/// chip when non-empty, swipe-to-delete rows, and a quick-log chip row of
/// the user's last-3 logs in this slot.
class MealSection extends ConsumerWidget {
  final MealTimeSlot slot;
  final DateTime date;
  final List<MealEntry> entries;
  final VoidCallback onAdd;
  final void Function(MealEntry) onDelete;
  final void Function(MealEntry)? onEdit;
  final VoidCallback? onCopyMeal;
  final VoidCallback? onSaveAsMeal;
  final VoidCallback? onLoadSavedMeal;

  const MealSection({
    super.key,
    required this.slot,
    required this.date,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
    this.onEdit,
    this.onCopyMeal,
    this.onSaveAsMeal,
    this.onLoadSavedMeal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final score = ref.watch(mealHealthScoreProvider(slot));
    final tint = _tintFor(c, slot);
    final mealName = ref.watch(mealPlanProvider).forSlot(slot).name;
    final macroTarget = ref.watch(mealMacroTargetsProvider)[slot];
    final target = macroTarget?.kcal;
    final kcal = entries.fold<double>(0, (a, e) => a + e.totals.kcal);
    final isEmpty = entries.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: meal name · X of Y Cal · round + ──
          GestureDetector(
            onLongPress: entries.isNotEmpty ? onCopyMeal : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 11),
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_iconFor(slot), size: 15, color: tint),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            mealName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entries.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          HealthScoreChip(
                            score: score,
                            onTap: () => FoodScoreInfoSheet.show(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        target != null
                            ? '${kcal.round()} of $target Cal'
                            : '${kcal.round()} Cal',
                        style: AppType.numMd.copyWith(
                            color: c.textMuted, fontSize: 12.5),
                      ),
                      if (macroTarget != null && macroTarget.hasMacros) ...[
                        const SizedBox(height: 2),
                        Text(
                          'P${macroTarget.proteinG} · C${macroTarget.carbsG} · F${macroTarget.fatG}',
                          style: AppType.meta.copyWith(
                              color: c.textDim, fontSize: 10.5),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 8),
                  _AddButton(tint: tint, onTap: onAdd),
                ],
              ),
            ),
          ),

          if (isEmpty) ...[
            // Friendly empty-state prompt card (tap to add)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Material(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  onTap: onAdd,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    alignment: Alignment.center,
                    child: Text(
                      _emptyPromptFor(slot),
                      textAlign: TextAlign.center,
                      style: AppType.meta.copyWith(color: c.textMuted),
                    ),
                  ),
                ),
              ),
            ),
            QuickLogChips(slot: slot, date: date),
          ] else ...[
            Divider(height: 1, color: c.border),
            // Entry rows
            for (final e in entries) ...[
              _EntryRow(
                entry: e,
                onDelete: () => onDelete(e),
                onTap: onEdit == null ? null : () => onEdit!(e),
              ),
              Divider(height: 1, color: c.border),
            ],
            // Footer: add more + save/load
            InkWell(
              onTap: onAdd,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadii.card)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.plus, size: 14, color: tint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add more',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tint,
                        ),
                      ),
                    ),
                    if (onLoadSavedMeal != null)
                      GestureDetector(
                        onTap: onLoadSavedMeal,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(LucideIcons.bookmark,
                              size: 16, color: c.textMuted),
                        ),
                      ),
                    if (onSaveAsMeal != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onSaveAsMeal,
                        child: Icon(LucideIcons.save,
                            size: 16, color: c.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(MealTimeSlot s) => switch (s) {
        MealTimeSlot.breakfast   => LucideIcons.sunrise,
        MealTimeSlot.preWorkout  => LucideIcons.zap,
        MealTimeSlot.lunch       => LucideIcons.sun,
        MealTimeSlot.snack       => LucideIcons.cookie,
        MealTimeSlot.postWorkout => LucideIcons.flame,
        MealTimeSlot.dinner      => LucideIcons.moon,
      };

  /// Distinct per-slot accent. Breakfast = amber sun, lunch = teal,
  /// dinner = athletic/blue-violet, snack = muted, pre = building, post = positive.
  static Color _tintFor(AppPalette c, MealTimeSlot s) => switch (s) {
        MealTimeSlot.breakfast   => c.amber,
        MealTimeSlot.preWorkout  => c.mind,
        MealTimeSlot.lunch       => c.accent,
        MealTimeSlot.snack       => c.textSecondary,
        MealTimeSlot.postWorkout => c.positive,
        MealTimeSlot.dinner      => c.indigo,
      };

  static String _emptyPromptFor(MealTimeSlot s) => switch (s) {
        MealTimeSlot.breakfast   => 'Start strong — log your breakfast 🍳',
        MealTimeSlot.preWorkout  => 'Fuel up before training ⚡',
        MealTimeSlot.lunch       => "Don't miss lunch — grab a tasty meal 🍱",
        MealTimeSlot.snack       => 'Grab a snack to stay energized 🥜',
        MealTimeSlot.postWorkout => 'Recover — log your post-workout meal 🥤',
        MealTimeSlot.dinner      => 'Wind down with a balanced dinner 🌙',
      };
}

// ── Round add button (HealthifyMe-style) ────────────────────────────

class _AddButton extends StatelessWidget {
  final Color tint;
  final VoidCallback onTap;
  const _AddButton({required this.tint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(LucideIcons.plus, size: 17, color: tint),
        ),
      ),
    );
  }
}

// ── Entry row ───────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final MealEntry entry;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  const _EntryRow({required this.entry, required this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final n = entry.totals;

    return Dismissible(
      key: ValueKey('entry-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: c.negative.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(LucideIcons.trash2, color: c.negative, size: 18),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          style: t.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.loggedVia == 'habit') ...[
                        const SizedBox(width: 7),
                        const _TaskBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_fmtQty(entry.qty)} ${entry.unit}',
                    style: t.meta.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _MacroChip(label: 'P', value: n.proteinG, color: c.proteinColor),
                      const SizedBox(width: 5),
                      _MacroChip(label: 'C', value: n.carbsG, color: c.carbsColor),
                      const SizedBox(width: 5),
                      _MacroChip(label: 'F', value: n.fatG, color: c.fatColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${n.kcal.round()}',
                    style: AppType.numMd.copyWith(color: c.textPrimary)),
                Text('kcal',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    )),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _fmtQty(double q) {
    if (q == q.roundToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(1);
  }
}

/// Tiny marker on diary rows that were auto-logged by completing a task.
class _TaskBadge extends StatelessWidget {
  const _TaskBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.listChecks, size: 10, color: c.accent),
          const SizedBox(width: 3),
          Text(
            'Task',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: c.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MacroChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$label ${value.round()}g',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

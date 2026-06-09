import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../domain/meal_entry.dart';
import '../providers/health_score_providers.dart';
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
    this.onCopyMeal,
    this.onSaveAsMeal,
    this.onLoadSavedMeal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final score = ref.watch(mealHealthScoreProvider(slot));
    final tint = _tintFor(c, slot);
    final kcal = entries.fold<double>(0, (a, e) => a + e.totals.kcal);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          GestureDetector(
            onLongPress: entries.isNotEmpty ? onCopyMeal : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(_iconFor(slot), size: 14, color: tint),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    slot.label.toUpperCase(),
                    style: AppType.overline.copyWith(
                      color: c.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (entries.isNotEmpty) HealthScoreChip(score: score),
                  const Spacer(),
                  if (entries.isNotEmpty) ...[
                    GestureDetector(
                      onTap: onCopyMeal,
                      child: Icon(LucideIcons.copy, size: 13, color: c.textDim),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text('${kcal.round()}',
                      style: AppType.numMd.copyWith(color: c.textPrimary)),
                  const SizedBox(width: 2),
                  Text('kcal',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: c.textMuted,
                      )),
                ],
              ),
            ),
          ),

          if (entries.isEmpty) ...[
            // Empty state + quick-log chips beneath
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Text(
                _emptyHintFor(slot),
                style: AppType.meta.copyWith(color: c.textDim),
              ),
            ),
            QuickLogChips(slot: slot, date: date),
            Divider(height: 1, color: c.border),
          ] else
            Divider(height: 1, color: c.border),

          // Entry rows
          for (final e in entries) ...[
            _EntryRow(entry: e, onDelete: () => onDelete(e)),
            Divider(height: 1, color: c.border),
          ],

          // Add food + save/load
          InkWell(
            onTap: onAdd,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadii.card)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
              child: Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(LucideIcons.plus, size: 13, color: tint),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add food',
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
                  if (entries.isNotEmpty && onSaveAsMeal != null) ...[
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

  static String _emptyHintFor(MealTimeSlot s) => switch (s) {
        MealTimeSlot.breakfast   => 'No breakfast logged · tap to add',
        MealTimeSlot.preWorkout  => 'Pre-workout fuel — log to track',
        MealTimeSlot.lunch       => 'Add your lunch to track macros',
        MealTimeSlot.snack       => 'Log snacks to capture stray calories',
        MealTimeSlot.postWorkout => 'Post-workout window — log recovery',
        MealTimeSlot.dinner      => 'No dinner logged · tap to add',
      };
}

// ── Entry row ───────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final MealEntry entry;
  final VoidCallback onDelete;
  const _EntryRow({required this.entry, required this.onDelete});

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: t.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_fmtQty(entry.qty)} ${entry.unit}',
                    style: t.meta.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _MacroChip(label: 'P', value: n.proteinG, color: c.athletic),
                      const SizedBox(width: 5),
                      _MacroChip(label: 'C', value: n.carbsG, color: c.amber),
                      const SizedBox(width: 5),
                      _MacroChip(label: 'F', value: n.fatG, color: c.mind),
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
    );
  }

  String _fmtQty(double q) {
    if (q == q.roundToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(1);
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$label ${value.round()}g',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';

/// "Which meal would you like to track?" — the picker shown when the user taps
/// the main log-food FAB. Lists every slot with its `X of Y Cal` progress and a
/// `+`. Pops the chosen [MealTimeSlot] so the caller can open the search sheet.
class MealPickerSheet extends ConsumerWidget {
  const MealPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final entries =
        ref.watch(diaryEntriesProvider).valueOrNull ?? const <MealEntry>[];
    final targets = ref.watch(mealTargetsProvider);

    final consumed = <MealTimeSlot, double>{
      for (final s in kDiarySlotOrder) s: 0,
    };
    for (final e in entries) {
      consumed[e.slot] = (consumed[e.slot] ?? 0) + e.totals.kcal;
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenH, 16, AppSpace.screenH, 6),
            child: Text(
              'Which meal would you like to track?',
              style: t.h2.copyWith(color: c.accent),
            ),
          ),
          const SizedBox(height: 4),
          for (final slot in kDiarySlotOrder)
            _MealRow(
              slot: slot,
              consumed: consumed[slot] ?? 0,
              target: targets[slot],
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(slot);
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final MealTimeSlot slot;
  final double consumed;
  final int? target;
  final VoidCallback onTap;
  const _MealRow({
    required this.slot,
    required this.consumed,
    required this.target,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.screenH, vertical: 4),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      slot.label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    target != null
                        ? '${consumed.round()} of $target kcal'
                        : '${consumed.round()} kcal',
                    style: AppType.numMd.copyWith(
                        color: c.textMuted, fontSize: 13.5),
                  ),
                  const SizedBox(width: 14),
                  Icon(LucideIcons.plus, size: 20, color: c.accent),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';
import '../providers/slot_history_provider.dart';
import 'log_confirmation_toast.dart';

/// Horizontal strip of up to 3 chips: [Oats 80g] [Whey 32g] [Banana 1].
/// Each = one-shot relog of the most recent entry for that food in this slot.
class QuickLogChips extends ConsumerWidget {
  final MealTimeSlot slot;
  final DateTime date;

  const QuickLogChips({super.key, required this.slot, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(slotHistoryProvider(slot));
    return async.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final c = context.c;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(LucideIcons.history, size: 12, color: c.textDim),
                ),
                for (final item in items) ...[
                  _Chip(
                    name: item.template.name,
                    qty: item.template.qty,
                    unit: item.template.unit,
                    onTap: () async {
                      final repo = ref.read(foodRepositoryProvider);
                      await repo.relogFromTemplate(
                        template: item.template,
                        slot: slot,
                        date: date,
                      );
                      ref.invalidate(diaryEntriesProvider);
                      if (context.mounted) {
                        LogConfirmationToast.show(
                          context,
                          item.template.totals,
                          slotLabel: slot.label,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String name;
  final double qty;
  final String unit;
  final VoidCallback onTap;

  const _Chip({
    required this.name,
    required this.qty,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(1);
    final shortName = name.length > 18 ? '${name.substring(0, 17)}…' : name;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 11, color: c.accent),
            const SizedBox(width: 5),
            Text(shortName,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                )),
            const SizedBox(width: 4),
            Text('· $qtyStr $unit',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}

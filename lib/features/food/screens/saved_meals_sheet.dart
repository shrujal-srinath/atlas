import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../data/meal_bundle_repository.dart';
import '../domain/food.dart';
import '../domain/meal_bundle.dart';
import '../domain/meal_entry.dart';
import '../providers/food_providers.dart';
import '../widgets/log_confirmation_toast.dart';

final _bundleRepoProvider =
    Provider<MealBundleRepository>((_) => MealBundleRepository());

final _bundlesProvider =
    FutureProvider.autoDispose<List<MealBundle>>((ref) async {
  final repo = ref.watch(_bundleRepoProvider);
  return repo.list();
});

/// Bottom sheet listing saved meal bundles with a "Log all" action.
class SavedMealsSheet extends ConsumerWidget {
  final MealTimeSlot slot;
  final DateTime date;
  const SavedMealsSheet({super.key, required this.slot, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final bundles = ref.watch(_bundlesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.screenH, 14, AppSpace.screenH, 6),
              child: Row(
                children: [
                  Expanded(
                      child: Text('Saved meals', style: t.h2)),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: c.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: bundles.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, _) => Center(
                    child: Text('Failed to load',
                        style: t.body.copyWith(color: c.textMuted))),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.bookmark, size: 28, color: c.textDim),
                            const SizedBox(height: 10),
                            Text('No saved meals yet',
                                style: t.body.copyWith(color: c.textMuted)),
                            const SizedBox(height: 4),
                            Text(
                              'Long-press a meal slot header to save it',
                              style: t.meta.copyWith(color: c.textDim),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(
                            AppSpace.screenH, 8, AppSpace.screenH, 32),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _BundleTile(
                          bundle: list[i],
                          slot: slot,
                          date: date,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleTile extends ConsumerWidget {
  final MealBundle bundle;
  final MealTimeSlot slot;
  final DateTime date;
  const _BundleTile({
    required this.bundle,
    required this.slot,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final n = bundle.totalNutrients;

    return Dismissible(
      key: ValueKey('bundle-${bundle.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: c.negative.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(LucideIcons.trash2, color: c.negative, size: 16),
            const SizedBox(width: 6),
            Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: c.negative,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        final repo = ref.read(_bundleRepoProvider);
        await repo.delete(bundle.id);
        ref.invalidate(_bundlesProvider);
        return true;
      },
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      border: Border.all(
                          color: c.accent.withValues(alpha: 0.25), width: 0.5),
                    ),
                    child: Icon(LucideIcons.bookmark,
                        size: 16, color: c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bundle.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: c.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bundle.items.length} items',
                          style: t.meta.copyWith(color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surfaceElevated,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${n.kcal.round()} kcal',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _MacroChip(label: 'P', value: n.proteinG.round()),
                  const SizedBox(width: 6),
                  _MacroChip(label: 'C', value: n.carbsG.round()),
                  const SizedBox(width: 6),
                  _MacroChip(label: 'F', value: n.fatG.round()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final repo = ref.read(_bundleRepoProvider);
                    final totals = bundle.items.fold<Nutrients>(
                        Nutrients.zero, (a, i) => a + i.scaledNutrients);
                    await repo.logBundle(
                      bundle: bundle,
                      slot: slot,
                      date: date,
                    );
                    ref.invalidate(diaryEntriesProvider);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      LogConfirmationToast.show(context, totals,
                          slotLabel: slot.label);
                    }
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: Text('Log to ${slot.label}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.onAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.chip)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final int value;
  const _MacroChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

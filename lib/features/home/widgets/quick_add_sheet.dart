import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../food/providers/food_providers.dart';
import '../../habits/widgets/habit_type_picker.dart';

/// 4-tile bottom sheet invoked by the center FAB on Home.
/// Order: Habit · Food · Water · Journal.
/// Habit opens the existing type-picker; Food navigates to the diary;
/// Water logs +250 ml inline (long-press for a custom-volume dialog);
/// Journal opens the daily wellness check-in.
Future<void> showQuickAdd4Tile(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _QuickAdd4Tile(),
  );
}

class _QuickAdd4Tile extends ConsumerWidget {
  const _QuickAdd4Tile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 28,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Text(
                'QUICK ADD',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: c.textMuted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
              child: Text(
                'Start a moment',
                style: t.h2.copyWith(fontSize: 19),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 14, 20, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _QuickTile(
                          icon: LucideIcons.repeat,
                          label: 'Habit',
                          sublabel: 'Create',
                          accent: c.accent,
                          onTap: () {
                            Navigator.of(context).pop();
                            showHabitTypePicker(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickTile(
                          icon: LucideIcons.utensilsCrossed,
                          label: 'Food',
                          sublabel: 'Log meal',
                          accent: c.athletic,
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go('/food');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickTile(
                          icon: LucideIcons.droplet,
                          label: '+250 ml',
                          sublabel: 'Hold for custom',
                          accent: c.mind,
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final repo = ref.read(foodRepositoryProvider);
                            final date = ref.read(diaryDateProvider);
                            await repo.addWater(250, date);
                            ref.invalidate(waterIntakeProvider);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          onLongPress: () async {
                            final ml =
                                await _promptCustomWater(context);
                            if (ml == null || ml <= 0) return;
                            final repo = ref.read(foodRepositoryProvider);
                            final date = ref.read(diaryDateProvider);
                            await repo.addWater(ml, date);
                            ref.invalidate(waterIntakeProvider);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickTile(
                          icon: LucideIcons.bookOpen,
                          label: 'Journal',
                          sublabel: 'Reflect',
                          accent: c.body,
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/journal');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<int?> _promptCustomWater(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text('Custom volume', style: ctx.t.h2),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: ctx.t.body,
            decoration: InputDecoration(
              hintText: 'ml',
              suffixText: 'ml',
              suffixStyle: AppType.meta.copyWith(color: c.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.accent,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              },
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 7,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.25), width: 0.5),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(height: 12),
              Text(
                label,
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
                sublabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: c.textMuted,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/food_providers.dart';
import '../providers/streak_provider.dart';

/// 7-dot horizontal strip of last week's logging adherence.
/// Filled (accent) = hit ≥80% of target & logged ≥1 entry.
/// Today's dot has a 1px accent ring.
/// Tap a dot → jump the diary to that date.
class StreakStrip extends ConsumerWidget {
  const StreakStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(streakProvider);

    return async.when(
      data: (days) {
        final hits = days.where((d) => d.state == DayLogState.hit).length;
        return Row(
          children: [
            Text('STREAK',
                style: AppType.overline.copyWith(color: c.textMuted, letterSpacing: 1.2)),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (final d in days) ...[
                    _Dot(
                      day: d,
                      onTap: () =>
                          ref.read(diaryDateProvider.notifier).state = d.date,
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Text('$hits / 7',
                style: AppType.numMd.copyWith(color: c.textPrimary, fontSize: 13)),
          ],
        );
      },
      loading: () => const SizedBox(height: 14),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _Dot extends StatelessWidget {
  final DayLog day;
  final VoidCallback onTap;
  const _Dot({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Color fill;
    Color stroke;
    switch (day.state) {
      case DayLogState.hit:
        fill = c.accent;
        stroke = c.accent;
        break;
      case DayLogState.partial:
        fill = c.accent.withValues(alpha: 0.28);
        stroke = c.accent.withValues(alpha: 0.55);
        break;
      case DayLogState.empty:
      case DayLogState.future:
        fill = Colors.transparent;
        stroke = c.textDim;
        break;
    }

    return Tooltip(
      message: '${DateFormat('EEE MMM d').format(day.date)} · '
          '${day.kcal.round()} kcal',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: stroke, width: 1),
          ),
          child: day.isToday
              ? Center(
                  child: Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      color: day.state == DayLogState.empty
                          ? c.accent
                          : c.background,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

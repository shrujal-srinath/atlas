import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/streak_provider.dart';
import 'fuel_calendar_sheet.dart';

/// Tappable fueling summary: a 7-day adherence preview that opens the full
/// month [FuelCalendarSheet] on tap. Filled (accent) dot = hit ≥80% of target.
class StreakStrip extends ConsumerWidget {
  const StreakStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(streakProvider);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () {
          HapticFeedback.selectionClick();
          showFuelCalendar(context);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: AppShadows.card,
          ),
          child: async.when(
            data: (days) {
              final hits = days.where((d) => d.state == DayLogState.hit).length;
              return Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.calendarRange,
                        size: 15, color: c.accent),
                  ),
                  const SizedBox(width: 10),
                  Text('FUELING',
                      style: AppType.overline
                          .copyWith(color: c.textMuted, letterSpacing: 1.2)),
                  const SizedBox(width: 12),
                  for (final d in days) ...[
                    _Dot(day: d),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  Text('$hits/7',
                      style:
                          AppType.numMd.copyWith(color: c.textPrimary, fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight, size: 16, color: c.textMuted),
                ],
              );
            },
            loading: () => const SizedBox(height: 28),
            error: (_, _) => const SizedBox(height: 28),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final DayLog day;
  const _Dot({required this.day});

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
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: stroke, width: 1),
        ),
        child: day.isToday
            ? Center(
                child: Container(
                  width: 4,
                  height: 4,
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
    );
  }
}

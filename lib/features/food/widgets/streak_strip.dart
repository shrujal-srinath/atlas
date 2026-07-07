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
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(LucideIcons.calendarRange,
                        size: 16, color: c.accent),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('FUELING',
                                style: AppType.overline.copyWith(
                                    color: c.textMuted, letterSpacing: 1.2)),
                            const Spacer(),
                            Text('$hits',
                                style: AppType.numMd.copyWith(
                                    color: hits >= 5 ? c.positive : c.textPrimary,
                                    fontSize: 13)),
                            Text(' of 7 on target',
                                style:
                                    AppType.meta.copyWith(color: c.textMuted)),
                            const SizedBox(width: 3),
                            Icon(LucideIcons.chevronRight,
                                size: 15, color: c.textMuted),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final d in days)
                              Expanded(
                                child: Column(
                                  children: [
                                    _Dot(day: d),
                                    const SizedBox(height: 4),
                                    Text(
                                      _weekdayLetter(d.date),
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: d.isToday
                                            ? c.accent
                                            : c.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => _placeholderRow(context),
            error: (_, _) => _placeholderRow(context),
          ),
        ),
      ),
    );
  }
}

/// Mon-first single-letter for a weekday.
String _weekdayLetter(DateTime d) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1];

/// Loading / no-data shell — keeps the strip self-describing (icon · FUELING ·
/// faded dots + weekday letters · chevron) instead of collapsing to a blank,
/// mysterious pill. Mirrors the loaded layout so there's no height jump.
Widget _placeholderRow(BuildContext context) {
  final c = context.c;
  final today = DateTime.now();
  return Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(LucideIcons.calendarRange, size: 16, color: c.accent),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('FUELING',
                    style: AppType.overline
                        .copyWith(color: c.textMuted, letterSpacing: 1.2)),
                const Spacer(),
                Icon(LucideIcons.chevronRight, size: 15, color: c.textMuted),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.textDim, width: 1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _weekdayLetter(
                              today.subtract(Duration(days: 6 - i))),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/streak_provider.dart';
import 'fuel_calendar_sheet.dart';

/// Tappable fueling summary: the trailing 7 days as day capsules, opening the
/// full month [FuelCalendarSheet] on tap.
///
/// Redesigned 2026-07-07 (NORTHSTAR T1/T5): the old 13px dots + "0 of 7 on
/// target" framing read as failure on a fresh week and the icon chip wasted a
/// third of the row. Now: no chip, full-width capsules with the weekday letter
/// beneath, and a status line that adapts — neutral before anything is logged,
/// counting only once there's something to count.
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
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: AppShadows.card,
          ),
          child: async.when(
            data: (days) => _Loaded(days: days),
            loading: () => const _Placeholder(),
            error: (_, _) => const _Placeholder(),
          ),
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  final List<DayLog> days;
  const _Loaded({required this.days});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hits = days.where((d) => d.state == DayLogState.hit).length;
    final logged = days
        .where((d) =>
            d.state == DayLogState.hit || d.state == DayLogState.partial)
        .length;

    // Status adapts to the week's reality — never opens with "0 of 7".
    final String status;
    final Color statusColor;
    if (logged == 0) {
      status = 'Start today';
      statusColor = c.textMuted;
    } else if (hits == 0) {
      status = logged == 1 ? '1 day logged' : '$logged days logged';
      statusColor = c.textMuted;
    } else {
      status = '$hits on target';
      statusColor = hits >= 5 ? c.positive : c.textPrimary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('FUELING · 7 DAYS',
                style: AppType.overline
                    .copyWith(color: c.textMuted, letterSpacing: 1.2)),
            const Spacer(),
            Text(status,
                style: AppType.meta.copyWith(
                    color: statusColor, fontWeight: FontWeight.w600)),
            const SizedBox(width: 3),
            Icon(LucideIcons.chevronRight, size: 15, color: c.textMuted),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < days.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(child: _DayCapsule(day: days[i])),
            ],
          ],
        ),
      ],
    );
  }
}

/// Loading / no-data shell — mirrors the loaded layout (label · capsules ·
/// letters · chevron) so there's no height jump and the strip always reads as
/// itself instead of a blank pill.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final today = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('FUELING · 7 DAYS',
                style: AppType.overline
                    .copyWith(color: c.textMuted, letterSpacing: 1.2)),
            const Spacer(),
            Icon(LucideIcons.chevronRight, size: 15, color: c.textMuted),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: c.border, width: 1),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _weekdayLetter(today.subtract(Duration(days: 6 - i))),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: c.textMuted,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Mon-first single-letter for a weekday.
String _weekdayLetter(DateTime d) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1];

/// One day of the week: a state-filled capsule with its weekday letter below.
/// Today is ringed in accent; letters stay outside the fill so no text ever
/// sits on a tint (house rule 1).
class _DayCapsule extends StatelessWidget {
  final DayLog day;
  const _DayCapsule({required this.day});

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    Color fill;
    Color stroke;
    double strokeW = 1;
    switch (day.state) {
      case DayLogState.hit:
        fill = c.accent;
        stroke = c.accent;
        break;
      case DayLogState.partial:
        fill = c.accent.withValues(alpha: 0.18);
        stroke = c.accent.withValues(alpha: 0.50);
        break;
      case DayLogState.empty:
        fill = c.surfaceElevated;
        stroke = c.border;
        break;
      case DayLogState.future:
        fill = Colors.transparent;
        stroke = c.border;
        break;
    }
    // Today gets an accent ring unless it's already fully accent.
    if (day.isToday && day.state != DayLogState.hit) {
      stroke = c.accent.withValues(alpha: 0.65);
      strokeW = 1.4;
    }

    final letterColor = switch (day.state) {
      _ when day.isToday => c.accent,
      DayLogState.future => c.textDim,
      _ => c.textMuted,
    };

    return Tooltip(
      message: '${DateFormat('EEE MMM d').format(day.date)} · '
          '${day.kcal.round()} kcal',
      child: Column(
        children: [
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: stroke, width: strokeW),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _weekdayLetter(day.date),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w700,
              color: letterColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

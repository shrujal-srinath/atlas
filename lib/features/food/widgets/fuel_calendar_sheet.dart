import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/food_providers.dart';
import '../providers/streak_provider.dart';

/// Opens the month-by-month fueling calendar as a bottom sheet.
Future<void> showFuelCalendar(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.c.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const FuelCalendarSheet(),
  );
}

/// A month calendar where each day is shaded by how that day's calories
/// compared to the user's target — the higher the intake (toward / above
/// target), the greener; well under target reads amber→red. Tap a day to
/// inspect it or jump the diary there. Backed by [monthCaloriesProvider].
class FuelCalendarSheet extends ConsumerStatefulWidget {
  const FuelCalendarSheet({super.key});

  @override
  ConsumerState<FuelCalendarSheet> createState() => _FuelCalendarSheetState();
}

class _FuelCalendarSheetState extends ConsumerState<FuelCalendarSheet> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month, 1);
    _selected = DateTime(n.year, n.month, n.day);
  }

  DateTime get _currentMonth {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  bool get _canGoNext => _month.isBefore(_currentMonth);
  bool get _canGoPrev {
    final limit = DateTime(_currentMonth.year, _currentMonth.month - 6, 1);
    return _month.isAfter(limit);
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      final n = DateTime.now();
      _selected = (_month.year == n.year && _month.month == n.month)
          ? DateTime(n.year, n.month, n.day)
          : null;
    });
  }

  void _openDay(DateTime d) {
    ref.read(diaryDateProvider.notifier).state = d;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;
    final target = ref.watch(dailyTargetsProvider).kcal;
    final byDay = ref.watch(monthCaloriesProvider(_month)).valueOrNull ?? const {};

    // Month summary.
    final logged = byDay.entries.where((e) => e.value > 0).toList();
    final avg = logged.isEmpty
        ? 0
        : (logged.fold<double>(0, (a, e) => a + e.value) / logged.length).round();
    final onTarget = target <= 0
        ? 0
        : logged.where((e) => e.value / target >= 0.9).length;

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 10,
        bottom: 18 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.borderStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title + target context.
          Row(
            children: [
              Icon(LucideIcons.flame, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text('Fueling Calendar', style: t.h2),
              const Spacer(),
              Text(
                'Target ${_fmt(target.round())}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Month pager.
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_month),
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              _PagerBtn(
                  icon: LucideIcons.chevronLeft,
                  enabled: _canGoPrev,
                  onTap: () => _shiftMonth(-1)),
              const SizedBox(width: 6),
              _PagerBtn(
                  icon: LucideIcons.chevronRight,
                  enabled: _canGoNext,
                  onTap: () => _shiftMonth(1)),
            ],
          ),
          const SizedBox(height: 14),
          // Weekday header.
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _Grid(
            month: _month,
            byDay: byDay,
            target: target,
            selected: _selected,
            // Tap a day → jump the diary straight there (and close), so you can
            // review or edit that day's meals. This is the diary's date switcher.
            onTapDay: (d) {
              HapticFeedback.selectionClick();
              _openDay(d);
            },
          ),
          const SizedBox(height: 14),
          _DayDetail(
            date: _selected,
            kcal: _selected == null ? null : byDay[_selected!.day],
            target: target,
            onOpen: _selected == null ? null : () => _openDay(_selected!),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 0.5, color: c.border),
          const SizedBox(height: 12),
          // Footer: summary + legend.
          Row(
            children: [
              Text(
                logged.isEmpty ? 'No days logged' : 'avg ${_fmt(avg)} kcal',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (logged.isNotEmpty)
                Text(
                  '  ·  $onTarget on target',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: c.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Legend ramp.
          Row(
            children: [
              Text('under',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted)),
              const SizedBox(width: 6),
              for (final r in const [0.25, 0.55, 0.85, 1.0, 1.3])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 16,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _fuelColor(context, r),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              Text('on target',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// Fuel ramp — ratio = kcal / target. Higher (toward/above target) reads
// greener; well under target reads amber→red. Returns the cell fill.
Color _fuelColor(BuildContext context, double ratio) {
  final c = context.c;
  if (ratio <= 0) return c.surfaceElevated;
  if (ratio >= 1.0) return c.positive;
  if (ratio >= 0.8) return c.positive.withValues(alpha: 0.5);
  if (ratio >= 0.6) return c.amber.withValues(alpha: 0.85);
  if (ratio >= 0.3) return c.athletic.withValues(alpha: 0.85);
  return c.negative.withValues(alpha: 0.85);
}

bool _strongFill(double ratio) =>
    ratio <= 0 ? false : (ratio >= 1.0 || ratio < 0.6);

String _fmt(int v) {
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _Grid extends StatelessWidget {
  final DateTime month;
  final Map<int, double> byDay;
  final double target;
  final DateTime? selected;
  final ValueChanged<DateTime> onTapDay;
  const _Grid({
    required this.month,
    required this.byDay,
    required this.target,
    required this.selected,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final first = DateTime(month.year, month.month, 1);
    final leadingBlanks = first.weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final total = leadingBlanks + daysInMonth;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        childAspectRatio: 1.0,
      ),
      itemCount: total,
      itemBuilder: (_, i) {
        if (i < leadingBlanks) return const SizedBox.shrink();
        final day = i - leadingBlanks + 1;
        final date = DateTime(month.year, month.month, day);
        final kcal = byDay[day] ?? 0;
        final ratio = target <= 0 ? 0.0 : kcal / target;
        final isFuture = date.isAfter(today);
        final isToday = date == today;
        final isSelected = selected != null &&
            DateTime(selected!.year, selected!.month, selected!.day) == date;

        Color fill;
        Color numColor;
        if (isFuture) {
          fill = Colors.transparent;
          numColor = c.textDim;
        } else if (kcal <= 0) {
          fill = c.surfaceElevated;
          numColor = c.textMuted;
        } else {
          fill = _fuelColor(context, ratio);
          numColor = _strongFill(ratio) ? c.onAccent : c.textSecondary;
        }

        Border? border;
        if (isSelected) {
          border = Border.all(color: c.textPrimary, width: 1.5);
        } else if (isToday) {
          border = Border.all(color: c.accent, width: 1.5);
        } else if (isFuture) {
          border = Border.all(color: c.border, width: 0.5);
        }

        return GestureDetector(
          onTap: isFuture ? null : () => onTapDay(date),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
              border: border,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 11,
                fontWeight:
                    isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isToday && !isSelected ? c.accent : numColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayDetail extends StatelessWidget {
  final DateTime? date;
  final double? kcal;
  final double target;
  final VoidCallback? onOpen;
  const _DayDetail({
    required this.date,
    required this.kcal,
    required this.target,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (date == null) {
      return Row(
        children: [
          Icon(LucideIcons.calendarDays, size: 15, color: c.textMuted),
          const SizedBox(width: 8),
          Text(
            'Tap any day to open it',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: c.textMuted,
            ),
          ),
        ],
      );
    }
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final isFuture = date!.isAfter(today);
    final label = DateFormat('EEEE, MMM d').format(date!);
    final k = kcal ?? 0;
    final pct = target <= 0 ? 0 : ((k / target) * 100).round();

    String status;
    Color tone = c.textMuted;
    if (isFuture) {
      status = 'Upcoming';
    } else if (k <= 0) {
      status = 'Nothing logged';
    } else {
      status = '${_fmt(k.round())} kcal · $pct% of target';
      final r = target <= 0 ? 0.0 : k / target;
      tone = r >= 0.9
          ? c.positive
          : r >= 0.6
              ? c.amber
              : c.negative;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tone,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (!isFuture && onOpen != null)
          GestureDetector(
            onTap: onOpen,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(LucideIcons.arrowRight, size: 13, color: c.accent),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PagerBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PagerBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon,
            size: 16, color: enabled ? c.textSecondary : c.textDim),
      ),
    );
  }
}

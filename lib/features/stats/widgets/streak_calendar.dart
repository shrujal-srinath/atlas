import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

/// Two ways to read the calendar: a motivating streak ribbon, or the classic
/// completion-intensity shading.
enum CalendarMode { streak, intensity }

/// One day on a [StreakCalendar]. The feeding card decides what "win" means
/// (a task completed, or a "good day" across all habits).
class CalendarDay {
  final DateTime date;
  final bool scheduled; // had anything scheduled (else a rest day)
  final bool win; // counts toward the streak
  final double rate; // 0..1, for intensity shading
  final bool inCurrentRun; // part of the ongoing streak ending today
  final int runLength; // consecutive wins ending this day (for milestone flame)
  const CalendarDay({
    required this.date,
    required this.scheduled,
    required this.win,
    required this.rate,
    this.inCurrentRun = false,
    this.runLength = 0,
  });

  bool get isRest => !scheduled;
}

/// A month calendar that flips between a **streak ribbon** (consecutive win-days
/// link into a glowing bar; misses cut it; 🔥 Current · Best on top) and an
/// **intensity** heatmap. Shared by the Stats hub and the per-task stats screen.
class StreakCalendar extends StatefulWidget {
  final DateTime month; // first-of-month
  final Map<int, CalendarDay> byDay; // keyed by day-of-month
  final int current;
  final int best;
  final Color accent;
  final bool canPrev;
  final bool canNext;
  final ValueChanged<int> onPage; // delta -1 / +1
  final String title;

  const StreakCalendar({
    super.key,
    required this.month,
    required this.byDay,
    required this.current,
    required this.best,
    required this.accent,
    required this.canPrev,
    required this.canNext,
    required this.onPage,
    this.title = 'CALENDAR',
  });

  @override
  State<StreakCalendar> createState() => _StreakCalendarState();
}

class _StreakCalendarState extends State<StreakCalendar> {
  CalendarMode _mode = CalendarMode.streak;
  DateTime? _selected;

  static const _milestones = {7, 14, 30, 50, 100, 200, 365};

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    if (widget.month.year == n.year && widget.month.month == n.month) {
      _selected = DateTime(n.year, n.month, n.day);
    }
  }

  Color get _accent => widget.accent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title + month + pager
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: AppType.overline.copyWith(color: c.textMuted)),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMMM yyyy').format(widget.month),
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _PagerBtn(
                  icon: LucideIcons.chevronLeft,
                  enabled: widget.canPrev,
                  onTap: () => widget.onPage(-1)),
              const SizedBox(width: 6),
              _PagerBtn(
                  icon: LucideIcons.chevronRight,
                  enabled: widget.canNext,
                  onTap: () => widget.onPage(1)),
            ],
          ),
          const SizedBox(height: 14),
          // Mode toggle
          _ModeToggle(
            mode: _mode,
            accent: _accent,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 14),
          if (_mode == CalendarMode.streak) ...[
            _StreakBadge(current: widget.current, best: widget.best, accent: _accent),
            const SizedBox(height: 14),
          ],
          // Weekday header
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: c.textMuted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _Grid(
            month: widget.month,
            byDay: widget.byDay,
            mode: _mode,
            accent: _accent,
            selected: _selected,
            milestones: _milestones,
            onTapDay: (d) {
              HapticFeedback.selectionClick();
              setState(() => _selected = d);
            },
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 0.5, color: c.border),
          const SizedBox(height: 11),
          _Footer(
            mode: _mode,
            accent: _accent,
            selected: _selected,
            cell: _selected == null ? null : widget.byDay[_selected!.day],
          ),
        ],
      ),
    );
  }
}

// ── Mode toggle ──────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final CalendarMode mode;
  final Color accent;
  final ValueChanged<CalendarMode> onChanged;
  const _ModeToggle(
      {required this.mode, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget seg(CalendarMode m, IconData icon, String label) {
      final on = m == mode;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(m);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? c.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.button),
              border: on ? Border.all(color: accent.withValues(alpha: 0.45)) : null,
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: on ? accent : c.textMuted),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                        color: on ? accent : c.textMuted)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.button + 4),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          seg(CalendarMode.streak, LucideIcons.flame, 'Streak'),
          seg(CalendarMode.intensity, LucideIcons.layoutGrid, 'Intensity'),
        ],
      ),
    );
  }
}

// ── Streak badge (🔥 Current · Best) ──────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int current;
  final int best;
  final Color accent;
  const _StreakBadge(
      {required this.current, required this.best, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final toBest = best - current;
    final hint = current == 0
        ? 'Do today to start a streak'
        : current >= best
            ? "Best streak ever — keep it alive!"
            : '$toBest ${toBest == 1 ? 'day' : 'days'} to beat your best';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.16), accent.withValues(alpha: 0.04)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.flame, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$current',
                        style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: accent)),
                    const SizedBox(width: 4),
                    Text('day${current == 1 ? '' : 's'}',
                        style: AppType.meta.copyWith(color: c.textSecondary)),
                    const SizedBox(width: 8),
                    Text('· best $best',
                        style: AppType.meta.copyWith(color: c.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(hint,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid (weeks of ribbon rows) ────────────────────────────────────────────

class _Grid extends StatelessWidget {
  final DateTime month;
  final Map<int, CalendarDay> byDay;
  final CalendarMode mode;
  final Color accent;
  final DateTime? selected;
  final Set<int> milestones;
  final ValueChanged<DateTime> onTapDay;
  const _Grid({
    required this.month,
    required this.byDay,
    required this.mode,
    required this.accent,
    required this.selected,
    required this.milestones,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final leadingBlanks = first.weekday - 1; // Mon=1 → 0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final total = leadingBlanks + daysInMonth;
    final weeks = (total / 7.0).ceil();

    return Column(
      children: [
        for (int w = 0; w < weeks; w++) ...[
          if (w > 0) const SizedBox(height: 5),
          _WeekRow(
            cells: [
              for (int col = 0; col < 7; col++)
                _resolve(w * 7 + col - leadingBlanks),
            ],
            mode: mode,
            accent: accent,
            month: month,
            selected: selected,
            milestones: milestones,
            onTapDay: onTapDay,
          ),
        ],
      ],
    );
  }

  CalendarDay? _resolve(int dayIndex) {
    final day = dayIndex + 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (day < 1 || day > daysInMonth) return null;
    return byDay[day] ??
        CalendarDay(
            date: DateTime(month.year, month.month, day),
            scheduled: false,
            win: false,
            rate: 0);
  }
}

class _WeekRow extends StatelessWidget {
  final List<CalendarDay?> cells; // 7
  final CalendarMode mode;
  final Color accent;
  final DateTime month;
  final DateTime? selected;
  final Set<int> milestones;
  final ValueChanged<DateTime> onTapDay;
  const _WeekRow({
    required this.cells,
    required this.mode,
    required this.accent,
    required this.month,
    required this.selected,
    required this.milestones,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 7, // 7 square cells across
      child: Stack(
        children: [
          if (mode == CalendarMode.streak)
            Positioned.fill(
              child: CustomPaint(
                painter: _RibbonPainter(week: cells, accent: accent),
              ),
            ),
          Row(
            children: [
              for (final cell in cells)
                Expanded(
                  child: _DayCell(
                    cell: cell,
                    mode: mode,
                    accent: accent,
                    selected: selected,
                    milestones: milestones,
                    onTap: cell == null ? null : () => onTapDay(cell.date),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final CalendarDay? cell;
  final CalendarMode mode;
  final Color accent;
  final DateTime? selected;
  final Set<int> milestones;
  final VoidCallback? onTap;
  const _DayCell({
    required this.cell,
    required this.mode,
    required this.accent,
    required this.selected,
    required this.milestones,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (cell == null) return const SizedBox.shrink();
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final date = cell!.date;
    final isFuture = date.isAfter(today);
    final isToday = date == today;
    final isSelected = selected != null &&
        DateTime(selected!.year, selected!.month, selected!.day) == date;

    final ribbonBehind = mode == CalendarMode.streak && cell!.win;
    Color fill = Colors.transparent;
    Color numColor = c.textSecondary;
    Border? border;

    if (isFuture) {
      numColor = c.textDim;
      border = Border.all(color: c.border, width: 0.5);
    } else if (cell!.isRest) {
      fill = c.surfaceElevated;
      numColor = c.textMuted;
    } else if (mode == CalendarMode.streak) {
      if (cell!.win) {
        // Filled by the ribbon behind — keep transparent, light number.
        numColor = c.onAccent;
      } else {
        // A miss — hollow with a stronger border so it reads as a "cut".
        border = Border.all(color: c.borderStrong, width: 1);
        numColor = c.textMuted;
      }
    } else {
      // Intensity
      fill = _intensity(context, cell!.rate);
      numColor = cell!.rate >= 0.75 ? c.onAccent : c.textSecondary;
    }

    if (isSelected) {
      border = Border.all(color: c.textPrimary, width: 1.5);
    } else if (isToday && border == null) {
      border = Border.all(color: accent, width: 1.5);
    }

    final showFlame = mode == CalendarMode.streak &&
        cell!.win &&
        milestones.contains(cell!.runLength);

    return GestureDetector(
      onTap: isFuture ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(8),
                border: border,
              ),
              alignment: Alignment.center,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isToday &&
                          !isSelected &&
                          fill == Colors.transparent &&
                          !ribbonBehind
                      ? accent
                      : numColor,
                ),
              ),
            ),
            if (showFlame)
              Positioned(
                top: -1,
                right: -1,
                child: Icon(LucideIcons.flame, size: 10, color: c.onAccent),
              ),
          ],
        ),
      ),
    );
  }

  Color _intensity(BuildContext context, double rate) {
    final c = context.c;
    if (rate >= 0.95) return accent;
    if (rate >= 0.75) return accent.withValues(alpha: 0.62);
    if (rate >= 0.50) return accent.withValues(alpha: 0.40);
    if (rate >= 0.25) return accent.withValues(alpha: 0.22);
    if (rate > 0) return accent.withValues(alpha: 0.10);
    return c.surfaceElevated; // scheduled but 0% — stays visible
  }
}

/// Paints the rounded ribbon under consecutive win-days in a week row.
class _RibbonPainter extends CustomPainter {
  final List<CalendarDay?> week;
  final Color accent;
  _RibbonPainter({required this.week, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final colW = size.width / 7;
    final cell = colW < size.height ? colW : size.height;
    const inset = 2.5;
    final h = cell - inset * 2;
    if (h <= 0) return;
    final cy = size.height / 2;

    int i = 0;
    while (i < 7) {
      if (week[i]?.win == true) {
        int j = i;
        while (j + 1 < 7 && week[j + 1]?.win == true) {
          j++;
        }
        final left = i * colW + inset;
        final right = (j + 1) * colW - inset;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(left, cy - h / 2, right, cy + h / 2),
          Radius.circular(h / 2),
        );
        final glow = week
            .sublist(i, j + 1)
            .any((d) => d?.inCurrentRun == true);
        if (glow) {
          canvas.drawRRect(
            rect.inflate(2),
            Paint()
              ..color = accent.withValues(alpha: 0.28)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
        canvas.drawRRect(
          rect,
          Paint()..color = glow ? accent : accent.withValues(alpha: 0.78),
        );
        i = j + 1;
      } else {
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter old) =>
      old.week != week || old.accent != accent;
}

// ── Footer (legend / day detail) ───────────────────────────────────────────

class _Footer extends StatelessWidget {
  final CalendarMode mode;
  final Color accent;
  final DateTime? selected;
  final CalendarDay? cell;
  const _Footer({
    required this.mode,
    required this.accent,
    required this.selected,
    required this.cell,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    if (selected == null) {
      // Legend for intensity, prompt for streak.
      if (mode == CalendarMode.intensity) {
        return Row(
          children: [
            Text('less',
                style: AppType.meta.copyWith(color: c.textMuted, fontSize: 9.5)),
            const SizedBox(width: 5),
            ...[0.10, 0.22, 0.40, 0.62, 1.0].map((a) => Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: a),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                )),
            Text('more',
                style: AppType.meta.copyWith(color: c.textMuted, fontSize: 9.5)),
          ],
        );
      }
      return Row(
        children: [
          Icon(LucideIcons.calendarDays, size: 15, color: c.textMuted),
          const SizedBox(width: 8),
          Text('Tap a day for detail',
              style: AppType.meta.copyWith(color: c.textMuted)),
        ],
      );
    }

    final label = DateFormat('EEEE, MMM d').format(selected!);
    final n = DateTime.now();
    final isFuture = selected!.isAfter(DateTime(n.year, n.month, n.day));
    final pct = ((cell?.rate ?? 0) * 100).round();

    String status;
    Color statusColor = c.textMuted;
    if (isFuture) {
      status = 'Upcoming';
    } else if (cell == null || cell!.isRest) {
      status = 'Rest day — nothing scheduled';
    } else if (cell!.win) {
      status = mode == CalendarMode.streak
          ? 'Day ${cell!.runLength} of a streak · $pct%'
          : '$pct% done';
      statusColor = c.positive;
    } else {
      status = mode == CalendarMode.streak ? 'Streak broken · $pct%' : '$pct% done';
      statusColor = pct > 0 ? c.amber : c.textMuted;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(status,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        if (!isFuture && cell != null && !cell!.isRest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('$pct%',
                style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    fontFeatures: const [FontFeature.tabularFigures()])),
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

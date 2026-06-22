part of 'home_screen.dart';

/// Week strip — fixed Mon-Sun column headers above a horizontally pageable row
/// of dates. One swipe moves a whole week: the selected date jumps by exactly
/// seven days, keeping the same weekday slot, and every date-keyed card on the
/// page (score, tiles, fuel, task rail) reloads for that day. You can page back
/// indefinitely but never past the current week, and future days can't be
/// selected — you don't log days that haven't happened.
///
/// A month label tracks the week you're viewing, and a "Today" chip appears the
/// moment you drift off the current day so getting home is always one tap.
class _WeekStrip extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  const _WeekStrip({required this.selected, required this.onSelect});

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  // A fixed Monday far enough in the past to act as the page-index anchor.
  static final DateTime _epochMonday = DateTime(2020, 1, 6);
  late PageController _pc;
  late DateTime _viewedMonday;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _mondayOf(DateTime d) {
    final n = _dateOnly(d);
    return n.subtract(Duration(days: n.weekday - 1));
  }

  static int _pageFor(DateTime monday) =>
      monday.difference(_epochMonday).inDays ~/ 7;

  DateTime get _today => _dateOnly(DateTime.now());
  // The current week is the furthest page forward — no logging the future.
  int get _maxPage => _pageFor(_mondayOf(_today));

  @override
  void initState() {
    super.initState();
    _viewedMonday = _mondayOf(widget.selected);
    _pc = PageController(initialPage: _pageFor(_viewedMonday));
  }

  @override
  void didUpdateWidget(covariant _WeekStrip old) {
    super.didUpdateWidget(old);
    // Selection changed from outside this widget (e.g. the Today chip, or a
    // pull-to-refresh reset) → glide the page to its week.
    final newMonday = _mondayOf(widget.selected);
    if (newMonday != _viewedMonday) {
      _viewedMonday = newMonday;
      if (_pc.hasClients) {
        _pc.animateToPage(
          _pageFor(newMonday),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  /// On settle, carry the selection to the same weekday in the new week,
  /// clamped so it never lands on a future day.
  void _onPageChanged(int page) {
    final monday = _epochMonday.add(Duration(days: page * 7));
    setState(() => _viewedMonday = monday);
    var target = monday.add(Duration(days: widget.selected.weekday - 1));
    if (target.isAfter(_today)) target = _today;
    if (!_sameDay(target, widget.selected)) {
      HapticFeedback.selectionClick();
      widget.onSelect(target);
    }
  }

  void _jumpToToday() {
    HapticFeedback.selectionClick();
    widget.onSelect(_today);
  }

  String _monthLabel(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    if (monday.month == sunday.month) {
      return DateFormat('MMMM yyyy').format(monday).toUpperCase();
    }
    // Week straddles a boundary: drop the year on the left unless the years
    // also differ ("JUN – JUL 2026" vs "DEC 2025 – JAN 2026").
    final left = monday.year == sunday.year
        ? DateFormat('MMM').format(monday)
        : DateFormat('MMM yyyy').format(monday);
    final right = DateFormat('MMM yyyy').format(sunday);
    return '$left – $right'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const dows = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final offToday = !_sameDay(widget.selected, _today);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Context row — which week am I on, and a one-tap way back to today.
          SizedBox(
            height: 22,
            child: Row(
              children: [
                const SizedBox(width: 2),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Text(
                      _monthLabel(_viewedMonday),
                      key: ValueKey(_viewedMonday),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: offToday
                      ? _TodayChip(onTap: _jumpToToday)
                      : const SizedBox(height: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in dows)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: PageView.builder(
              controller: _pc,
              physics: const BouncingScrollPhysics(),
              itemCount: _maxPage + 1,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, page) {
                final weekMonday = _epochMonday.add(Duration(days: page * 7));
                return _WeekPage(
                  monday: weekMonday,
                  selected: widget.selected,
                  today: _today,
                  onTap: widget.onSelect,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayChip extends StatelessWidget {
  final VoidCallback onTap;
  const _TodayChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 4, 10, 4),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cornerUpLeft, size: 11, color: c.accent),
            const SizedBox(width: 4),
            Text(
              'Today',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: c.accent,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekPage extends StatelessWidget {
  final DateTime monday;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onTap;
  const _WeekPage({
    required this.monday,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    int? selectedIdx;
    for (int i = 0; i < 7; i++) {
      if (_sameDay(monday.add(Duration(days: i)), selected)) {
        selectedIdx = i;
        break;
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = constraints.maxWidth / 7;
        return Stack(
          children: [
            if (selectedIdx != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: selectedIdx * colWidth + 3,
                top: 4,
                width: colWidth - 6,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: List.generate(7, (i) {
                final d = monday.add(Duration(days: i));
                final on = i == selectedIdx;
                final isToday = _sameDay(d, today);
                final future = d.isAfter(today);
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Future days are visible for orientation but inert.
                    onTap: future
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            onTap(d);
                          },
                    child: SizedBox(
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w700,
                              color: on
                                  ? Colors.white
                                  : (future
                                      ? c.textMuted.withValues(alpha: 0.45)
                                      : c.textPrimary),
                              fontFeatures: const [FontFeature.tabularFigures()],
                              height: 1.0,
                            ),
                            child: Text('${d.day}'),
                          ),
                          if (isToday && !on)
                            Positioned(
                              bottom: 5,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

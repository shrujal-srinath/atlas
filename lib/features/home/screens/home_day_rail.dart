part of 'home_screen.dart';

// ════════════════════════════════════════════════════════════════════
// DAY RAIL — the day as one chronological track.
//
// A single time axis replaces the Up-Next hero + period accordions.
// Three row densities keep the whole day on screen:
//   · done     → 36px receipt row (strikethrough · DONE tag)
//   · pending  → compact card (icon, meta, rail node toggles it)
//   · in focus → expanded card with inline stepper + actions
// Exactly one card is expanded at a time. On today it auto-tracks the
// "up now" task (the last pending task whose slot time has arrived, else
// the next one coming); tapping another card moves focus, tapping the
// expanded header collapses. A NOW divider marks wall-clock position.
// ════════════════════════════════════════════════════════════════════

const double _kGutterW = 60; // time label + rail line + node
const double _kRailX = 47;   // x of the rail line's center inside the gutter

String _hhmmNow() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
}

int _periodRankOfNow() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return 0;
  if (h >= 12 && h < 17) return 1;
  if (h >= 17 && h < 21) return 2;
  return 3;
}

/// Whether [t]'s slot is later than the current wall clock. Untimed tasks
/// inherit their period's position (treated as that period's opening).
bool _isAfterNow(_TaskVM t) {
  final pr = _kPeriods.indexOf(t.period);
  final nr = _periodRankOfNow();
  if (pr != nr) return pr > nr;
  final tt = t.time.isEmpty ? '00:00' : t.time;
  return tt.compareTo(_hhmmNow()) > 0;
}

String _fmtNum(double v) {
  final r = v.toStringAsFixed(2);
  if (r.endsWith('.00')) return r.substring(0, r.length - 3);
  if (r.endsWith('0')) return r.substring(0, r.length - 1);
  return r;
}

/// Stepper increment per unit — one tap should feel like one meaningful rep.
double _stepFor(String? unit) => switch (unit) {
      'min' => 5,
      'km' => 0.5,
      'L' => 0.25,
      _ => 1,
    };

class _DayRail extends ConsumerStatefulWidget {
  final List<_TaskVM> tasks;
  final bool isToday;
  final ValueChanged<_TaskVM> onToggle;
  const _DayRail({
    required this.tasks,
    required this.isToday,
    required this.onToggle,
  });

  @override
  ConsumerState<_DayRail> createState() => _DayRailState();
}

class _DayRailState extends ConsumerState<_DayRail> {
  static const _kNone = '__none__';

  /// User-chosen expansion. Null = follow the auto "up now" target;
  /// [_kNone] = user collapsed everything.
  String? _override;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Re-seat the NOW divider + auto-expansion as the wall clock moves.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.isToday) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _DayRail old) {
    super.didUpdateWidget(old);
    // A manually-focused task that got completed (or filtered away) releases
    // focus back to the auto target.
    if (_override != null && _override != _kNone) {
      final t = widget.tasks.where((t) => t.id == _override).firstOrNull;
      if (t == null || t.done) _override = null;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  List<_TaskVM> _sorted() {
    final list = [...widget.tasks];
    list.sort((a, b) {
      final r =
          _kPeriods.indexOf(a.period).compareTo(_kPeriods.indexOf(b.period));
      if (r != 0) return r;
      return a.time.compareTo(b.time);
    });
    return list;
  }

  /// The task the rail spotlights when the user hasn't picked one: the last
  /// pending task whose slot time has arrived ("up now"), else the next
  /// pending one. Only today auto-focuses — past/future days open calm.
  _TaskVM? _autoTarget(List<_TaskVM> sorted) {
    if (!widget.isToday) return null;
    _TaskVM? due;
    _TaskVM? next;
    for (final t in sorted) {
      if (t.done || t.isRest) continue; // rested = handled, don't auto-spotlight
      if (_isAfterNow(t)) {
        next ??= t;
      } else {
        due = t;
      }
    }
    return due ?? next;
  }

  void _focus(String id) {
    HapticFeedback.selectionClick();
    setState(() => _override = id);
  }

  void _collapse() {
    HapticFeedback.selectionClick();
    setState(() => _override = _kNone);
  }

  void _openSheet(_TaskVM t) {
    final habit = t.habitRef;
    if (habit == null) return;
    final date = ref.read(selectedDateProvider);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    HapticFeedback.selectionClick();
    showHabitQuickSheet(context, habit, t.logRef, key);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sorted = _sorted();

    if (sorted.isEmpty) {
      return _Card(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Icon(LucideIcons.check, size: 20, color: c.positive),
            const SizedBox(height: 8),
            Text(
              'Nothing here — all clear.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final auto = _autoTarget(sorted);
    final String? expandedId = _override == _kNone
        ? null
        : (_override != null &&
                sorted.any((t) => t.id == _override && !t.done))
            ? _override
            : auto?.id;
    // A day is "all clear" when every task is either finished or rested.
    final allDone = sorted.every((t) => t.done || t.isRest);

    // Flatten into slots, then find where NOW belongs. If NOW lands on the
    // first task of a period, the divider goes above that period's header.
    final slots = <({String kind, String period, _TaskVM? task})>[];
    for (final p in _kPeriods) {
      final items = sorted.where((t) => t.period == p).toList();
      if (items.isEmpty) continue;
      slots.add((kind: 'header', period: p, task: null));
      for (final t in items) {
        slots.add((kind: 'task', period: p, task: t));
      }
    }
    int nowIdx = -1;
    if (widget.isToday) {
      nowIdx = slots.length;
      for (int i = 0; i < slots.length; i++) {
        final s = slots[i];
        if (s.kind == 'task' && _isAfterNow(s.task!)) {
          nowIdx = (i > 0 && slots[i - 1].kind == 'header') ? i - 1 : i;
          break;
        }
      }
    }

    final rows = <Widget>[];
    for (int i = 0; i <= slots.length; i++) {
      if (i == nowIdx) rows.add(const _NowRow());
      if (i == slots.length) break;
      final s = slots[i];
      if (s.kind == 'header') {
        final items = sorted.where((t) => t.period == s.period).toList();
        rows.add(_PeriodHeaderRow(
          period: s.period,
          done: items.where((t) => t.done).length,
          total: items.length,
        ));
      } else {
        final t = s.task!;
        if (t.done) {
          rows.add(_DoneRow(
            task: t,
            onTapNode: () => widget.onToggle(t),
            onTapRow: () => _openSheet(t),
          ));
        } else if (t.isRest && t.id != expandedId) {
          // A deliberate rest reads as a calm receipt — tap to reopen it (so the
          // user can finish or undo the rest via the expanded card).
          rows.add(_DoneRow(
            task: t,
            rested: true,
            onTapNode: () => _focus(t.id),
            onTapRow: () => _focus(t.id),
          ));
        } else if (t.id == expandedId) {
          rows.add(_ExpandedRow(
            key: ValueKey('exp-${t.id}'),
            task: t,
            tag: _override == null || _override == t.id && auto?.id == t.id
                ? (t.id == auto?.id
                    ? (_isAfterNow(t) ? 'NEXT' : 'UP NOW')
                    : null)
                : null,
            onCollapse: _collapse,
            onComplete: () => widget.onToggle(t),
            onNote: () => _openSheet(t),
            onTapNode: () => widget.onToggle(t),
          ));
        } else {
          rows.add(_CompactRow(
            task: t,
            onTap: () => _focus(t.id),
            onTapNode: () => widget.onToggle(t),
          ));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allDone) ...[
          const _AllClearBanner(),
          const SizedBox(height: 4),
        ],
        ...rows,
        const SizedBox(height: 2),
      ],
    );
  }
}

class _AllClearBanner extends StatelessWidget {
  const _AllClearBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.positive.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.positive.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle2, size: 16, color: c.positive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Day complete — every task is in.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Rail plumbing — gutter (time + line + node) beside a content cell.
// ────────────────────────────────────────────────────────────────────

class _RailRow extends StatelessWidget {
  final String? timeLabel;
  final Color? timeColor;
  final bool timeBold;
  final Widget node;
  final double nodeTop;     // y of the node's center within the row
  final double nodeSize;
  final VoidCallback? onTapNode;
  final Widget child;
  const _RailRow({
    required this.node,
    required this.nodeTop,
    required this.child,
    this.nodeSize = 22,
    this.timeLabel,
    this.timeColor,
    this.timeBold = false,
    this.onTapNode,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget gutterNode = node;
    if (onTapNode != null) {
      // 44dp invisible target around the visible node.
      gutterNode = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapNode,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: node,
        ),
      );
    }
    final hit = onTapNode != null ? 44.0 : nodeSize;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _kGutterW,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _kRailX - 0.75,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 1.5, color: c.border),
                ),
                if (timeLabel != null && timeLabel!.isNotEmpty)
                  Positioned(
                    left: 0,
                    width: _kRailX - 13,
                    top: nodeTop - 6,
                    child: Text(
                      timeLabel!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: timeBold ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0.2,
                        color: timeColor ?? c.textMuted,
                        height: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                Positioned(
                  left: _kRailX - hit / 2,
                  top: nodeTop - hit / 2,
                  child: gutterNode,
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Rail node: filled check (done) · pulsing ring (in focus) · hollow ring.
class _RailNode extends StatelessWidget {
  final Color color;
  final bool done;
  final bool live;
  const _RailNode({required this.color, this.done = false, this.live = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (done) {
      // Finished tasks recede: a soft tinted dot instead of a bright solid
      // node, so the eye lands on what's still pending.
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.check,
          size: 11,
          color: color.withValues(alpha: 0.85),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: c.background,
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: live ? 1.0 : 0.55),
          width: 2,
        ),
      ),
      child: live ? Center(child: _PulseDot(color: color)) : null,
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final v = Curves.easeInOut.transform(_ctrl.value);
        return Opacity(
          opacity: 0.55 + 0.45 * v,
          child: Transform.scale(
            scale: 0.75 + 0.35 * v,
            child: Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}

/// Wall-clock divider — glowing dot on the rail, sweep line across.
class _NowRow extends StatelessWidget {
  const _NowRow();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _RailRow(
      timeLabel: _hhmmNow(),
      timeColor: c.accent,
      timeBold: true,
      nodeTop: 13,
      nodeSize: 8,
      node: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.55),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      c.accent.withValues(alpha: 0.75),
                      c.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                'NOW',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: c.accent,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodHeaderRow extends StatelessWidget {
  final String period;
  final int done;
  final int total;
  const _PeriodHeaderRow({
    required this.period,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final complete = total > 0 && done == total;
    return _RailRow(
      nodeTop: 24,
      nodeSize: 20,
      node: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Icon(_periodIcon(period), size: 10, color: c.textMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 2, top: 16, bottom: 9, right: 2),
        child: Row(
          children: [
            _Overline(period, size: 9.5),
            const Spacer(),
            Text(
              '$done/$total',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: complete ? c.positive : c.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Row states.
// ────────────────────────────────────────────────────────────────────

/// Receipt line for a finished task — the day's history stays visible
/// without spending card-height on it.
class _DoneRow extends StatelessWidget {
  final _TaskVM task;
  final VoidCallback onTapNode;
  final VoidCallback onTapRow;
  /// Rested receipt variant — a neutral "Rest day" line instead of a struck-out
  /// completion. Used for flexible-count habits the user rested today.
  final bool rested;
  const _DoneRow({
    required this.task,
    required this.onTapNode,
    required this.onTapRow,
    this.rested = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Habit colour on the node keeps the receipt line subtly identifiable.
    final cat = _habitColorFor(context, task);
    return _RailRow(
      timeLabel: task.time,
      timeColor: c.textMuted.withValues(alpha: 0.5),
      nodeTop: 13,
      node: _RailNode(color: rested ? c.textMuted : cat, done: true),
      onTapNode: onTapNode,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapRow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 5, 2, 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  task.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: c.textMuted.withValues(alpha: 0.7),
                    decoration:
                        rested ? null : TextDecoration.lineThrough,
                    decorationColor: c.textMuted.withValues(alpha: 0.4),
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rested) ...[
                Icon(LucideIcons.coffee,
                    size: 11, color: c.textMuted.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text(
                  'Rest day',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                    height: 1.0,
                  ),
                ),
              ] else if (task.streak > 0) ...[
                Icon(LucideIcons.flame,
                    size: 9, color: c.amber.withValues(alpha: 0.55)),
                const SizedBox(width: 2),
                Text(
                  '${task.streak}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: c.amber.withValues(alpha: 0.55),
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Resting state for a pending task — one line of identity, one of context.
/// Tapping the card focuses it; tapping the rail node completes it outright.
class _CompactRow extends StatelessWidget {
  final _TaskVM task;
  final VoidCallback onTap;
  final VoidCallback onTapNode;
  const _CompactRow({
    required this.task,
    required this.onTap,
    required this.onTapNode,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // The habit's own colour, used subtly — the icon + the progress ring/node.
    final cat = _habitColorFor(context, task);
    final prio = _priorityIcon(task.priority);
    final hasPartial = task.isNumeric && (task.current ?? 0) > 0;
    return _RailRow(
      timeLabel: task.time,
      nodeTop: 30,
      node: _RailNode(color: cat),
      onTapNode: onTapNode,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 11),
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cat.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: cat.withValues(alpha: 0.22), width: 0.5),
                ),
                child: Icon(task.icon, size: 17, color: cat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: c.textPrimary,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // One quiet context line — the icon colour already says
                    // which section this is, so the category word is dropped.
                    Text(
                      _goalLabel(task),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: c.textMuted,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (task.streak > 0) ...[
                Icon(LucideIcons.flame, size: 12, color: c.amber),
                const SizedBox(width: 2),
                Text(
                  '${task.streak}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.amber,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (prio != null) ...[
                Icon(prio, size: 12,
                    color: _priorityColor(context, task.priority)),
                const SizedBox(width: 8),
              ],
              if (hasPartial)
                SizedBox(
                  width: 30,
                  height: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(30, 30),
                        painter: _RingPainter(
                          pct: task.ratio.clamp(0.0, 1.0),
                          color: cat,
                          track: c.surfaceElevated,
                          stroke: 3,
                        ),
                      ),
                      Text(
                        _fmtNum(task.current ?? 0),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          height: 1.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(LucideIcons.chevronRight, size: 16, color: c.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

String _goalLabel(_TaskVM t) {
  if (t.isNumeric) {
    final unit = t.unitLabel ?? '';
    return '${_fmtNum(t.target!)}${unit.isEmpty ? '' : ' $unit'}';
  }
  return 'one tap';
}

/// The spotlight card — everything needed to act without leaving the list:
/// inline stepper for numeric goals, complete, note, focus timer.
class _ExpandedRow extends ConsumerStatefulWidget {
  final _TaskVM task;
  final String? tag; // 'UP NOW' | 'NEXT' | null (manual focus)
  final VoidCallback onCollapse;
  final VoidCallback onComplete;
  final VoidCallback onNote;
  final VoidCallback onTapNode;
  const _ExpandedRow({
    super.key,
    required this.task,
    required this.tag,
    required this.onCollapse,
    required this.onComplete,
    required this.onNote,
    required this.onTapNode,
  });

  @override
  ConsumerState<_ExpandedRow> createState() => _ExpandedRowState();
}

class _ExpandedRowState extends ConsumerState<_ExpandedRow> {
  late double _value = widget.task.current ?? 0;
  bool _dirty = false;
  Timer? _commit;

  @override
  void didUpdateWidget(covariant _ExpandedRow old) {
    super.didUpdateWidget(old);
    if (old.task.id != widget.task.id) {
      _commit?.cancel();
      _dirty = false;
      _value = widget.task.current ?? 0;
    } else if (!_dirty) {
      _value = widget.task.current ?? 0;
    }
  }

  @override
  void dispose() {
    _commit?.cancel();
    if (_dirty) _persist();
    super.dispose();
  }

  String get _dateKey {
    final d = ref.read(selectedDateProvider);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _persist() {
    _dirty = false;
    final t = widget.task;
    ref.read(habitActionsProvider.notifier).toggleHabit(
          t.id,
          _dateKey,
          completed: _value >= (t.target ?? double.infinity) - 1e-9,
          actualValue: _value,
        );
  }

  void _bump(double delta) {
    final t = widget.task;
    final target = t.target ?? 0;
    final next = (_value + delta).clamp(0.0, target * 2);
    if (next == _value) return;
    final crossed = _value < target && next >= target;
    setState(() {
      _value = next;
      _dirty = true;
    });
    if (crossed) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    _commit?.cancel();
    _commit = Timer(const Duration(milliseconds: 500), _persist);
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    _commit?.cancel();
    _dirty = false;
    final t = widget.task;
    if (t.isNumeric) {
      final v = math.max(_value, t.target ?? 0);
      ref.read(habitActionsProvider.notifier).toggleHabit(
            t.id,
            _dateKey,
            completed: true,
            actualValue: v,
          );
    } else {
      widget.onComplete();
    }
  }

  void _openFocusTimer() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.c.background,
      builder: (_) => const FocusTimerSheet(),
    );
  }

  // Flexible "X / week" habits: mark today a deliberate rest (neutral) or undo.
  void _toggleRest() {
    HapticFeedback.selectionClick();
    _commit?.cancel();
    _dirty = false;
    ref
        .read(habitActionsProvider.notifier)
        .setRestDay(widget.task.id, _dateKey, rest: !widget.task.isRest);
  }

  /// The small neutral "Rest" button shown beside Finish for flexible-count
  /// habits (1 part to Finish's 3). Fills in when today is already a rest.
  Widget _restButton(AppPalette c, _TaskVM t) {
    final rested = t.isRest;
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: _toggleRest,
        style: FilledButton.styleFrom(
          backgroundColor: rested ? c.textSecondary : c.surfaceElevated,
          foregroundColor: rested ? Colors.white : c.textSecondary,
          elevation: 0,
          padding: EdgeInsets.zero,
          side: rested ? null : BorderSide(color: c.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.coffee, size: 15),
              const SizedBox(width: 5),
              Text(
                rested ? 'Resting' : 'Rest',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = widget.task;
    // The focus card earns its emphasis from the border, lift and accents
    // (brand ruby — keeps CTA contrast safe). The habit's own colour shows on
    // the leading icon for identity continuity with the compact row.
    final cat = c.accent;
    final hc = _habitColorFor(context, t);
    final prio = _priorityIcon(t.priority);
    final target = t.target ?? 0;
    final pct = target <= 0 ? 0.0 : (_value / target).clamp(0.0, 1.0);

    return _RailRow(
      timeLabel: t.time,
      timeColor: cat,
      timeBold: true,
      nodeTop: 34,
      node: _RailNode(color: cat, live: true),
      onTapNode: widget.onTapNode,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          // A clean surface keeps the title, meta and counter crisp. The
          // "live" state is carried by the coloured border, a soft lift
          // shadow, the icon and the accents — never a tint behind the text,
          // which is what muddied legibility before.
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: cat.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: cat.withValues(alpha: 0.16),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 9,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onCollapse,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hc.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(t.icon, size: 21, color: hc),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                t.name,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: c.textPrimary,
                                  height: 1.12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (prio != null) ...[
                              const SizedBox(width: 6),
                              Icon(prio, size: 12,
                                  color:
                                      _priorityColor(context, t.priority)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              _catName(t.cat).toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: c.textMuted,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              '  ·  ${_goalLabel(t)}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: c.textSecondary,
                                height: 1.0,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            if (t.streak > 0) ...[
                              const SizedBox(width: 8),
                              Icon(LucideIcons.flame,
                                  size: 11.5, color: c.amber),
                              const SizedBox(width: 2),
                              Text(
                                '${t.streak}d',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.amber,
                                  height: 1.0,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.tag != null)
                    _FocusTag(label: widget.tag!, color: cat)
                  else
                    Icon(LucideIcons.chevronUp,
                        size: 15, color: c.textMuted),
                ],
              ),
            ),
            if (t.isNumeric) ...[
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    _StepBtn(
                      icon: LucideIcons.minus,
                      onTap: () => _bump(-_stepFor(t.unitLabel)),
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _fmtNum(_value),
                                  style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                    height: 1.0,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                Text(
                                  ' / ${_fmtNum(target)}'
                                  '${(t.unitLabel ?? '').isEmpty ? '' : ' ${t.unitLabel}'}',
                                  style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.textMuted,
                                    height: 1.0,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Track is a faint tint of the category colour so
                            // the filled vs. remaining portion both read on the
                            // elevated surface — the old grey-on-grey track was
                            // invisible.
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: pct),
                                duration:
                                    const Duration(milliseconds: 240),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, _) =>
                                    LinearProgressIndicator(
                                  value: v,
                                  minHeight: 5,
                                  backgroundColor:
                                      cat.withValues(alpha: 0.15),
                                  valueColor:
                                      AlwaysStoppedAnimation(cat),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _StepBtn(
                      icon: LucideIcons.plus,
                      filled: true,
                      tint: cat,
                      onTap: () => _bump(_stepFor(t.unitLabel)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                // Finish takes 3 parts; the optional Rest button takes 1 — the
                // 3:1 split for flexible "X / week" habits.
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        backgroundColor: cat,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.button),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text(t.isNumeric ? 'Finish' : 'Complete'),
                    ),
                  ),
                ),
                if (t.isFlexibleCount) ...[
                  const SizedBox(width: 8),
                  Expanded(flex: 1, child: _restButton(c, t)),
                ],
                const SizedBox(width: 8),
                _SquareAction(
                  icon: LucideIcons.edit3,
                  onTap: widget.onNote,
                ),
                if (t.type == 'timer' && !t.isFlexibleCount) ...[
                  const SizedBox(width: 8),
                  _SquareAction(
                    icon: LucideIcons.timer,
                    onTap: _openFocusTimer,
                  ),
                ],
              ],
            ),
            if (t.isRest) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  Icon(LucideIcons.coffee, size: 13, color: c.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rest day — counts as neutral, your streak is safe.',
                      style: context.t.meta.copyWith(color: c.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color? tint;
  const _StepBtn({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled ? (tint ?? c.accent) : c.surface,
          borderRadius: BorderRadius.circular(11),
          border: filled ? null : Border.all(color: c.border, width: 0.5),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled ? Colors.white : c.textSecondary,
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Icon(icon, size: 18, color: c.textSecondary),
      ),
    );
  }
}

/// The "UP NOW" / "NEXT" marker on the spotlight card. UP NOW is the
/// act-on-it-right-now signal, so it reads as a solid filled badge; NEXT is
/// informational and stays tonal. Both lead with a dot so the eye catches the
/// state before reading the word.
class _FocusTag extends StatelessWidget {
  final String label;
  final Color color;
  const _FocusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final urgent = label == 'UP NOW';
    final fg = urgent ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: urgent ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: fg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// STAYING CLEAN — negative ("avoid") habits in their own group.
// Each day is clean by default; tapping a clean row logs a slip
// (`completed:false`), tapping a broken row undoes it.
// ════════════════════════════════════════════════════════════════════

String _negDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Consecutive clean days ending today for a negative habit — days with no
/// logged slip — bounded by the earliest tracked day so a brand-new habit
/// can't claim a huge streak.
int _negativeCleanStreak(String habitId, List<HabitLog> logs, DateTime now) {
  final mine = logs.where((l) => l.habitId == habitId).toList();
  if (mine.isEmpty) return 0;
  final slipDates = {for (final l in mine) if (!l.completed) l.date};
  var earliest = mine.first.date;
  for (final l in mine) {
    if (l.date.compareTo(earliest) < 0) earliest = l.date;
  }
  final today = DateTime(now.year, now.month, now.day);
  int streak = 0;
  for (int i = 0; i < 400; i++) {
    final key = _negDateKey(today.subtract(Duration(days: i)));
    if (key.compareTo(earliest) < 0) break;
    if (slipDates.contains(key)) break;
    streak++;
  }
  return streak;
}

class _StayingCleanGroup extends ConsumerWidget {
  final List<_TaskVM> tasks;
  const _StayingCleanGroup({required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final recent =
        ref.watch(recentHabitLogsProvider).valueOrNull ?? const <HabitLog>[];
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(LucideIcons.shieldOff, size: 13, color: c.negative),
            const SizedBox(width: 7),
            Text('STAYING CLEAN',
                style: AppType.overline
                    .copyWith(color: c.textMuted, letterSpacing: 1.3)),
          ],
        ),
        const SizedBox(height: 8),
        for (final t in tasks) ...[
          _NegativeRow(
              task: t, cleanStreak: _negativeCleanStreak(t.id, recent, now)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NegativeRow extends ConsumerWidget {
  final _TaskVM task;
  final int cleanStreak;
  const _NegativeRow({required this.task, required this.cleanStreak});

  bool get _broke => task.logRef != null && !task.logRef!.completed;

  String _dateKey(WidgetRef ref) => _negDateKey(ref.read(selectedDateProvider));

  Future<void> _setBroke(WidgetRef ref, bool broke) =>
      ref.read(habitActionsProvider.notifier).toggleHabit(
            task.id,
            _dateKey(ref),
            completed: !broke,
          );

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (_broke) {
      HapticFeedback.selectionClick();
      await _setBroke(ref, false); // undo → clean
      return;
    }
    final slip = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SlipSheet(name: task.name),
    );
    if (slip != true) return;
    HapticFeedback.mediumImpact();
    await _setBroke(ref, true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Slip logged · ${task.name}'),
        action:
            SnackBarAction(label: 'Undo', onPressed: () => _setBroke(ref, false)),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final broke = _broke;
    final accent = c.negative;
    return PressableScale(
      onTap: () => _onTap(context, ref),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: broke ? accent.withValues(alpha: 0.08) : c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: broke ? accent.withValues(alpha: 0.5) : c.border,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(LucideIcons.ban, size: 16, color: accent),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                      decoration: broke ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    broke
                        ? 'Broke today · tap to undo'
                        : cleanStreak > 0
                            ? '$cleanStreak ${cleanStreak == 1 ? "day" : "days"} clean'
                            : 'Clean today',
                    style: AppType.meta.copyWith(
                      color: broke ? accent : c.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (broke)
              Icon(LucideIcons.rotateCcw, size: 18, color: accent)
            else
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.positive.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.check, size: 15, color: c.positive),
              ),
          ],
        ),
      ),
    );
  }
}

/// Confirm sheet shown before logging a slip on a negative habit.
class _SlipSheet extends StatelessWidget {
  final String name;
  const _SlipSheet({required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 18 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Icon(LucideIcons.alertTriangle, size: 30, color: c.negative),
          const SizedBox(height: 12),
          Text('Log a slip?', style: context.t.h2),
          const SizedBox(height: 6),
          Text(
            'Marks today broken for “$name” and resets your clean streak. '
            'It costs points — but you can undo.',
            textAlign: TextAlign.center,
            style: AppType.meta.copyWith(color: c.textMuted, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.negative,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('I slipped',
                  style: TextStyle(
                      fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Stayed clean',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

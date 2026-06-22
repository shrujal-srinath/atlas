part of 'home_screen.dart';

class _LevelTile extends ConsumerWidget {
  final VoidCallback onTap;
  const _LevelTile({required this.onTap});

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final lvl = ref.watch(currentLevelProvider);
    final levelNum = lvl.level;
    final into = lvl.xpIntoLevel;
    final span = lvl.xpForNextLevel == 0 ? 1 : lvl.xpForNextLevel;
    final remaining = (span - into).clamp(0, span);
    final progress = lvl.progress;
    final todayDelta = ref.watch(todayLevelXpDeltaProvider);
    final streak = ref.watch(currentScoreStreakProvider).valueOrNull ?? 0;

    return _Card(
      onTap: onTap,
      padding: const EdgeInsets.all(11),
      child: SizedBox(
        height: 86,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Overline('Level $levelNum', size: 9),
                const Spacer(),
                if (streak > 0) ...[
                  Icon(LucideIcons.flame, size: 12, color: c.amber),
                  const SizedBox(width: 2),
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.amber,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ] else
                  Icon(LucideIcons.zap, size: 14, color: c.accent),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmt(into),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: c.textPrimary,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    'xp',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: c.surfaceElevated,
                valueColor: AlwaysStoppedAnimation(c.accent),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    todayDelta > 0
                        ? '+$todayDelta XP today'
                        : '$remaining to L${levelNum + 1}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight:
                          todayDelta > 0 ? FontWeight.w700 : FontWeight.w500,
                      color: todayDelta > 0 ? c.accent : c.textMuted,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 14, color: c.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiTile extends ConsumerStatefulWidget {
  const _MultiTile();
  @override
  ConsumerState<_MultiTile> createState() => _MultiTileState();
}

class _MultiTileState extends ConsumerState<_MultiTile> {
  int _i = 0;
  Timer? _t;
  static const _faces = ['c', 't', 'r'];

  /// Each face deep-links to its own destination (not one shared page):
  /// consistency → Trends, to-do → the (WIP) tasks section, reminder → the
  /// specific habit/note it belongs to.
  void _open(String face, String? reminderRoute) {
    HapticFeedback.selectionClick();
    switch (face) {
      case 'c':
        context.push('/stats/trends');
      case 't':
        context.push('/todo');
      default:
        context.push(reminderRoute ?? '/notifications');
    }
  }

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _faces.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final selDate = ref.watch(selectedDateProvider);
    final week = ref.watch(homeWeekProvider(selDate)).valueOrNull ??
        const <HomeWeekDay>[];
    final tasks = ref.watch(homeTasksProvider(selDate)).valueOrNull ??
        const <HomeTask>[];
    final reminders = ref.watch(upcomingRemindersProvider).valueOrNull ??
        const <UpcomingReminder>[];
    final face = _faces[_i];
    final (icon, label) = switch (face) {
      'c' => (LucideIcons.grid, 'Consistency'),
      't' => (LucideIcons.checkSquare, 'To-do'),
      _ => (LucideIcons.bell, 'Reminder'),
    };
    final reminderRoute = reminders.isNotEmpty ? reminders.first.route : null;
    return InkWell(
      onTap: () => _open(face, reminderRoute),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.34),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 11,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          height: 86,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_faces.length, (k) {
                      final active = k == _i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(left: 3),
                        width: active ? 10 : 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    key: ValueKey(face),
                    alignment: Alignment.topLeft,
                    child: _faceContent(face, week, tasks, reminders),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faceContent(String face, List<HomeWeekDay> week,
      List<HomeTask> tasks, List<UpcomingReminder> reminders) {
    return switch (face) {
      'c' => _consistencyFace(week),
      't' => _todoFace(tasks),
      _ => _reminderFace(reminders),
    };
  }

  static const _bigNum = TextStyle(
    fontFamily: 'Inter',
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: Colors.white,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Consistency: share of this week's scheduled (non-future) days that had any
  // completion, plus a 7-dot week strip.
  Widget _consistencyFace(List<HomeWeekDay> week) {
    final active = week.where((d) => !d.isFuture && d.total > 0).toList();
    final hit = active.where((d) => d.done > 0).length;
    final pct = active.isEmpty ? 0 : ((hit / active.length) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$pct', style: _bigNum),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.0,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'this week',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: List.generate(7, (i) {
            final filled =
                i < week.length && !week[i].isFuture && week[i].done > 0;
            return Padding(
              padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.32),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // To-do: how many of today's tasks are still pending + the next one up.
  Widget _todoFace(List<HomeTask> tasks) {
    final pending = tasks.where((t) => !t.isCompleted).toList();
    final left = pending.length;
    final next = pending.where((t) => t.time.isNotEmpty).firstOrNull ??
        pending.firstOrNull;
    final sub = left == 0
        ? 'All done — nice work'
        : next == null
            ? 'Tap to view your tasks'
            : 'Next · ${next.habit.name}'
                '${next.time.isNotEmpty ? ' · ${next.time}' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$left', style: _bigNum),
            const SizedBox(width: 6),
            Text(
              'left today',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  // Reminder: the next upcoming reminder (habit/note/water), or an all-clear.
  Widget _reminderFace(List<UpcomingReminder> reminders) {
    final r = reminders.isEmpty ? null : reminders.first;
    final title = r?.title ?? 'No upcoming reminders';
    final sub = r == null
        ? "You're all set"
        : [
            if ((r.timeLabel ?? '').isNotEmpty) r.timeLabel!,
            if ((r.subtitle ?? '').isNotEmpty) r.subtitle!,
          ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          sub.isEmpty ? 'Scheduled' : sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

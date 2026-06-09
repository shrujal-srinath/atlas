import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../food/providers/food_providers.dart';
import '../../food/scoring/nutrition_score.dart';
import '../../habits/providers/habit_provider.dart';
import '../../journal/widgets/wellness_check_in_card.dart';
import '../../notifications/reminder_feed_provider.dart';
import '../../xp/leveling_providers.dart';
import '../providers/home_providers.dart';
import '../providers/ticker_provider.dart';
import '../widgets/habit_log_modal.dart';

// ════════════════════════════════════════════════════════════════════
// BENTO HOME — pixel-accurate port of app-home.jsx (Compact Stadium).
// Renders with mock data; clickable areas route to placeholders for now.
// ════════════════════════════════════════════════════════════════════

class _MockDay {
  final String d;
  final int n;
  final int score;
  final int done;
  final int total;
  final Map<String, int> cats; // ATH / MIND / BODY
  const _MockDay({
    required this.d,
    required this.n,
    required this.score,
    required this.done,
    required this.total,
    required this.cats,
  });
}

const _kDays = <_MockDay>[
  _MockDay(d: 'W', n: 27, score: 88, done: 6, total: 6, cats: {'ATH': 100, 'MIND': 100, 'BODY': 100}),
  _MockDay(d: 'T', n: 28, score: 74, done: 5, total: 7, cats: {'ATH': 100, 'MIND': 67, 'BODY': 50}),
  _MockDay(d: 'F', n: 29, score: 61, done: 4, total: 7, cats: {'ATH': 50, 'MIND': 67, 'BODY': 50}),
  _MockDay(d: 'S', n: 30, score: 65, done: 3, total: 8, cats: {'ATH': 100, 'MIND': 33, 'BODY': 50}),
  _MockDay(d: 'S', n: 31, score: 0, done: 0, total: 6, cats: {'ATH': 0, 'MIND': 0, 'BODY': 0}),
  _MockDay(d: 'M', n: 1, score: 0, done: 0, total: 7, cats: {'ATH': 0, 'MIND': 0, 'BODY': 0}),
  _MockDay(d: 'T', n: 2, score: 0, done: 0, total: 5, cats: {'ATH': 0, 'MIND': 0, 'BODY': 0}),
];

class _MockTask {
  final String id;
  final String period;
  final String name;
  final String time;
  final String cat;
  final String type;
  final int? duration;
  final double? target;
  final double? current;
  final int streak;
  final bool done;
  final IconData icon;
  final HabitPriority priority;
  /// Underlying habit (null for the seed mock data).
  final Habit? habitRef;
  final HabitLog? logRef;
  /// Numeric-goal unit label ('reps', 'min', 'km', 'L') — used for the
  /// "12 / 20 reps · 60%" sub-line on numeric task cards.
  final String? unitLabel;
  const _MockTask({
    required this.id,
    required this.period,
    required this.name,
    required this.time,
    required this.cat,
    required this.type,
    this.duration,
    this.target,
    this.current,
    this.streak = 0,
    this.done = false,
    required this.icon,
    this.priority = HabitPriority.normal,
    this.habitRef,
    this.logRef,
    this.unitLabel,
  });

  /// Completion ratio in `[0, 1.1]`. 0 if numeric and no target, 1 if done.
  double get ratio {
    if (target != null && target! > 0 && current != null) {
      final r = current! / target!;
      if (r >= 1.10) return 1.10;
      if (r < 0) return 0;
      return r;
    }
    return done ? 1.0 : 0.0;
  }

  bool get isNumeric => target != null && target! > 0;
}

const _kTasks = <_MockTask>[
  _MockTask(id: 't1', period: 'MORNING', name: 'Morning run', time: '06:30', cat: 'ATH', type: 'timer', duration: 30, streak: 12, done: true, icon: LucideIcons.footprints),
  _MockTask(id: 't2', period: 'MORNING', name: 'Meditate', time: '07:30', cat: 'MIND', type: 'timer', duration: 10, streak: 24, done: true, icon: LucideIcons.moon),
  _MockTask(id: 't3', period: 'MORNING', name: 'Protein breakfast', time: '08:30', cat: 'BODY', type: 'check', streak: 6, done: true, icon: LucideIcons.droplet),
  _MockTask(id: 't4', period: 'AFTERNOON', name: 'Read 20 pages', time: '13:00', cat: 'MIND', type: 'reps', target: 20.0, current: 12.0, streak: 9, icon: LucideIcons.bookOpen),
  _MockTask(id: 't5', period: 'AFTERNOON', name: 'Gym · push day', time: '15:30', cat: 'ATH', type: 'timer', duration: 60, icon: LucideIcons.dumbbell, priority: HabitPriority.critical),
  _MockTask(id: 't6', period: 'EVENING', name: 'No phone after 10', time: '22:00', cat: 'BODY', type: 'check', streak: 4, icon: LucideIcons.smartphone, priority: HabitPriority.high),
  _MockTask(id: 't7', period: 'EVENING', name: 'Journal', time: '22:30', cat: 'MIND', type: 'check', streak: 14, icon: LucideIcons.edit3),
  _MockTask(id: 't8', period: 'NIGHT', name: 'Lights out', time: '23:00', cat: 'BODY', type: 'check', streak: 3, icon: LucideIcons.moon),
];

const _kPeriods = ['MORNING', 'AFTERNOON', 'EVENING', 'NIGHT'];

Color _catColor(BuildContext context, String key) {
  final c = context.c;
  return switch (key) {
    'ATH' => c.athletic,
    'MIND' => c.mind,
    'BODY' => c.body,
    _ => c.textMuted,
  };
}

/// Icon for the high/critical priority marker on a task card. Returns null for
/// low/normal — we deliberately hide the indicator there to keep the card calm.
IconData? _priorityIcon(HabitPriority p) => switch (p) {
      HabitPriority.high => LucideIcons.chevronsUp,
      HabitPriority.critical => LucideIcons.alertTriangle,
      _ => null,
    };

Color _priorityColor(BuildContext context, HabitPriority p) {
  final c = context.c;
  return switch (p) {
    HabitPriority.high => c.amber,
    HabitPriority.critical => c.negative,
    _ => c.textMuted,
  };
}

String _catKeyFor(HabitSection s) => switch (s) {
      HabitSection.athletic => 'ATH',
      HabitSection.mind => 'MIND',
      HabitSection.body => 'BODY',
    };

_MockDay _weekDayToMock(HomeWeekDay d) => _MockDay(
      d: d.dowLabel,
      n: d.dayNum,
      score: d.score,
      done: d.done,
      total: d.total,
      cats: {
        'ATH': d.sectionPct[HabitSection.athletic] ?? 0,
        'MIND': d.sectionPct[HabitSection.mind] ?? 0,
        'BODY': d.sectionPct[HabitSection.body] ?? 0,
      },
    );

_MockTask _homeTaskToMock(HomeTask t) {
  final h = t.habit;
  final type = switch (h.goalType) {
    GoalType.reps => 'reps',
    GoalType.durationMin => 'timer',
    _ => 'check',
  };
  // Numeric tasks expose the live actual_value so the card can show "12 / 20".
  final isNumeric = h.goalType != null && (h.goalValue ?? 0) > 0;
  return _MockTask(
    id: h.id,
    period: t.period,
    name: h.name,
    time: t.time,
    cat: _catKeyFor(h.section),
    type: type,
    duration: h.goalType == GoalType.durationMin ? h.goalValue?.toInt() : null,
    target: isNumeric ? h.goalValue : null,
    current: isNumeric ? (t.log?.actualValue ?? (t.isCompleted ? h.goalValue : 0)) : null,
    streak: t.streak,
    done: t.isCompleted,
    icon: habitIcon(h.icon),
    priority: h.priority,
    habitRef: h,
    logRef: t.log,
    unitLabel: h.goalType == null ? null : _unitLabelFor(h.goalType!),
  );
}

String _unitLabelFor(GoalType t) => switch (t) {
      GoalType.reps => 'reps',
      GoalType.durationMin => 'min',
      GoalType.distanceKm => 'km',
      GoalType.litres => 'L',
      GoalType.custom => '',
    };

String _catName(String key) => switch (key) {
      'ATH' => 'Athletic',
      'MIND' => 'Mind',
      'BODY' => 'Body',
      _ => '',
    };

IconData _periodIcon(String p) => switch (p) {
      'MORNING' => LucideIcons.sunrise,
      'AFTERNOON' => LucideIcons.sun,
      _ => LucideIcons.moon,
    };

String _greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Still up';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 21) return 'Good evening';
  return 'Good night';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _filter = 'all';

  // Greeting auto-collapses 1.5s after the screen mounts to reclaim space.
  // Once collapsed, it stays collapsed for the rest of the session — only a
  // pull-to-refresh (or reopening the app) reveals it again.
  Timer? _greetingTimer;
  bool _showGreeting = true;

  @override
  void initState() {
    super.initState();
    _armGreetingCollapse();
  }

  void _armGreetingCollapse() {
    _greetingTimer?.cancel();
    _greetingTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _showGreeting = false);
    });
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _showGreeting = true);
    _armGreetingCollapse();
    final date = ref.read(selectedDateProvider);
    ref.invalidate(homeWeekProvider(date));
    ref.invalidate(homeTasksProvider(date));
    ref.invalidate(homeScoreProvider(date));
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  Future<void> _complete(String habitId) async {
    HapticFeedback.lightImpact();
    final date = ref.read(selectedDateProvider);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await ref.read(habitActionsProvider.notifier).toggleHabit(habitId, key);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final selDate = ref.watch(selectedDateProvider);
    final weekAsync = ref.watch(homeWeekProvider(selDate));
    final tasksAsync = ref.watch(homeTasksProvider(selDate));
    final scoreAsync = ref.watch(homeScoreProvider(selDate));

    // Convert real data → display shapes. Falls back to mocks while loading
    // so the layout never thrashes.
    final week = weekAsync.valueOrNull;
    final realDays = (week == null || week.isEmpty)
        ? _kDays
        : week.map(_weekDayToMock).toList();
    final selIdx = week == null
        ? 3
        : week.indexWhere((d) =>
            d.date.year == selDate.year &&
            d.date.month == selDate.month &&
            d.date.day == selDate.day);
    final selDayIdx = selIdx < 0 ? 3 : selIdx;

    final realTasks = tasksAsync.valueOrNull?.map(_homeTaskToMock).toList();
    final List<_MockTask> tasks = realTasks ?? _kTasks;
    final day = realDays[selDayIdx];

    final counts = <String, int>{
      'all': tasks.length,
      for (final p in _kPeriods) p: tasks.where((t) => t.period == p).length,
      'incomplete': tasks.where((t) => !t.done).length,
    };
    final filtered = _filter == 'all'
        ? null
        : _filter == 'incomplete'
            ? tasks.where((t) => !t.done).toList()
            : tasks.where((t) => t.period == _filter).toList();

    // Use the provider score if available (more accurate than per-day arc data).
    final scoreOverride = scoreAsync.valueOrNull;
    final dayForScore = scoreOverride == null
        ? day
        : _MockDay(
            d: day.d,
            n: day.n,
            score: scoreOverride.score,
            done: scoreOverride.done,
            total: scoreOverride.total,
            cats: {
              'ATH': scoreOverride.sectionPct[HabitSection.athletic] ?? 0,
              'MIND': scoreOverride.sectionPct[HabitSection.mind] ?? 0,
              'BODY': scoreOverride.sectionPct[HabitSection.body] ?? 0,
            },
          );

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: c.accent,
          backgroundColor: c.surface,
          edgeOffset: 8,
          displacement: 28,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 118),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              _Header(
                onBell: () => context.push('/notifications'),
                showGreeting: _showGreeting,
              ),
              const SizedBox(height: 10),
              const _NotifBanner(),
              const SizedBox(height: 10),
              _WeekStrip(
                selected: selDate,
                onSelect: (d) =>
                    ref.read(selectedDateProvider.notifier).state = d,
              ),
              const SizedBox(height: 7),
              _ScoreBlock(day: dayForScore, onTap: () => context.push('/stats/score')),
              const SizedBox(height: 6),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _LevelTile(
                        onTap: () => context.push('/stats/progression'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _MultiTile(
                        onTap: () => context.push('/stats/glance'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _FuelCard(onTap: () => context.go('/food')),
              const SizedBox(height: 8),
              const WellnessCheckInCard(flush: true),
              const SizedBox(height: 11),
              _FilterPills(
                value: _filter,
                counts: counts,
                onChange: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 16),
              if (filtered != null)
                _FilteredList(tasks: filtered, onComplete: _complete)
              else
                ..._kPeriods.map((p) {
                  final items = tasks.where((t) => t.period == p).toList();
                  if (items.isEmpty) return const SizedBox.shrink();
                  final dn = items.where((t) => t.done).length;
                  return _PeriodGroup(
                    period: p,
                    done: dn,
                    total: items.length,
                    tasks: items,
                    onComplete: _complete,
                  );
                }),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final VoidCallback onBell;
  final bool showGreeting;
  const _Header({required this.onBell, this.showGreeting = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final unread = ref.watch(bellBadgeCountProvider);
    // Bell shrinks when the greeting collapses, so the whole row contracts and
    // we actually reclaim vertical pixels (otherwise the bell pins the row).
    final bellSize = showGreeting ? 42.0 : 30.0;
    final bellRadius = showGreeting ? 13.0 : 9.0;
    final bellIconSize = showGreeting ? 19.0 : 15.0;
    final now = DateTime.now();
    final dateLabel =
        DateFormat('EEEE · d MMM').format(now).toUpperCase();
    final greeting = _greetingFor(now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: c.textMuted,
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: showGreeting
                        ? Padding(
                            key: const ValueKey('greeting-on'),
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              '$greeting, Shrujal',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: c.textPrimary,
                                height: 1.0,
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('greeting-off'),
                            width: double.infinity,
                            height: 0,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          width: bellSize,
          height: bellSize,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(bellRadius),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 7,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(bellRadius),
            child: InkWell(
              onTap: onBell,
              borderRadius: BorderRadius.circular(bellRadius),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(LucideIcons.bell,
                      size: bellIconSize, color: c.textSecondary),
                  if (unread > 0)
                    Positioned(
                      top: showGreeting ? 9 : 6,
                      right: showGreeting ? 10 : 7,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.accent,
                          border: Border.all(color: c.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotifBanner extends ConsumerStatefulWidget {
  const _NotifBanner();
  @override
  ConsumerState<_NotifBanner> createState() => _NotifBannerState();
}

class _NotifBannerState extends ConsumerState<_NotifBanner> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 3400), (_) {
      if (!mounted) return;
      final n = ref.read(tickerLinesProvider).length;
      if (n > 0) setState(() => _i = (_i + 1) % n);
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
    final lines = ref.watch(tickerLinesProvider);
    if (lines.isEmpty) return const SizedBox.shrink();
    final idx = _i % lines.length;
    final f = lines[idx];
    final tc = f.tone == TickerTone.warn
        ? c.amber
        : f.tone == TickerTone.accent
            ? c.accent
            : c.textSecondary;
    return InkWell(
      onTap: f.routeTo == null ? null : () => context.push(f.routeTo!),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 9,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(f.icon, size: 14, color: tc),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  f.text,
                  key: ValueKey(idx),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(lines.length, (k) {
              final active = k == idx;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(left: 4),
                width: active ? 12 : 5,
                height: 4,
                decoration: BoxDecoration(
                  color: active ? c.accent : c.borderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Week strip: fixed Mon-Sun column headers + a horizontally pageable row of
/// dates. The accent pill slides smoothly under the tapped date; swiping left
/// or right pages a full week at a time.
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

  static DateTime _mondayOf(DateTime d) {
    final n = DateTime(d.year, d.month, d.day);
    return n.subtract(Duration(days: n.weekday - 1));
  }

  static int _pageFor(DateTime monday) =>
      monday.difference(_epochMonday).inDays ~/ 7;

  @override
  void initState() {
    super.initState();
    _viewedMonday = _mondayOf(widget.selected);
    _pc = PageController(initialPage: _pageFor(_viewedMonday));
  }

  @override
  void didUpdateWidget(covariant _WeekStrip old) {
    super.didUpdateWidget(old);
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const dows = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 8, 5, 6),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
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
            height: 38,
            child: PageView.builder(
              controller: _pc,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (page) {
                final monday = _epochMonday.add(Duration(days: page * 7));
                setState(() => _viewedMonday = monday);
              },
              itemBuilder: (context, page) {
                final weekMonday =
                    _epochMonday.add(Duration(days: page * 7));
                return _WeekPage(
                  monday: weekMonday,
                  selected: widget.selected,
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

class _WeekPage extends StatelessWidget {
  final DateTime monday;
  final DateTime selected;
  final ValueChanged<DateTime> onTap;
  const _WeekPage({
    required this.monday,
    required this.selected,
    required this.onTap,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
                top: 3,
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
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(d);
                    },
                    child: SizedBox(
                      height: 38,
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
                                  : (future ? c.textMuted : c.textPrimary),
                              fontFeatures: const [FontFeature.tabularFigures()],
                              height: 1.0,
                            ),
                            child: Text('${d.day}'),
                          ),
                          if (isToday && !on)
                            Positioned(
                              bottom: 4,
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

class _ScoreBlock extends StatelessWidget {
  final _MockDay day;
  final VoidCallback onTap;
  const _ScoreBlock({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Card(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 116,
            height: 116,
            child: CustomPaint(
              painter: _TripleArcPainter(
                values: [
                  day.cats['ATH']! / 100,
                  day.cats['MIND']! / 100,
                  day.cats['BODY']! / 100,
                ],
                colors: [c.athletic, c.mind, c.body],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${day.score}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.8,
                        color: c.textPrimary,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const _Overline('Score'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _Overline('Standing'),
                    const Spacer(),
                    Text(
                      'proj 84%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, size: 15, color: c.textMuted),
                  ],
                ),
                const SizedBox(height: 9),
                _catRow(context, 'ATH', day.cats['ATH']!),
                const SizedBox(height: 8),
                _catRow(context, 'MIND', day.cats['MIND']!),
                const SizedBox(height: 8),
                _catRow(context, 'BODY', day.cats['BODY']!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MicroPill(
                      text: '${day.done}/${day.total} done',
                      color: c.textMuted,
                    ),
                    const SizedBox(width: 6),
                    _MicroPill(
                      icon: LucideIcons.flame,
                      text: '3d',
                      color: c.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catRow(BuildContext context, String key, int pct) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _catColor(context, key),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _catName(key),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
              height: 1.0,
            ),
          ),
        ),
        Text(
          '$pct%',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _TripleArcPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _TripleArcPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 42.0;
    const segAng = 120.0;
    const gap = 22.0;
    final fullSweep = (segAng - gap) * math.pi / 180;

    for (int i = 0; i < values.length; i++) {
      final rotDeg = -90 + i * segAng + gap / 2;
      final startRad = rotDeg * math.pi / 180;
      final filledSweep = fullSweep * values[i].clamp(0.0, 1.0);

      final trackPaint = Paint()
        ..color = colors[i].withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startRad,
        fullSweep,
        false,
        trackPaint,
      );

      if (filledSweep > 0) {
        final fillPaint = Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          startRad,
          filledSweep,
          false,
          fillPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TripleArcPainter old) =>
      old.values != values || old.colors != colors;
}

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
                Text(
                  '$remaining to L${levelNum + 1}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: c.textMuted,
                    height: 1.0,
                  ),
                ),
                const Spacer(),
                Icon(LucideIcons.chevronRight, size: 14, color: c.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiTile extends StatefulWidget {
  final VoidCallback onTap;
  const _MultiTile({required this.onTap});
  @override
  State<_MultiTile> createState() => _MultiTileState();
}

class _MultiTileState extends State<_MultiTile> {
  int _i = 0;
  Timer? _t;
  static const _faces = ['c', 't', 'r'];

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
    final face = _faces[_i];
    final (icon, label) = switch (face) {
      'c' => (LucideIcons.grid, 'Consistency'),
      't' => (LucideIcons.checkSquare, 'To-do'),
      _ => (LucideIcons.bell, 'Reminder'),
    };
    return InkWell(
      onTap: widget.onTap,
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
                    child: _faceContent(face),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faceContent(String face) {
    if (face == 'c') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '92',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Colors.white,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
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
              final filled = i != 3;
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
    if (face == 't') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '4',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Colors.white,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
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
            'Next · Gym push · 3 PM',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Physio session',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Today · 6:00 PM',
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

class _FuelCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _FuelCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final totals = ref.watch(diaryTotalsProvider);
    final targets = ref.watch(dailyTargetsProvider);
    final waterMl = ref.watch(waterIntakeProvider).valueOrNull ?? 0;
    final waterTargetMl = ref.watch(waterTargetProvider);
    final phase = ref.watch(bodyPhaseProvider);

    final kcal = totals.kcal.round();
    final kgoal = targets.kcal.round() == 0 ? 3000 : targets.kcal.round();
    final macros = [
      ('Protein', totals.proteinG.round(), targets.proteinG.round(), c.body),
      ('Carbs', totals.carbsG.round(), targets.carbsG.round(), c.mind),
      ('Fat', totals.fatG.round(), targets.fatG.round(), c.athletic),
    ];

    // Phase-aware delta + tone matching the diary hero card semantics.
    final delta = _fuelDelta(phase, kcal: kcal, kgoal: kgoal);

    return _Card(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(kcal),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: c.textPrimary,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  '/ ${_fmt(kgoal)} kcal',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                    height: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              _FuelPhasePill(phase: phase),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.fromLTRB(9, 4, 7, 4),
                decoration: BoxDecoration(
                  color: _fuelDeltaTint(c, delta.tone).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      delta.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _fuelDeltaTint(c, delta.tone),
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight,
                        size: 13, color: c.textMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _fuelPaceHint(phase, kcal: kcal, kgoal: kgoal),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: c.textMuted,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 9),
          // Macro bar + chips, full-width now that water has its own row.
          SizedBox(
            height: 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Row(
                children: [
                  for (final m in macros) ...[
                    Expanded(
                      flex: ((m.$2 / kgoal) * 4 * 1000).round().clamp(1, 1 << 20),
                      child: Container(color: m.$4),
                    ),
                    const SizedBox(width: 2),
                  ],
                  Expanded(
                    flex: ((1 - kcal / kgoal) * 1.2 * 1000).round().clamp(1, 1 << 20),
                    child: Container(color: c.surfaceElevated),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < macros.length; i++) ...[
                Expanded(child: _macroMini(context, macros[i])),
                if (i < macros.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          // Hairline divider before the hydration row.
          const SizedBox(height: 10),
          Container(height: 0.5, color: c.border),
          const SizedBox(height: 10),
          _FuelWaterRow(
            waterMl: waterMl,
            waterTargetMl: waterTargetMl,
          ),
        ],
      ),
    );
  }

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  Widget _macroMini(BuildContext context, (String, int, int, Color) m) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: m.$4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              m.$1,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${m.$2}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
            Text(
              '/${m.$3}g',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Phase-aware delta + tone for the fuel-card calorie pill.
enum _FuelTone { positive, warn, negative, neutral }

class _FuelDelta {
  final String label;
  final _FuelTone tone;
  const _FuelDelta(this.label, this.tone);
}

_FuelDelta _fuelDelta(BodyPhase phase, {required int kcal, required int kgoal}) {
  final remaining = kgoal - kcal;
  switch (phase) {
    case BodyPhase.bulk:
      if (kcal < kgoal) return _FuelDelta('+$remaining to go', _FuelTone.warn);
      final over = kcal - kgoal;
      return _FuelDelta('+$over surplus', _FuelTone.positive);
    case BodyPhase.cut:
      if (kcal <= kgoal) return _FuelDelta('$remaining left', _FuelTone.positive);
      final over = kcal - kgoal;
      return _FuelDelta('-$over over', _FuelTone.negative);
    case BodyPhase.maintain:
      if (kcal <= kgoal) return _FuelDelta('$remaining left', _FuelTone.neutral);
      final over = kcal - kgoal;
      return _FuelDelta('-$over over', _FuelTone.warn);
  }
}

Color _fuelDeltaTint(AppPalette c, _FuelTone t) {
  return switch (t) {
    _FuelTone.positive => c.accent,
    _FuelTone.warn => c.amber,
    _FuelTone.negative => c.negative,
    _FuelTone.neutral => c.textSecondary,
  };
}

String _fuelPaceHint(BodyPhase phase, {required int kcal, required int kgoal}) {
  final phaseLabel = switch (phase) {
    BodyPhase.bulk => 'Bulk',
    BodyPhase.cut => 'Cut',
    BodyPhase.maintain => 'Maintain',
  };
  if (kgoal <= 0) return phaseLabel;
  final now = DateTime.now();
  final minsIntoDay = now.hour * 60 + now.minute;
  // Linear waking pace: 7am → 11pm. Outside that window, fall back to ratio.
  const wakeStartMin = 7 * 60;
  const wakeEndMin = 23 * 60;
  final wakingFrac = minsIntoDay <= wakeStartMin
      ? 0.0
      : minsIntoDay >= wakeEndMin
          ? 1.0
          : (minsIntoDay - wakeStartMin) / (wakeEndMin - wakeStartMin);
  final expected = (kgoal * wakingFrac).round();
  if (expected == 0) {
    return '$phaseLabel · day just starting';
  }
  final diff = kcal - expected;
  if (diff.abs() <= (kgoal * 0.05)) {
    return '$phaseLabel · on pace';
  }
  if (diff > 0) {
    return '$phaseLabel · ${diff.abs()} ahead of pace';
  }
  return '$phaseLabel · ${diff.abs()} behind pace';
}

class _FuelPhasePill extends StatelessWidget {
  final BodyPhase phase;
  const _FuelPhasePill({required this.phase});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, color) = switch (phase) {
      BodyPhase.bulk => ('BULK', c.athletic),
      BodyPhase.cut => ('CUT', c.mind),
      BodyPhase.maintain => ('KEEP', c.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Hydration row that lives inside the Fuel card. Tap the `+250 ml` pill to
/// log a glass; long-press for a custom-volume dialog. The bar + label tap
/// falls through to the parent _Card's onTap (→ /food).
class _FuelWaterRow extends ConsumerWidget {
  final int waterMl;
  final int waterTargetMl;
  const _FuelWaterRow({required this.waterMl, required this.waterTargetMl});

  String _fmtLiters(int ml) {
    final l = ml / 1000.0;
    if ((l * 10).round() == (l.round() * 10)) return l.toStringAsFixed(1);
    return l.toStringAsFixed(1);
  }

  Future<void> _addWater(WidgetRef ref, int ml) async {
    HapticFeedback.selectionClick();
    final repo = ref.read(foodRepositoryProvider);
    final date = ref.read(diaryDateProvider);
    await repo.addWater(ml, date);
    ref.invalidate(waterIntakeProvider);
  }

  Future<void> _promptCustom(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ml = await showDialog<int>(
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
    if (ml != null && ml > 0) await _addWater(ref, ml);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final target = waterTargetMl <= 0 ? 3500 : waterTargetMl;
    final pct = (waterMl / target).clamp(0.0, 1.0);
    return Row(
      children: [
        Icon(LucideIcons.droplet, size: 13, color: c.mind),
        const SizedBox(width: 7),
        Text(
          '${_fmtLiters(waterMl)} / ${_fmtLiters(target)} L',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: c.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(c.mind),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _WaterAddBtn(
          onTap: () => _addWater(ref, 250),
          onLongPress: () => _promptCustom(context, ref),
        ),
      ],
    );
  }
}

/// Pill button for `+250 ml`. Uses GestureDetector with `opaque` hit-test so
/// the parent card's onTap (route to /food) is not also triggered.
class _WaterAddBtn extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _WaterAddBtn({required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.mind.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: c.mind.withValues(alpha: 0.35), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 11, color: c.mind),
            const SizedBox(width: 4),
            Text(
              '250 ml',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.mind,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter({
    required this.pct,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - stroke / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final trackP = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, trackP);

    if (pct > 0) {
      final p = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        2 * math.pi * pct,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.pct != pct || old.color != color;
}

class _FilterPills extends StatelessWidget {
  final String value;
  final Map<String, int> counts;
  final ValueChanged<String> onChange;
  const _FilterPills({
    required this.value,
    required this.counts,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final opts = [
      ('all', 'All'),
      ('MORNING', 'Morning'),
      ('AFTERNOON', 'Afternoon'),
      ('EVENING', 'Evening'),
      ('NIGHT', 'Night'),
      ('incomplete', 'Incomplete'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final o in opts) ...[
            _pill(context, o.$1, o.$2, counts[o.$1] ?? 0),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String id, String label, int cnt) {
    final c = context.c;
    final on = value == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChange(id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: on ? c.accent : c.border, width: 0.5),
          boxShadow: on
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 7,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : c.textSecondary,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 17),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: on
                    ? Colors.white.withValues(alpha: 0.22)
                    : c.surfaceElevated,
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: Alignment.center,
              child: Text(
                '$cnt',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : c.textMuted,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodGroup extends StatelessWidget {
  final String period;
  final int done;
  final int total;
  final List<_MockTask> tasks;
  final ValueChanged<String> onComplete;
  const _PeriodGroup({
    required this.period,
    required this.done,
    required this.total,
    required this.tasks,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
            child: Row(
              children: [
                Icon(_periodIcon(period), size: 14, color: c.textMuted),
                const SizedBox(width: 8),
                _Overline(period[0] + period.substring(1).toLowerCase()),
                const Spacer(),
                Text(
                  '$done/$total',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          for (final t in tasks) ...[
            _TaskCard(task: t, onComplete: () => onComplete(t.id)),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _FilteredList extends StatelessWidget {
  final List<_MockTask> tasks;
  final ValueChanged<String> onComplete;
  const _FilteredList({required this.tasks, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      final c = context.c;
      return _Card(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(LucideIcons.check, size: 22, color: c.positive),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in tasks) ...[
          _TaskCard(task: t, onComplete: () => onComplete(t.id), showPeriod: true),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final _MockTask task;
  final VoidCallback onComplete;
  final bool showPeriod;
  const _TaskCard({
    required this.task,
    required this.onComplete,
    this.showPeriod = false,
  });

  void _openModal(BuildContext context, WidgetRef ref) {
    final habit = task.habitRef;
    if (habit == null) {
      context.push('/habit/${task.id}');
      return;
    }
    final date = ref.read(selectedDateProvider);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    HapticFeedback.selectionClick();
    showHabitQuickSheet(context, habit, task.logRef, key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final cat = _catColor(context, task.cat);
    final done = task.done;
    final showNumericRow = task.isNumeric && (task.current ?? 0) > 0;
    final pct = task.isNumeric ? task.ratio.clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: () => _openModal(context, ref),
      child: Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: done ? c.positive : cat),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 13, 14, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: done
                          ? c.surfaceElevated
                          : cat.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      task.icon,
                      size: 20,
                      color: done ? c.textMuted : cat,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                task.name,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: done ? c.textMuted : c.textPrimary,
                                  decoration: done ? TextDecoration.lineThrough : null,
                                  height: 1.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!done && _priorityIcon(task.priority) != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                _priorityIcon(task.priority)!,
                                size: 12,
                                color: _priorityColor(context, task.priority),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.surfaceElevated,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                task.time,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.textMuted,
                                  height: 1.0,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: cat.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                _catName(task.cat).toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: cat,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            if (showPeriod) ...[
                              const SizedBox(width: 7),
                              Text(
                                task.period[0] +
                                    task.period.substring(1).toLowerCase(),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: c.textMuted,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (showNumericRow) ...[
                          const SizedBox(height: 6),
                          _PartialProgressRow(
                            current: task.current ?? 0,
                            target: task.target ?? 0,
                            unit: task.unitLabel ?? '',
                            pct: pct,
                            color: cat,
                            done: done,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _taskRight(context),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _taskRight(BuildContext context) {
    final c = context.c;
    if (task.done) {
      return GestureDetector(
        onTap: onComplete,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: c.positive,
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.check, size: 16, color: Colors.white),
        ),
      );
    }
    if (task.type == 'reps') {
      final pct = (task.current ?? 0) / (task.target ?? 1);
      return SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(38, 38),
              painter: _RingPainter(
                pct: pct,
                color: _catColor(context, task.cat),
                track: c.surfaceElevated,
                stroke: 3.5,
              ),
            ),
            Text(
              '${(task.current ?? 0).toInt()}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }
    if (task.type == 'timer') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.play, size: 11, color: c.accent),
            const SizedBox(width: 4),
            Text(
              '${task.duration}m',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onComplete,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.borderStrong, width: 1.5),
        ),
      ),
    );
  }
}

/// Sub-line + thin progress bar shown below the meta row on numeric tasks.
class _PartialProgressRow extends StatelessWidget {
  final double current;
  final double target;
  final String unit;
  final double pct; // 0..1 (clamped for the bar; the % label uses the raw)
  final Color color;
  final bool done;
  const _PartialProgressRow({
    required this.current,
    required this.target,
    required this.unit,
    required this.pct,
    required this.color,
    required this.done,
  });

  static String _fmt(double v) {
    final r = v.toStringAsFixed(2);
    if (r.endsWith('.00')) return r.substring(0, r.length - 3);
    if (r.endsWith('0')) return r.substring(0, r.length - 1);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rawPct = target <= 0 ? 0 : ((current / target) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_fmt(current)} / ${_fmt(target)} $unit',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: done ? c.textMuted : c.textSecondary,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '· $rawPct%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: done ? c.textMuted : color,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 3,
            backgroundColor: c.surfaceElevated,
            valueColor: AlwaysStoppedAnimation(done ? c.positive : color),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const _Card({required this.child, this.padding = EdgeInsets.zero, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: card,
    );
  }
}

class _Overline extends StatelessWidget {
  final String text;
  final double size;
  const _Overline(this.text, {this.size = 10.5});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: c.textMuted,
        height: 1.0,
      ),
    );
  }
}

class _MicroPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const _MicroPill({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

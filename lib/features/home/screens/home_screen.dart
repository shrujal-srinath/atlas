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
import '../../auth/providers/auth_provider.dart';
import '../../food/providers/food_providers.dart';
import '../../food/scoring/nutrition_score.dart';
import '../../habits/providers/habit_provider.dart';
import '../../journal/widgets/wellness_check_in_card.dart';
import '../../notifications/reminder_feed_provider.dart';
import '../../xp/leveling_providers.dart';
import '../providers/home_providers.dart';
import '../providers/ticker_provider.dart';
import '../widgets/habit_log_modal.dart';
import 'focus_timer_sheet.dart';

// ════════════════════════════════════════════════════════════════════
// BENTO HOME — Compact Stadium layout, wired to live providers
// (homeWeekProvider / homeTasksProvider / homeScoreProvider). The render
// view-models (_DayVM/_TaskVM) and section widgets are split across the
// part files below for navigability.
// ════════════════════════════════════════════════════════════════════

part 'home_view_models.dart';
part 'home_header.dart';
part 'home_week_strip.dart';
part 'home_score_block.dart';
part 'home_tiles.dart';
part 'home_fuel_card.dart';
part 'home_common.dart';
part 'home_day_rail.dart';

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

  /// Toggles a task done/undone. Numeric tasks complete *at* their target
  /// (and reset to 0 on undo) so the score engine's ratio actually reads 1.0 —
  /// `completed: true` alone would leave a partial actual_value in charge.
  Future<void> _toggleTask(_TaskVM t) async {
    HapticFeedback.lightImpact();
    final date = ref.read(selectedDateProvider);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await ref.read(habitActionsProvider.notifier).toggleHabit(
          t.id,
          key,
          completed: !t.done,
          actualValue: t.isNumeric ? (t.done ? 0.0 : t.target) : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final selDate = ref.watch(selectedDateProvider);
    final weekAsync = ref.watch(homeWeekProvider(selDate));
    final tasksAsync = ref.watch(homeTasksProvider(selDate));
    final scoreAsync = ref.watch(homeScoreProvider(selDate));

    // Convert real data → display shapes. While loading we fall back to a
    // zeroed placeholder week + empty rail — correct dates, never fabricated
    // scores or habits — so the layout doesn't thrash.
    final week = weekAsync.valueOrNull;
    final realDays = (week == null || week.isEmpty)
        ? _placeholderWeek(selDate)
        : week.map(_weekDayToMock).toList();
    final selIdx = week == null
        ? 3
        : week.indexWhere((d) =>
            d.date.year == selDate.year &&
            d.date.month == selDate.month &&
            d.date.day == selDate.day);
    final selDayIdx = selIdx < 0 ? 3 : selIdx;

    final realTasks = tasksAsync.valueOrNull?.map(_homeTaskToMock).toList();
    // While loading, show an empty rail (a calm "all clear" card) rather than
    // fabricated seed habits. Cache-backed loads resolve near-instantly.
    final List<_TaskVM> tasks = realTasks ?? const <_TaskVM>[];
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
        : _DayVM(
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
                _ScoreBlock(
                    day: dayForScore, onTap: () => context.push('/stats/score')),
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
                      const Expanded(
                        child: _MultiTile(),
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
                const SizedBox(height: 12),
                _DayRail(
                  tasks: filtered ?? tasks,
                  isToday: DateUtils.isSameDay(selDate, DateTime.now()),
                  onToggle: _toggleTask,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

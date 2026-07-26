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
import '../../../shared/widgets/pressable_scale.dart';
import '../../food/providers/food_providers.dart';
import '../../food/providers/food_sub_tab_provider.dart';
import '../../food/scoring/nutrition_score.dart';
import '../../habits/providers/habit_provider.dart';
import '../../habits/widgets/meal_completion_gate.dart';
import '../../../shared/providers/today_provider.dart';
import '../../journal/widgets/wellness_check_in_card.dart';
import '../../notifications/reminder_feed_provider.dart';
import '../../xp/leveling_providers.dart';
import '../../xp/prereq_providers.dart';
import '../../xp/milestone_nudge_provider.dart';
import '../../xp/models/level_prereq.dart';
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

  Future<void> _onRefresh() async {
    // Pull-to-refresh genuinely reloads the day's data. (The old gesture only
    // re-revealed a greeting that no longer exists.) Invalidate the leaf data
    // sources; the home families recompute, and we hold the spinner until the
    // score lands.
    HapticFeedback.lightImpact();
    final date = ref.read(selectedDateProvider);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    ref.invalidate(habitsProvider);
    ref.invalidate(recentHabitLogsProvider);
    ref.invalidate(habitLogsForDateProvider(key));
    // Also refresh the stats/achievement leaf sources so a manual reload isn't
    // limited to the live home score (see HabitActionsNotifier._invalidateLogCaches).
    ref.invalidate(statsLogsProvider);
    ref.invalidate(lifetimeCompletedLogsProvider);
    await ref.read(homeScoreProvider(date).future);
  }

  /// Toggles a task done/undone. Numeric tasks complete *at* their target
  /// (and reset to 0 on undo) so the score engine's ratio actually reads 1.0 —
  /// `completed: true` alone would leave a partial actual_value in charge.
  Future<void> _toggleTask(_TaskVM t) async {
    HapticFeedback.lightImpact();
    final date = ref.read(selectedDateProvider);
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await completeHabitGated(
      context,
      ref,
      t.id,
      key,
      habit: t.habitRef,
      wasCompleted: t.done,
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
    // Keep-alive: evaluates milestone halfway/late nudges as progress changes.
    ref.watch(milestoneNudgeRunnerProvider);

    // Convert real data → display shapes. While loading we fall back to a
    // zeroed placeholder week + empty rail — correct dates, never fabricated
    // scores or habits — so the layout doesn't thrash.
    final week = weekAsync.valueOrNull;
    final realDays = (week == null || week.isEmpty)
        ? _placeholderWeek(selDate)
        : week.map(_weekDayToMock).toList();
    final selIdx = week == null
        ? 3
        : week.indexWhere(
            (d) =>
                d.date.year == selDate.year &&
                d.date.month == selDate.month &&
                d.date.day == selDate.day,
          );
    final selDayIdx = selIdx < 0 ? 3 : selIdx;

    final realTasks = tasksAsync.valueOrNull?.map(_homeTaskToMock).toList();
    // While loading, show an empty rail (a calm "all clear" card) rather than
    // fabricated seed habits. Cache-backed loads resolve near-instantly.
    final List<_TaskVM> allTasks = realTasks ?? const <_TaskVM>[];
    // Negatives ("avoid" habits) live in their own "Staying clean" group below
    // the rail — not in the chronological track and not period-filtered.
    final negatives = allTasks
        .where((t) => t.habitRef?.type == HabitType.negative)
        .toList();
    final tasks = allTasks
        .where((t) => t.habitRef?.type != HabitType.negative)
        .toList();
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
      body: Stack(
        children: [
          SafeArea(
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
                    // Status ticker pulled to the top with the bell beside it —
                    // the greeting/date block above it has been removed.
                    _TopBar(onBell: () => context.push('/notifications')),
                    const SizedBox(height: 10),
                    _WeekStrip(
                      selected: selDate,
                      onSelect: (d) =>
                          ref.read(selectedDateProvider.notifier).state = d,
                    ),
                    const SizedBox(height: 7),
                    _ScoreBlock(
                      day: dayForScore,
                      onTap: () => context.push('/stats/score'),
                    ),
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
                          const Expanded(child: _MultiTile()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _FuelCard(
                      onTap: () {
                        // Always open the Diary sub-tab, not whichever Food sub-tab
                        // (Body/Insights) happened to be viewed last.
                        ref.read(foodSubTabProvider.notifier).state =
                            FoodSubTab.diary;
                        context.go('/food');
                      },
                    ),
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
                    if (negatives.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _StayingCleanGroup(tasks: negatives),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const _XpGainOverlay(),
          const _MilestoneCelebrationWatcher(),
        ],
      ),
    );
  }
}

/// Watches the next level's milestones and pops a celebration the moment one
/// transitions to "met". Primes from the current snapshot so already-complete
/// milestones never re-fire on entry. Invisible itself.
class _MilestoneCelebrationWatcher extends ConsumerStatefulWidget {
  const _MilestoneCelebrationWatcher();
  @override
  ConsumerState<_MilestoneCelebrationWatcher> createState() =>
      _MilestoneCelebrationWatcherState();
}

class _MilestoneCelebrationWatcherState
    extends ConsumerState<_MilestoneCelebrationWatcher> {
  final Set<String> _seen = {};
  bool _primed = false;

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(confirmedLevelProvider).valueOrNull;
    if (level == null) return const SizedBox.shrink();
    final list = ref.watch(prereqProgressProvider(level + 1)).valueOrNull;
    if (list != null) {
      if (!_primed) {
        _seen.addAll(list.where((p) => p.isMet).map((p) => p.def.id));
        _primed = true;
      } else {
        for (final p in list) {
          if (p.isMet && _seen.add(p.def.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate(p));
          }
        }
      }
    }
    return const SizedBox.shrink();
  }

  void _celebrate(PrereqProgress p) {
    if (!mounted) return;
    final habits = ref.read(habitsProvider).valueOrNull ?? const <Habit>[];
    HapticFeedback.heavyImpact();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) =>
          _MilestoneCelebrationDialog(label: describePrereq(p.def, habits)),
    );
  }
}

/// Compact "milestone complete" celebration dialog.
class _MilestoneCelebrationDialog extends StatefulWidget {
  final String label;
  const _MilestoneCelebrationDialog({required this.label});
  @override
  State<_MilestoneCelebrationDialog> createState() =>
      _MilestoneCelebrationDialogState();
}

class _MilestoneCelebrationDialogState
    extends State<_MilestoneCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
        child: Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: AppShadows.sheet,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.positive.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.trophy, size: 30, color: c.positive),
              ),
              const SizedBox(height: 16),
              Text('Milestone complete', style: context.t.h2),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: AppType.meta.copyWith(color: c.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text(
                    'Nice',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating "+N XP" reward that flies up and fades whenever the user's
/// cumulative level XP increases (e.g. finishing a task). Self-contained: it
/// listens to [cumulativeLevelXpProvider] and animates the delta, so every XP
/// source gets the same celebratory feedback with zero per-call wiring.
class _XpGainOverlay extends ConsumerStatefulWidget {
  const _XpGainOverlay();
  @override
  ConsumerState<_XpGainOverlay> createState() => _XpGainOverlayState();
}

class _XpGainOverlayState extends ConsumerState<_XpGainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _amount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _fire(int amount) {
    if (amount <= 0 || !mounted) return;
    setState(() => _amount = amount);
    HapticFeedback.lightImpact();
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Any XP increase (task completion, etc.) triggers the fly-up.
    ref.listen(cumulativeLevelXpProvider, (prev, next) {
      final p = prev?.valueOrNull;
      final n = next.valueOrNull;
      if (p != null && n != null && n > p) _fire(n - p);
    });

    final c = context.c;
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.5),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            if (t == 0 || t == 1) return const SizedBox.shrink();
            final rise = -40.0 * Curves.easeOut.transform(t);
            final opacity = t < 0.15
                ? t / 0.15
                : t > 0.72
                ? (1 - (t - 0.72) / 0.28)
                : 1.0;
            final scale =
                0.8 +
                0.2 * Curves.easeOutBack.transform((t * 2.2).clamp(0.0, 1.0));
            return Transform.translate(
              offset: Offset(0, rise),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.40),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.zap, size: 15, color: c.onAccent),
                        const SizedBox(width: 5),
                        Text(
                          '+$_amount XP',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: c.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

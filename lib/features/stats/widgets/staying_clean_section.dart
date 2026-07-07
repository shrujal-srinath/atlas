import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../habits/providers/habit_provider.dart';
import 'stats_primitives.dart';

/// Stats subsection for negative ("avoid") habits — how the user is doing at
/// staying clean. Self-heading and self-hiding: renders nothing when there are
/// no negative habits, so the hub can drop it in unconditionally.
class StatsStayingClean extends ConsumerWidget {
  const StatsStayingClean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final negatives =
        habits.where((h) => h.type == HabitType.negative).toList();
    if (negatives.isEmpty) return const SizedBox.shrink();

    final logs =
        ref.watch(recentHabitLogsProvider).valueOrNull ?? const <HabitLog>[];
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatsSectionHeader(
            title: 'Staying clean',
            caption: 'Days clean & longest no-slip runs',
          ),
          const SizedBox(height: 12),
          for (final h in negatives) ...[
            _NegStatCard(habit: h, m: _cleanMetrics(h.id, logs, now)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 18), // section rhythm (hub adds nothing after)
        ],
      ),
    );
  }
}

String _ds(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _CleanMetrics {
  final int current; // current clean streak (days, ending today)
  final int longest; // longest clean run in the tracked window
  final int totalClean; // total clean days tracked
  final int slips; // total slips
  final List<bool?> last14; // per-day: true=clean, false=slip, null=untracked
  const _CleanMetrics(
      this.current, this.longest, this.totalClean, this.slips, this.last14);
}

/// Current/longest clean streak + total clean days for a negative, computed
/// over the tracked window (from the earliest log to today). A slip
/// (`completed:false`) breaks a run; today breaks immediately if slipped.
_CleanMetrics _cleanMetrics(String habitId, List<HabitLog> logs, DateTime now) {
  final mine = logs.where((l) => l.habitId == habitId).toList();
  final today = DateTime(now.year, now.month, now.day);
  if (mine.isEmpty) {
    return _CleanMetrics(0, 0, 0, 0, List<bool?>.filled(14, null));
  }
  final slip = {for (final l in mine) if (!l.completed) l.date};
  var earliest = mine.first.date;
  for (final l in mine) {
    if (l.date.compareTo(earliest) < 0) earliest = l.date;
  }
  final start = DateTime.parse(earliest);
  final startD = DateTime(start.year, start.month, start.day);
  final totalDays = today.difference(startD).inDays + 1;

  int longest = 0, run = 0, totalClean = 0;
  for (int i = 0; i < totalDays; i++) {
    final clean = !slip.contains(_ds(startD.add(Duration(days: i))));
    if (clean) {
      run++;
      totalClean++;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
  }

  // Last 14 days for the strip: clean by default, slip if logged, null before
  // the habit was being tracked.
  final last14 = <bool?>[
    for (int i = 13; i >= 0; i--)
      () {
        final d = today.subtract(Duration(days: i));
        if (d.isBefore(startD)) return null;
        return !slip.contains(_ds(d));
      }(),
  ];

  // `run` ends on today → the current streak (0 if today is a slip).
  return _CleanMetrics(run, longest, totalClean, slip.length, last14);
}

class _NegStatCard extends StatelessWidget {
  final Habit habit;
  final _CleanMetrics m;
  const _NegStatCard({required this.habit, required this.m});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return StatsCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.negative.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(LucideIcons.ban, size: 15, color: c.negative),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habit.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (m.slips == 0 && m.totalClean > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.positive.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('Spotless',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.positive,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _metric(context, '${m.current}', 'current streak',
                  LucideIcons.flame, c.amber),
              _divider(c),
              _metric(context, '${m.longest}', 'longest run',
                  LucideIcons.trophy, c.accent),
              _divider(c),
              _metric(context, '${m.totalClean}', 'days clean',
                  LucideIcons.shieldCheck, c.positive),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 0.5, color: c.border),
          const SizedBox(height: 12),
          Text('LAST 14 DAYS',
              style: AppType.meta.copyWith(
                  color: c.textDim, letterSpacing: 0.6, fontSize: 9.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in m.last14)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: d == null
                            ? c.surfaceElevated.withValues(alpha: 0.4)
                            : d
                                ? c.positive.withValues(alpha: 0.75)
                                : c.negative,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(AppPalette c) =>
      Container(width: 0.5, height: 30, color: c.border);

  Widget _metric(BuildContext context, String value, String label,
      IconData icon, Color color) {
    final c = context.c;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: c.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

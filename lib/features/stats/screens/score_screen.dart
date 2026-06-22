import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../../habits/providers/habit_provider.dart';
import '../../home/providers/home_providers.dart';
import '../../home/scoring/score_engine.dart';
import '../../home/widgets/habit_log_modal.dart';
import '../../home/widgets/triple_arc_ring.dart';
import '../../xp/leveling_providers.dart';

/// Today's Score deep-dive. Five-section layout: big ring → section
/// breakdown → per-task contributions → "what's left to peak" → 7-day trend.
class ScoreScreen extends ConsumerWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final selDate = ref.watch(selectedDateProvider);
    final scoreAsync = ref.watch(homeScoreProvider(selDate));
    final weekAsync = ref.watch(homeWeekProvider(selDate));
    final weights = ref.watch(sectionWeightsProvider);

    final score = scoreAsync.valueOrNull;
    final week = weekAsync.valueOrNull;
    final streak = ref.watch(currentScoreStreakProvider).valueOrNull ?? 0;
    final contribs = score?.perTaskContrib ?? const <TaskContribution>[];
    final pending = contribs.where((c) => !c.isCompleted).toList()
      ..sort((a, b) => b.remainingPts.compareTo(a.remainingPts));
    final topPeak = pending.take(3).toList();
    final atPeak = score != null && score.score >= score.projectedScore;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(fallback: '/stats'),
        title: Text("Today's Score", style: t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeScoreProvider(selDate));
            ref.invalidate(homeWeekProvider(selDate));
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          color: c.accent,
          backgroundColor: c.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
                AppSpace.screenH, 12, AppSpace.screenH, 118),
            children: [
              _BigScoreCard(score: score, streak: streak),
              const SizedBox(height: 22),
              _Section(label: 'SECTION BREAKDOWN'),
              const SizedBox(height: 8),
              _BreakdownCard(score: score, weights: weights),
              const SizedBox(height: 22),
              _Section(label: 'WHERE YOUR SCORE COMES FROM'),
              const SizedBox(height: 8),
              _ContribCard(
                contribs: contribs,
                onTapHabit: (h, l) => _openModal(context, ref, h, l, selDate),
              ),
              if (contribs.isNotEmpty) ...[
                const SizedBox(height: 22),
                _Section(label: "WHAT'S LEFT TO PEAK"),
                const SizedBox(height: 8),
                _PeakCard(
                  rows: topPeak,
                  atPeak: atPeak && pending.isEmpty,
                  onTapHabit: (h, l) =>
                      _openModal(context, ref, h, l, selDate),
                ),
              ],
              const SizedBox(height: 22),
              _Section(label: '7-DAY TREND'),
              const SizedBox(height: 8),
              _TrendCard(week: week ?? const []),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openModal(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    HabitLog? log,
    DateTime date,
  ) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    showHabitLogModal(context, habit, log, key);
  }
}

// ────────────────────────────────────────────────────────────────────
// BIG SCORE
// ────────────────────────────────────────────────────────────────────

class _BigScoreCard extends StatelessWidget {
  final HomeScore? score;
  final int streak;
  const _BigScoreCard({required this.score, required this.streak});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = score;
    final ath = (s?.sectionPct[HabitSection.athletic] ?? 0) / 100.0;
    final mind = (s?.sectionPct[HabitSection.mind] ?? 0) / 100.0;
    final body = (s?.sectionPct[HabitSection.body] ?? 0) / 100.0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          TripleArcRing(
            score: (s?.score ?? 0).toDouble(),
            athleticPct: ath,
            buildingPct: mind,
            breakingPct: body,
            size: 168,
            centerFontSize: 48,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [
                _Pill(
                  text: '${s?.done ?? 0}/${s?.total ?? 0} habits',
                  color: c.textMuted,
                ),
                _Pill(
                  text: 'projected ${s?.projectedScore ?? 0}%',
                  color: c.accent,
                ),
                _Pill(
                  text: '$streak-day',
                  icon: LucideIcons.flame,
                  color: c.amber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const _Pill({required this.text, required this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
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

// ────────────────────────────────────────────────────────────────────
// BREAKDOWN
// ────────────────────────────────────────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  final HomeScore? score;
  final Map<HabitSection, double> weights; // fractions summing to ~1.0
  const _BreakdownCard({required this.score, required this.weights});

  static const _labels = {
    HabitSection.athletic: 'Athletic',
    HabitSection.mind: 'Mind',
    HabitSection.body: 'Body',
  };

  int _weightPct(HabitSection s) => ((weights[s] ?? 0) * 100).round();

  double _contribution(HabitSection s) {
    final pct = (score?.sectionPct[s] ?? 0) / 100.0;
    return pct * (weights[s] ?? 0) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final total = HabitSection.values
        .fold<double>(0, (a, s) => a + _contribution(s))
        .round();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < HabitSection.values.length; i++) ...[
            _BreakdownRow(
              section: HabitSection.values[i],
              pct: score?.sectionPct[HabitSection.values[i]] ?? 0,
              weightPct: _weightPct(HabitSection.values[i]),
              contribution: _contribution(HabitSection.values[i]).round(),
              label: _labels[HabitSection.values[i]]!,
              color: HabitSection.values[i].color(context.c),
            ),
            if (i < HabitSection.values.length - 1) const SizedBox(height: 11),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 0.5, color: c.borderStrong),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Total score',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${score?.score ?? total} / 100',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final HabitSection section;
  final int pct;        // 0..110
  final int weightPct;
  final int contribution;
  final String label;
  final Color color;
  const _BreakdownRow({
    required this.section,
    required this.pct,
    required this.weightPct,
    required this.contribution,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final over = pct > 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'weight $weightPct%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const Spacer(),
            if (over)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(LucideIcons.plus, size: 12, color: c.amber),
              ),
            Text(
              '+$contribution',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (pct / 100.0).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: c.surfaceElevated,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$pct% complete × $weightPct% weight',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: c.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// PER-TASK CONTRIBUTIONS
// ────────────────────────────────────────────────────────────────────

class _ContribCard extends StatelessWidget {
  final List<TaskContribution> contribs;
  final void Function(Habit h, HabitLog? l) onTapHabit;
  const _ContribCard({required this.contribs, required this.onTapHabit});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (contribs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Center(
          child: Text(
            'No habits scheduled today.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c.textMuted,
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < contribs.length; i++) ...[
            _ContribRow(
              contrib: contribs[i],
              onTap: () => onTapHabit(contribs[i].habit, contribs[i].log),
            ),
            if (i < contribs.length - 1)
              Divider(height: 1, thickness: 0.5, color: c.border, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _ContribRow extends StatelessWidget {
  final TaskContribution contrib;
  final VoidCallback onTap;
  const _ContribRow({required this.contrib, required this.onTap});

  static String _fmtPts(double v) => v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = contrib.habit;
    final color = h.section.color(context.c);
    final done = contrib.isCompleted;
    final muted = contrib.ratio < 0.01;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Section dot
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: muted ? color.withValues(alpha: 0.3) : color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Habit icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: muted
                    ? c.surfaceElevated
                    : color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                habitIcon(h.icon),
                size: 16,
                color: muted ? c.textMuted : color,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          h.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: muted ? c.textMuted : c.textPrimary,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            decorationColor: c.textMuted,
                            height: 1.15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PriorityChip(priority: h.priority),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    done
                        ? 'Completed'
                        : muted
                            ? 'Not started'
                            : '${(contrib.ratio * 100).round()}% complete',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side: contributed pts / potential pts
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '+${_fmtPts(contrib.contributedPts)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: muted ? c.textMuted : color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'pts',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: c.textMuted,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '/ ${_fmtPts(contrib.potentialPts)} max',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: c.textMuted,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final HabitPriority priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (priority == HabitPriority.normal) return const SizedBox.shrink();
    final color = switch (priority) {
      HabitPriority.low => c.textMuted,
      HabitPriority.high => c.amber,
      HabitPriority.critical => c.negative,
      HabitPriority.normal => c.textMuted,
    };
    final label = switch (priority) {
      HabitPriority.low => '0.5×',
      HabitPriority.high => '1.5×',
      HabitPriority.critical => '2.5×',
      HabitPriority.normal => '1×',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.0,
          letterSpacing: 0.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// PEAK — top remaining gains
// ────────────────────────────────────────────────────────────────────

class _PeakCard extends StatelessWidget {
  final List<TaskContribution> rows;
  final bool atPeak;
  final void Function(Habit h, HabitLog? l) onTapHabit;
  const _PeakCard({
    required this.rows,
    required this.atPeak,
    required this.onTapHabit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (atPeak || rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.positive.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.check, size: 17, color: c.positive),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peak reached for today',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Every scheduled habit is done. Nothing left to lift it.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final totalRemaining = rows.fold<double>(0, (a, r) => a + r.remainingPts);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(
                  'Lift your score by',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  '+${totalRemaining.toStringAsFixed(1)} pts',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: c.border),
          for (int i = 0; i < rows.length; i++) ...[
            _PeakRow(
              row: rows[i],
              color: rows[i].habit.section.color(context.c),
              onTap: () => onTapHabit(rows[i].habit, rows[i].log),
            ),
            if (i < rows.length - 1)
              Divider(height: 1, thickness: 0.5, color: c.border, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _PeakRow extends StatelessWidget {
  final TaskContribution row;
  final Color color;
  final VoidCallback onTap;
  const _PeakRow({required this.row, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = row.habit;
    final pct = row.ratio.clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(habitIcon(h.icon), size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    h.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (pct > 0) ...[
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 3,
                        backgroundColor: c.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '+${row.remainingPts.toStringAsFixed(1)}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: c.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                'pts',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// 7-DAY TREND
// ────────────────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  final List<HomeWeekDay> week;
  const _TrendCard({required this.week});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final scores = week.map((d) => d.score).toList();
    final past = scores.where((s) => s > 0).toList();
    final avg =
        past.isEmpty ? 0 : (past.reduce((a, b) => a + b) / past.length).round();
    final best = past.isEmpty ? 0 : past.reduce(math.max);
    final low = past.isEmpty ? 0 : past.reduce(math.min);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$avg',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.6,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'weekly avg',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                ),
              ),
              const Spacer(),
              if (past.isNotEmpty)
                Text(
                  'best $best · low $low',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: CustomPaint(
              size: const Size.fromHeight(64),
              painter: _Sparkline(
                points: scores,
                color: c.accent,
                fill: c.accent.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  final List<int> points;
  final Color color;
  final Color fill;
  _Sparkline({required this.points, required this.color, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final stepX = points.length > 1 ? w / (points.length - 1) : w;
    final maxV = math.max(100, points.fold<int>(0, math.max));
    Offset ptAt(int i) {
      final v = points[i];
      final y = h - (v / maxV) * h;
      return Offset(i * stepX, y);
    }

    final path = Path()..moveTo(ptAt(0).dx, ptAt(0).dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(ptAt(i).dx, ptAt(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final area = Path()..moveTo(0, h);
    for (int i = 0; i < points.length; i++) {
      area.lineTo(ptAt(i).dx, ptAt(i).dy);
    }
    area
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(covariant _Sparkline old) =>
      old.points != points || old.color != color;
}

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: c.textMuted,
          height: 1.0,
        ),
      ),
    );
  }
}

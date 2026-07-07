part of 'progression_screen.dart';

// ────────────────────────────────────────────────────────────────────
// DAILY XP BARS — per-day contribution, green above break-even / red below
// ────────────────────────────────────────────────────────────────────

class _XpBarsCard extends ConsumerWidget {
  const _XpBarsCard();

  static String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(dailyXpDeltaProvider);

    Widget shell(Widget child) => Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: child,
        );
    Widget hint(String m) => SizedBox(
          height: 90,
          child: Center(
            child: Text(m,
                textAlign: TextAlign.center,
                style: AppType.meta.copyWith(color: c.textMuted)),
          ),
        );

    return async.when(
      loading: () => shell(hint('Loading daily XP…')),
      error: (_, _) => shell(hint('Daily XP unavailable right now.')),
      data: (all) {
        if (all.isEmpty) {
          return shell(hint('Your daily XP appears here after a logged day.'));
        }
        final data = all.length > 21 ? all.sublist(all.length - 21) : all;
        final deltas = data.map((e) => e.delta).toList();
        final maxD = deltas.reduce(math.max);
        final minD = deltas.reduce(math.min);
        final maxY = ((maxD < 10 ? 10 : maxD) * 1.18).toDouble();
        final minY = (minD >= 0 ? 0.0 : minD * 1.18).toDouble();
        final windowSum = deltas.fold<int>(0, (a, b) => a + b);
        final best = deltas.reduce(math.max);
        final worst = deltas.reduce(math.min);
        final labelEvery = (data.length / 4).ceil().clamp(1, data.length);

        return shell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${windowSum >= 0 ? '+' : ''}${_fmt(windowSum)}',
                    style: AppType.numLg.copyWith(
                        color: windowSum >= 0 ? c.textPrimary : c.negative,
                        fontSize: 24)),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('XP · last ${data.length} days',
                      style: AppType.meta.copyWith(color: c.textMuted)),
                ),
                const Spacer(),
                Text('best +$best · worst $worst',
                    style: AppType.meta.copyWith(color: c.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceBetween,
                  minY: minY,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 18,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 ||
                              i >= data.length ||
                              i % labelEvery != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('d/M').format(data[i].date),
                                style: AppType.overline
                                    .copyWith(color: c.textMuted, fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(y: 0, color: c.borderStrong, strokeWidth: 1),
                  ]),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => c.surfaceElevated,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      getTooltipItem: (group, _, rod, _) {
                        final e = data[group.x];
                        return BarTooltipItem(
                          '${e.delta >= 0 ? '+' : ''}${e.delta} XP\n',
                          TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: DateFormat('EEE d MMM').format(e.date),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < data.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: data[i].delta.toDouble(),
                          color: data[i].delta >= 0 ? c.positive : c.negative,
                          width: 6,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ));
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// PRE-REQS CHECKLIST
// ────────────────────────────────────────────────────────────────────

class _PrereqsCard extends ConsumerWidget {
  final List<PrereqProgress> progress;
  final List<Habit> habits;
  final int targetLevel;
  const _PrereqsCard({
    required this.progress,
    required this.habits,
    required this.targetLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    if (progress.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.target, size: 15, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No milestones set',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'XP threshold (2,100 pts) is your only gate to Level $targetLevel.',
              style: AppType.meta.copyWith(color: c.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => context.push('/level/prereq-picker/$targetLevel'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              child: const Text('Set milestones',
                  style: TextStyle(
                      fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < progress.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, thickness: 0.5, color: c.border, indent: 56),
            _PrereqRow(
              progress: progress[i],
              label: describePrereq(progress[i].def, habits),
              onRestart: progress[i].isExpired
                  ? () => _restart(ref, progress[i].def)
                  : null,
            ),
          ],
          Divider(height: 1, thickness: 0.5, color: c.border),
          InkWell(
            onTap: () => context.push('/level/prereq-picker/$targetLevel'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(LucideIcons.plus, size: 14, color: c.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Add or edit milestones',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Re-stamps an expired milestone's timeframe so the user gets a fresh window
  /// instead of being stuck. Keeps the same target + window length.
  Future<void> _restart(WidgetRef ref, LevelPrereq def) async {
    final cfg = {
      ...def.config,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
    };
    final fresh = LevelPrereq(
      id: def.id,
      userId: def.userId,
      level: def.level,
      kind: def.kind,
      config: cfg,
    );
    if (ref.read(devModeProvider)) {
      removePrereqDevMode(ref, def.id, def.level);
      addPrereqDevMode(ref, fresh);
    } else {
      final repo = ref.read(levelPrereqRepoProvider);
      await repo.delete(def.id);
      await repo.insert(fresh);
    }
    ref.invalidate(userPrereqsProvider);
    ref.invalidate(prereqProgressProvider);
  }
}

class _PrereqRow extends StatelessWidget {
  final PrereqProgress progress;
  final String label;
  final VoidCallback? onRestart;
  const _PrereqRow({
    required this.progress,
    required this.label,
    this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final met = progress.isMet;
    final tint = met ? c.positive : c.accent;
    final pct = progress.target <= 0
        ? 0.0
        : (progress.currentProgress / progress.target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              met ? LucideIcons.checkCircle2 : _kindIcon(progress.def.kind),
              size: 15,
              color: tint,
            ),
          ),
          const SizedBox(width: 12),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: c.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation(tint),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${progress.currentProgress} / ${progress.target}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: met ? c.positive : c.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                if (!met && progress.daysLeft != null) ...[
                  const SizedBox(height: 6),
                  _TimeframeLine(progress: progress, onRestart: onRestart),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "X days left" / "Expired · Restart" line under a timed milestone.
class _TimeframeLine extends StatelessWidget {
  final PrereqProgress progress;
  final VoidCallback? onRestart;
  const _TimeframeLine({required this.progress, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final expired = progress.isExpired;
    final days = progress.daysLeft ?? 0;
    final color = expired
        ? c.negative
        : (days <= 3 ? c.amber : c.textMuted);
    return Row(
      children: [
        Icon(expired ? LucideIcons.alertCircle : LucideIcons.clock,
            size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          expired
              ? 'Timeframe expired'
              : (days == 0 ? 'Last day' : '$days days left'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (expired && onRestart != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onRestart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.rotateCcw, size: 11, color: c.accent),
                const SizedBox(width: 3),
                Text(
                  'Restart',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

IconData _kindIcon(PrereqKind k) => switch (k) {
      PrereqKind.habitCompletions => LucideIcons.checkSquare,
      PrereqKind.streakDays => LucideIcons.flame,
      PrereqKind.perfectDays => LucideIcons.target,
      PrereqKind.nutritionDays => LucideIcons.utensils,
    };

// ────────────────────────────────────────────────────────────────────
// ACTIVITY TODAY (derived from score engine's contributions)
// ────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final List<TaskContribution> contribs;
  const _ActivityCard({required this.contribs});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = contribs.where((c) => c.isCompleted).toList()
      ..sort((a, b) => b.contributedPts.compareTo(a.contributedPts));
    if (done.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          'No tasks completed yet today',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < done.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  color: c.border,
                  thickness: 0.5,
                  indent: 14,
                  endIndent: 14),
            _ActivityRow(contrib: done[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final TaskContribution contrib;
  const _ActivityRow({required this.contrib});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = contrib.habit;
    final color = h.sectionId.sectionColor(c);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
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
            child: Icon(habitIcon(h.icon), size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              h.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${contrib.contributedPts.round()} XP',
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
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// ACHIEVEMENTS
// ────────────────────────────────────────────────────────────────────

class _AchievementsGrid extends StatelessWidget {
  final Set<String> unlocked;
  final Map<String, AchievementProgress> progress;
  const _AchievementsGrid({required this.unlocked, required this.progress});

  @override
  Widget build(BuildContext context) {
    final visible = achievementCatalog
        .where((a) => !a.hidden || unlocked.contains(a.id))
        .toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: visible.length,
      itemBuilder: (_, i) => _AchievementTile(
        def: visible[i],
        unlocked: unlocked.contains(visible[i].id),
        progress: progress[visible[i].id],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementDef def;
  final bool unlocked;
  final AchievementProgress? progress;
  const _AchievementTile({
    required this.def,
    required this.unlocked,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = unlocked ? c.accent : c.textMuted;
    // Show a progress bar only for locked achievements the user has started.
    final p = progress;
    final showProgress = !unlocked &&
        p != null &&
        p.target > 0 &&
        p.current > 0 &&
        p.fraction < 1.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: unlocked ? c.accent.withValues(alpha: 0.4) : c.border,
          width: unlocked ? 1 : 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: unlocked
                  ? c.accent.withValues(alpha: 0.12)
                  : c.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: tint.withValues(alpha: 0.6), width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(def.icon, size: 20, color: tint),
          ),
          const SizedBox(height: 8),
          Text(
            def.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: unlocked ? c.textPrimary : c.textMuted,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          if (showProgress) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: p.fraction,
                  minHeight: 4,
                  backgroundColor: c.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${p.current} / ${p.target}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: c.accent,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ] else
            Text(
              def.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: c.textMuted,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

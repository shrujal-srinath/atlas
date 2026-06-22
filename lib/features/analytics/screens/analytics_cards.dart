part of 'analytics_screen.dart';

// ── Week-over-week compare ─────────────────────────────────────

class _WeekCompareCard extends StatelessWidget {
  final AnalyticsData data;
  const _WeekCompareCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final overall = data.weekAvg - data.prevWeekAvg;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('THIS WEEK VS LAST',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              Text('${data.weekAvg.round()}%',
                  style: AppType.numMd.copyWith(color: c.textPrimary)),
              const SizedBox(width: 8),
              _DeltaChip(value: overall),
            ],
          ),
          const SizedBox(height: 14),
          for (final s in HabitSection.values) ...[
            _CompareRow(
              label: _sectionLabel(s),
              color: _sectionColor(context, s),
              thisPct: (data.weekSectionAvg[s] ?? 0) * 100,
              delta: ((data.weekSectionAvg[s] ?? 0) -
                      (data.prevWeekSectionAvg[s] ?? 0)) *
                  100,
            ),
            if (s != HabitSection.values.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final Color color;
  final double thisPct;
  final double delta;
  const _CompareRow({
    required this.label,
    required this.color,
    required this.thisPct,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('${thisPct.round()}%',
            style: AppType.numMd.copyWith(color: c.textPrimary, fontSize: 13)),
        const SizedBox(width: 8),
        _DeltaChip(value: delta),
      ],
    );
  }
}

/// Small up/down delta pill in points. Neutral when within ±1.
class _DeltaChip extends StatelessWidget {
  final double value;
  const _DeltaChip({required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = value.round();
    final neutral = r.abs() < 1;
    final tint = neutral
        ? c.textMuted
        : (r > 0 ? c.positive : c.negative);
    final icon = neutral
        ? LucideIcons.minus
        : (r > 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: tint),
          const SizedBox(width: 3),
          Text('${r > 0 ? '+' : ''}$r',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tint,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

// ── Performance patterns (weekday + time of day) ───────────────

class _PatternsCard extends StatelessWidget {
  final AnalyticsData data;
  const _PatternsCard({required this.data});

  static const _wdLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S']; // Mon..Sun
  static const _pLabels = ['Morn', 'Aft', 'Eve', 'Night'];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wd = data.weekdays;
    final periods = data.periods;

    int bestWd = -1;
    double bestWdAvg = -1;
    for (int i = 0; i < wd.length; i++) {
      if (wd[i].days > 0 && wd[i].avgScore > bestWdAvg) {
        bestWdAvg = wd[i].avgScore;
        bestWd = i;
      }
    }
    int bestP = -1;
    double bestPRate = -1;
    for (int i = 0; i < periods.length; i++) {
      if (periods[i].scheduled > 0 && periods[i].rate > bestPRate) {
        bestPRate = periods[i].rate;
        bestP = i;
      }
    }

    Widget caption(String s) => Text(s,
        style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: c.textSecondary));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERFORMANCE PATTERNS',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 14),
          caption('Avg score by weekday'),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: Row(
              children: [
                for (int i = 0; i < wd.length; i++)
                  _BarColumn(
                    frac: wd[i].avgScore / 100,
                    label: _wdLabels[i],
                    value: wd[i].days == 0 ? '—' : '${wd[i].avgScore.round()}',
                    color: c.accent,
                    highlight: i == bestWd,
                    empty: wd[i].days == 0,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 0.5, color: c.border),
          const SizedBox(height: 14),
          caption('Completion by time of day'),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: Row(
              children: [
                for (int i = 0; i < periods.length; i++)
                  _BarColumn(
                    frac: periods[i].rate,
                    label: _pLabels[i],
                    value: periods[i].scheduled == 0
                        ? '—'
                        : '${(periods[i].rate * 100).round()}%',
                    color: c.athletic,
                    highlight: i == bestP,
                    empty: periods[i].scheduled == 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final double frac;
  final String label;
  final String value;
  final Color color;
  final bool highlight;
  final bool empty;
  const _BarColumn({
    required this.frac,
    required this.label,
    required this.value,
    required this.color,
    required this.highlight,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final barColor = empty
        ? c.surfaceElevated
        : (highlight ? color : color.withValues(alpha: 0.35));
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor:
                      empty ? 0.04 : frac.clamp(0.04, 1.0).toDouble(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: empty ? c.textMuted : c.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                  color: highlight ? c.accent : c.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Wellness × performance correlation ─────────────────────────

class _WellnessVsScoreCard extends ConsumerWidget {
  const _WellnessVsScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final corrs = ref.watch(wellnessVsScoreProvider).valueOrNull ?? const [];
    if (corrs.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WELLNESS × PERFORMANCE',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 4),
          Text('Avg score on good days vs low days',
              style: AppType.meta.copyWith(color: c.textMuted)),
          const SizedBox(height: 12),
          for (int i = 0; i < corrs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _WellnessRow(corr: corrs[i]),
          ],
        ],
      ),
    );
  }
}

class _WellnessRow extends StatelessWidget {
  final WellnessCorrelation corr;
  const _WellnessRow({required this.corr});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(corr.label,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Row(
            children: [
              _MiniStat(
                  label: 'good', value: corr.highAvgScore, color: c.positive),
              const SizedBox(width: 14),
              _MiniStat(
                  label: 'low', value: corr.lowAvgScore, color: c.textMuted),
            ],
          ),
        ),
        _DeltaChip(value: corr.delta),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('${value.round()}',
            style: AppType.numMd.copyWith(color: color, fontSize: 15)),
        const SizedBox(width: 3),
        Text(label,
            style: AppType.meta.copyWith(color: c.textMuted)),
      ],
    );
  }
}

// ── Nutrition performance (links to Food → Insights) ───────────

class _NutritionCard extends ConsumerWidget {
  const _NutritionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final days = ref.watch(insightsRangeProvider);
    final week = ref.watch(rangeTotalsProvider).valueOrNull ?? const [];
    final targets = ref.watch(dailyTargetsProvider);
    final logged = week.where((d) => d.hasLogs).toList();

    int hits = 0;
    double proteinSum = 0;
    for (final d in logged) {
      if (targets.kcal > 0) {
        final r = d.totals.kcal / targets.kcal;
        if (r >= 0.85 && r <= 1.15) hits++;
      }
      proteinSum += d.totals.proteinG;
    }
    final adherence = logged.isEmpty ? 0.0 : hits / logged.length;
    final proteinAvg = logged.isEmpty ? 0.0 : proteinSum / logged.length;

    void openInsights() {
      ref.read(foodSubTabProvider.notifier).state = FoodSubTab.insights;
      context.go('/food');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('NUTRITION · LAST $days DAYS',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              Icon(LucideIcons.utensils, size: 14, color: c.textMuted),
            ],
          ),
          const SizedBox(height: 14),
          if (logged.isEmpty)
            Text('No food logged in this window.',
                style: AppType.meta.copyWith(color: c.textMuted))
          else
            Row(
              children: [
                Expanded(
                  child: _NutStat(
                    value: '${(adherence * 100).round()}%',
                    label: 'kcal on target',
                    tint: adherence >= 0.7
                        ? c.positive
                        : (adherence >= 0.4 ? c.amber : c.negative),
                  ),
                ),
                Container(width: 0.5, height: 36, color: c.border),
                Expanded(
                  child: _NutStat(
                    value: '${proteinAvg.round()}g',
                    label: targets.proteinG > 0
                        ? 'protein /day · goal ${targets.proteinG.round()}g'
                        : 'protein /day',
                    tint: c.textPrimary,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          InkWell(
            onTap: openInsights,
            borderRadius: BorderRadius.circular(AppRadii.button),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text('See full breakdown',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.accent)),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.arrowRight, size: 14, color: c.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutStat extends StatelessWidget {
  final String value;
  final String label;
  final Color tint;
  const _NutStat({required this.value, required this.label, required this.tint});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppType.numLg.copyWith(color: tint, fontSize: 22)),
        const SizedBox(height: 2),
        Text(label,
            style: AppType.meta.copyWith(color: c.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

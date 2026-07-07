part of 'progression_screen.dart';

// ────────────────────────────────────────────────────────────────────
// XP JOURNEY — cumulative curve + level-crossing log
// ────────────────────────────────────────────────────────────────────

class _JourneyCard extends ConsumerWidget {
  const _JourneyCard();

  static String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final histAsync = ref.watch(xpHistoryProvider);
    final info = ref.watch(currentLevelProvider);
    final deltasAsync = ref.watch(dailyXpDeltaProvider);

    Widget shell(Widget child) => Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: child,
        );

    Widget hint(String msg) => SizedBox(
          height: 90,
          child: Center(
            child: Text(msg,
                textAlign: TextAlign.center,
                style: AppType.meta.copyWith(color: c.textMuted)),
          ),
        );

    return histAsync.when(
      loading: () => shell(hint('Loading your journey…')),
      error: (_, _) => shell(hint('Journey unavailable right now.')),
      data: (hist) {
        if (hist.points.length < 2) {
          return shell(hint(
              'Your XP curve appears here after a couple of logged days.'));
        }
        final points = hist.points;
        final lastCum = points.last.cumulative;
        final nextThreshold = xpForLevel(info.level + 1);
        final maxY =
            math.max(lastCum.toDouble(), nextThreshold.toDouble()) * 1.08;
        final milestoneKeys = {
          for (final m in hist.milestones)
            '${m.date.year}-${m.date.month}-${m.date.day}'
        };
        final spots = [
          for (int i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].cumulative.toDouble())
        ];
        final lastMilestoneDate = hist.milestones.isEmpty
            ? points.first.date
            : hist.milestones.last.date;
        final daysAtRank =
            DateTime.now().difference(lastMilestoneDate).inDays.clamp(0, 9999);
        final rank = rankFor(info.level);
        final recent = hist.milestones.reversed.take(3).toList();

        // Projected level-up from trailing XP pace (mean of the last ~14
        // logged days). Only meaningful while the XP gate is still ahead.
        String? projection;
        final deltas = deltasAsync.valueOrNull;
        if (!info.xpGatePassed && deltas != null && deltas.isNotEmpty) {
          final recentDeltas =
              deltas.length > 14 ? deltas.sublist(deltas.length - 14) : deltas;
          final vel = recentDeltas.fold<int>(0, (a, e) => a + e.delta) /
              recentDeltas.length;
          final remainingXp = nextThreshold - lastCum;
          if (vel > 0 && remainingXp > 0) {
            final etaDays = (remainingXp / vel).ceil();
            if (etaDays >= 0 && etaDays <= 3650) {
              final date = DateTime.now().add(Duration(days: etaDays));
              projection =
                  '~${vel.round()} XP/day · L${info.level + 1} by ${DateFormat('d MMM').format(date)}';
            }
          }
        }

        return shell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt(lastCum),
                    style: AppType.numLg
                        .copyWith(color: c.textPrimary, fontSize: 26)),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('total XP earned',
                      style: AppType.meta.copyWith(color: c.textMuted)),
                ),
                const Spacer(),
                Text('Day ${daysAtRank + 1} as ${rank.tier.name}',
                    style: AppType.meta.copyWith(color: c.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY <= 0 ? 100 : maxY,
                  clipData: const FlClipData.all(),
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
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
                        interval:
                            ((points.length - 1) / 4).clamp(1, double.infinity),
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('d/M').format(points[i].date),
                              style: AppType.overline
                                  .copyWith(color: c.textMuted, fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: nextThreshold.toDouble(),
                      color: c.accent.withValues(alpha: 0.6),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: AppType.overline
                            .copyWith(color: c.accent, fontSize: 9),
                        labelResolver: (_) => 'L${info.level + 1}',
                      ),
                    ),
                  ]),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.18,
                      preventCurveOverShooting: true,
                      color: c.accent,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, _) {
                          final i = spot.x.toInt();
                          if (i < 0 || i >= points.length) return false;
                          final d = points[i].date;
                          return milestoneKeys
                              .contains('${d.year}-${d.month}-${d.day}');
                        },
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 3.5,
                          color: c.onAccent,
                          strokeWidth: 2,
                          strokeColor: c.accent,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: c.accent.withValues(alpha: 0.10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (projection != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LucideIcons.trendingUp, size: 14, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(projection,
                        style: AppType.meta.copyWith(color: c.textSecondary)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (recent.isEmpty)
              Row(
                children: [
                  Icon(LucideIcons.flag, size: 14, color: c.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'First level-up ahead — ${_fmt((nextThreshold - lastCum).clamp(0, nextThreshold))} XP to Level ${info.level + 1}.',
                      style: AppType.meta.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  for (final m in recent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: Text('${m.level}',
                                style: AppType.numMd.copyWith(
                                    color: c.accent, fontSize: 11)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Reached ${rankFor(m.level).tier.name}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          Text(DateFormat('d MMM').format(m.date),
                              style: AppType.meta.copyWith(color: c.textMuted)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ));
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// MISC
// ────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final String? trailingLabel;
  const _Section({required this.label, this.trailingLabel});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
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
          if (trailingLabel != null) ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                trailingLabel!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: c.accent,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

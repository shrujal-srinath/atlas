part of 'analytics_screen.dart';

// ── Score trend chart ──────────────────────────────────────────

class _ScoreTrendChart extends StatefulWidget {
  final AnalyticsData data;
  const _ScoreTrendChart({required this.data});

  @override
  State<_ScoreTrendChart> createState() => _ScoreTrendChartState();
}

class _ScoreTrendChartState extends State<_ScoreTrendChart> {
  bool _showMonth = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final scores = _showMonth ? widget.data.monthScores : widget.data.weekScores;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Text('SCORE TREND',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              _ChipToggle(
                labels: const ['7D', '28D'],
                selected: _showMonth ? 1 : 0,
                onChanged: (i) => setState(() => _showMonth = i == 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: c.border,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 10,
                          color: c.textDim,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: _showMonth ? 7 : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= scores.length) return const SizedBox();
                        final day = scores[idx].date;
                        return Text(
                          '${day.day}',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 10,
                            color: c.textDim,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles()),
                  rightTitles: const AxisTitles(sideTitles: SideTitles()),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      scores.length,
                      (i) => FlSpot(i.toDouble(), scores[i].score),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: c.accent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: !_showMonth,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: c.accent,
                        strokeWidth: 2,
                        strokeColor: c.surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.accent.withValues(alpha: 0.2),
                          c.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => c.surfaceElevated,
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.round()}%',
                        TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip toggle ────────────────────────────────────────────────

class _ChipToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const _ChipToggle({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? c.accent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: active
                    ? Border.all(color: c.accent.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? c.accent : c.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Section trends over time ───────────────────────────────────

class _SectionTrendChart extends ConsumerStatefulWidget {
  const _SectionTrendChart();
  @override
  ConsumerState<_SectionTrendChart> createState() =>
      _SectionTrendChartState();
}

class _SectionTrendChartState extends ConsumerState<_SectionTrendChart> {
  static const _ranges = [7, 30, 90];
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final async = ref.watch(sectionTrendProvider(_days));

    Widget box(Widget child) => SizedBox(height: 170, child: Center(child: child));

    Widget chart(SectionTrend t) {
      final len = t.dates.length;
      if (len < 2) {
        return box(Text('Not enough data yet.',
            style: AppType.meta.copyWith(color: c.textMuted)));
      }
      LineChartBarData barFor(HabitSection s) => LineChartBarData(
            spots: [
              for (int i = 0; i < len; i++)
                FlSpot(i.toDouble(), t.series[s]![i].clamp(0.0, 1.1))
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            color: _sectionColor(context, s),
            barWidth: 2,
            dotData: const FlDotData(show: false),
          );
      return SizedBox(
        height: 170,
        child: LineChart(LineChartData(
          minX: 0,
          maxX: (len - 1).toDouble(),
          minY: 0,
          maxY: 1.1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.5,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 0.5,
                getTitlesWidget: (v, _) => Text('${(v * 100).round()}',
                    style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 10,
                        color: c.textDim)),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: ((len - 1) / 4).clamp(1, double.infinity),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= len) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${t.dates[i].day}',
                        style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 10,
                            color: c.textDim)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            for (final s in HabitSection.values) barFor(s)
          ],
        )),
      );
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
              Text('SECTION TRENDS',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              _ChipToggle(
                labels: const ['7D', '30D', '90D'],
                selected: _ranges.indexOf(_days),
                onChanged: (i) => setState(() => _days = _ranges[i]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in HabitSection.values)
                _LegendSwatch(
                    color: _sectionColor(context, s), label: _sectionLabel(s)),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            data: chart,
            loading: () => box(
                CircularProgressIndicator(color: c.accent, strokeWidth: 2)),
            error: (_, _) => box(Text('Trends unavailable.',
                style: AppType.meta.copyWith(color: c.textMuted))),
          ),
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendSwatch({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.textSecondary)),
      ],
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// One line on a [StatsLineChart].
class ChartSeries {
  final List<double> values;
  final Color color;
  final String? label;

  /// Draw a soft gradient area under the line — use for the single hero metric.
  final bool fill;
  const ChartSeries(this.values, this.color, {this.label, this.fill = false});
}

/// The single, consistent line chart for the whole Stats section. Tooltips are
/// ON (the old section-trend chart had them disabled), supports one or many
/// series, an optional dashed goal line, date-aware x labels, and the dark
/// linen+ruby styling. Replaces the bespoke per-screen `LineChart` configs.
class StatsLineChart extends StatelessWidget {
  final List<ChartSeries> series;

  /// One date per x index (oldest → newest). Drives x labels + tooltip header.
  final List<DateTime>? dates;
  final double minY;
  final double maxY;
  final double yInterval;
  final double height;

  /// Optional horizontal target line (e.g. a goal value).
  final double? goalLine;
  final Color? goalColor;
  final String? goalLabel;

  /// Left-axis + tooltip number formatting. Defaults to integers.
  final String Function(double)? yLabel;
  final String Function(double)? tooltipValue;

  /// Emphasize each series' final point with a ringed dot ("today").
  final bool emphasizeLast;

  const StatsLineChart({
    super.key,
    required this.series,
    this.dates,
    this.minY = 0,
    this.maxY = 100,
    this.yInterval = 25,
    this.height = 180,
    this.goalLine,
    this.goalColor,
    this.goalLabel,
    this.yLabel,
    this.tooltipValue,
    this.emphasizeLast = false,
  });

  int get _len => series.isEmpty ? 0 : series.first.values.length;

  String _fmtY(double v) => yLabel?.call(v) ?? v.round().toString();
  String _fmtTip(double v) => tooltipValue?.call(v) ?? v.round().toString();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_len < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Not enough data yet.',
              style: AppType.meta.copyWith(color: c.textMuted)),
        ),
      );
    }

    final lastX = (_len - 1).toDouble();
    // ~5 x labels regardless of window length.
    final xInterval = (lastX / 4).clamp(1, double.infinity).toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastX,
          minY: minY,
          maxY: maxY,
          // Clip the line/area to the plot rect so a curved overshoot never
          // paints over the axis labels.
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: yInterval,
                getTitlesWidget: (v, _) => Text(
                  _fmtY(v),
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
                showTitles: dates != null,
                reservedSize: 20,
                interval: xInterval,
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (dates == null || i < 0 || i >= dates!.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${dates![i].day}',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 10,
                        color: c.textDim,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: goalLine == null
              ? const ExtraLinesData()
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: goalLine!,
                    color: (goalColor ?? c.textMuted).withValues(alpha: 0.6),
                    strokeWidth: 1.2,
                    dashArray: [5, 4],
                    label: HorizontalLineLabel(
                      show: goalLabel != null,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: goalColor ?? c.textMuted,
                      ),
                      labelResolver: (_) => goalLabel!,
                    ),
                  ),
                ]),
          lineBarsData: [
            for (final s in series)
              LineChartBarData(
                spots: [
                  for (int i = 0; i < s.values.length; i++)
                    FlSpot(i.toDouble(), s.values[i]),
                ],
                isCurved: true,
                curveSmoothness: 0.28,
                preventCurveOverShooting: true,
                color: s.color,
                barWidth: 2.4,
                dotData: emphasizeLast
                    ? FlDotData(
                        show: true,
                        checkToShowDot: (spot, _) => spot.x == lastX,
                        getDotPainter: (spot, _, bar, _) => FlDotCirclePainter(
                          radius: 4,
                          color: bar.color ?? c.accent,
                          strokeWidth: 2,
                          strokeColor: c.surface,
                        ),
                      )
                    : const FlDotData(show: false),
                belowBarData: s.fill
                    ? BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            s.color.withValues(alpha: 0.22),
                            s.color.withValues(alpha: 0.0),
                          ],
                        ),
                      )
                    : BarAreaData(show: false),
              ),
          ],
          lineTouchData: LineTouchData(
            // A thin accent guide-line + a small ringed dot — not fl_chart's
            // default fat "bulb".
            getTouchedSpotIndicator: (barData, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(
                    color: (barData.color ?? c.accent).withValues(alpha: 0.30),
                    strokeWidth: 1.5,
                  ),
                  FlDotData(
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 3.5,
                      color: bar.color ?? c.accent,
                      strokeWidth: 2,
                      strokeColor: c.surface,
                    ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surfaceElevated,
              tooltipRoundedRadius: 10,
              tooltipMargin: 10,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final s = series[spot.barIndex];
                  final header = (spot.barIndex == 0 && dates != null)
                      ? '${_dateLabel(dates![spot.x.round()])}\n'
                      : '';
                  final name = s.label != null ? '${s.label}  ' : '';
                  return LineTooltipItem(
                    '$header$name${_fmtTip(spot.y)}',
                    TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: s.color,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
        // Fluid entrance + range-swap animation.
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  static const _mon = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _dateLabel(DateTime d) => '${_mon[d.month]} ${d.day}';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/providers/analytics_provider.dart';
import 'stats_primitives.dart';

/// CONSISTENCY — a Duolingo-style streak hero (flame + this-week strip) and a
/// GitHub-style intensity heatmap with a range toggle. Both read the unified
/// score, so the streak here matches the Overview badge exactly.
class StatsConsistency extends StatelessWidget {
  const StatsConsistency({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _StreakHeroCard(),
        SizedBox(height: 12),
        _IntensityCard(),
      ],
    );
  }
}

// ══════════════════════════ Streak hero (Duolingo) ══════════════════════════

class _StreakHeroCard extends ConsumerWidget {
  const _StreakHeroCard();

  static const _wk = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final data = ref.watch(scoreStreakSummaryProvider).valueOrNull;
    final current = data?.current ?? 0;
    final best = data?.best ?? 0;
    final week = data?.week ?? const <DayWin>[];
    final amber = c.amber;

    final todayState =
        week.isEmpty ? DayWinState.rest : week.last.state;
    final toBeat = best - current;
    final String msg;
    if (current == 0) {
      msg = 'Score 50+ today to light your streak.';
    } else if (todayState == DayWinState.miss) {
      msg = 'Finish a bit more today to keep your $current-day streak.';
    } else if (toBeat > 0) {
      msg = '$toBeat ${toBeat == 1 ? 'day' : 'days'} to beat your best ($best).';
    } else {
      msg = 'Best streak ever — keep it alive!';
    }

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Flame coin with the count inside.
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [amber, Color.lerp(amber, c.accent, 0.35)!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: amber.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.flame, size: 15, color: Colors.white),
                    Text('$current',
                        style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 21,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('day${current == 1 ? '' : 's'} streak',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                        const SizedBox(width: 8),
                        Text('best $best',
                            style: AppType.meta.copyWith(color: c.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(msg,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                            height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // This-week strip.
          Row(
            children: [
              for (int i = 0; i < week.length; i++)
                Expanded(
                  child: _DayDot(
                    label: _wk[week[i].date.weekday - 1],
                    state: week[i].state,
                    isToday: i == week.length - 1,
                    amber: amber,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final DayWinState state;
  final bool isToday;
  final Color amber;
  const _DayDot({
    required this.label,
    required this.state,
    required this.isToday,
    required this.amber,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Color fill;
    Widget? glyph;
    Border? border;
    switch (state) {
      case DayWinState.win:
        fill = amber;
        glyph = const Icon(LucideIcons.check, size: 14, color: Colors.white);
      case DayWinState.miss:
        fill = c.surfaceElevated;
        glyph = Icon(LucideIcons.x, size: 12, color: c.textMuted);
      case DayWinState.rest:
        fill = Colors.transparent;
        border = Border.all(color: c.border, width: 1);
      case DayWinState.future:
        fill = Colors.transparent;
        border = Border.all(color: c.border, width: 1);
    }
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday ? c.textPrimary : c.textMuted)),
        const SizedBox(height: 6),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: border,
          ),
          alignment: Alignment.center,
          child: glyph,
        ),
        const SizedBox(height: 5),
        // Today marker.
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: isToday ? amber : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════ Intensity heatmap (GitHub) ══════════════════════

class _IntensityCard extends ConsumerStatefulWidget {
  const _IntensityCard();
  @override
  ConsumerState<_IntensityCard> createState() => _IntensityCardState();
}

class _IntensityCardState extends ConsumerState<_IntensityCard> {
  // 1Y is intentionally omitted until there's ~6 months of history (Phase B).
  static const _ranges = [30, 90, 180];
  static const _labels = ['30D', '3M', '6M'];
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final map = ref.watch(dayIntensityProvider(_days)).valueOrNull ?? const {};
    final activeDays = map.values.where((r) => r > 0).length;

    return StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('INTENSITY', style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              StatsRangeToggle(
                labels: _labels,
                selected: _ranges.indexOf(_days),
                onChanged: (i) => setState(() => _days = _ranges[i]),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('$activeDays active ${activeDays == 1 ? 'day' : 'days'} · '
              'effort per day',
              style: AppType.meta.copyWith(color: c.textDim)),
          const SizedBox(height: 14),
          _Heatmap(rateByDay: map, days: _days),
        ],
      ),
    );
  }
}

/// GitHub-style effort grid: weeks as columns (oldest → newest), weekdays as
/// rows, each cell shaded by that day's completion rate.
class _Heatmap extends StatelessWidget {
  final Map<DateTime, double> rateByDay;
  final int days;
  const _Heatmap({required this.rateByDay, required this.days});

  static const _mon = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Color _cellColor(AppPalette c, Color accent, DateTime d, DateTime today) {
    if (d.isAfter(today)) return Colors.transparent;
    final key = DateTime(d.year, d.month, d.day);
    if (!rateByDay.containsKey(key)) {
      return c.surfaceElevated.withValues(alpha: 0.35); // rest / no data
    }
    final r = rateByDay[key]!;
    if (r >= 0.95) return accent;
    if (r >= 0.75) return accent.withValues(alpha: 0.62);
    if (r >= 0.50) return accent.withValues(alpha: 0.40);
    if (r >= 0.25) return accent.withValues(alpha: 0.22);
    if (r > 0) return accent.withValues(alpha: 0.10);
    return c.surfaceElevated; // scheduled but 0% — a visible miss
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = c.accent;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final weeks = ((days + 6) / 7).ceil();
    final gridStart = startOfWeek.subtract(Duration(days: (weeks - 1) * 7));

    return LayoutBuilder(builder: (context, box) {
      const gap = 3.0;
      const labelW = 16.0;
      final cell = (((box.maxWidth - labelW) - gap * (weeks - 1)) / weeks)
          .clamp(9.0, 15.0);
      final colW = cell + gap;

      // Month labels row.
      final monthLabels = <Widget>[];
      int? lastMonth;
      for (int col = 0; col < weeks; col++) {
        final ws = gridStart.add(Duration(days: col * 7));
        final isNew = ws.month != lastMonth;
        lastMonth = ws.month;
        monthLabels.add(SizedBox(
          width: colW,
          child: isNew
              ? Text(_mon[ws.month],
                  style: TextStyle(
                      fontFamily: 'SpaceGrotesk', fontSize: 9, color: c.textDim))
              : const SizedBox.shrink(),
        ));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: labelW),
            child: Row(children: monthLabels),
          ),
          const SizedBox(height: 4),
          for (int row = 0; row < 7; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row == 6 ? 0 : gap),
              child: Row(
                children: [
                  SizedBox(
                    width: labelW,
                    child: (row == 0 || row == 2 || row == 4)
                        ? Text(const ['M', '', 'W', '', 'F', '', ''][row],
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 8.5,
                                color: c.textDim))
                        : null,
                  ),
                  for (int col = 0; col < weeks; col++)
                    Padding(
                      padding:
                          EdgeInsets.only(right: col == weeks - 1 ? 0 : gap),
                      child: () {
                        final day = gridStart.add(Duration(days: col * 7 + row));
                        return Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: _cellColor(c, accent, day, today),
                            borderRadius: BorderRadius.circular(3),
                            border: day == today
                                ? Border.all(color: accent, width: 1)
                                : null,
                          ),
                        );
                      }(),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('less',
                  style: AppType.meta.copyWith(color: c.textDim, fontSize: 9.5)),
              const SizedBox(width: 5),
              for (final a in [0.10, 0.22, 0.40, 0.62, 1.0])
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: a),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              Text('more',
                  style: AppType.meta.copyWith(color: c.textDim, fontSize: 9.5)),
            ],
          ),
        ],
      );
    });
  }
}

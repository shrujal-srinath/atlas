import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/models.dart';
import '../../home/providers/home_providers.dart';
import '../../home/widgets/triple_arc_ring.dart';
import '../../xp/leveling_providers.dart';
import '../../xp/rank_tier.dart';
import '../stats_baseline.dart';
import 'stats_primitives.dart';

/// Overview hero — today's score ring, the headline streak/rank, and the
/// motivating "recent vs your norm" baseline read with a 30-day sparkline.
/// Tapping opens the full score breakdown.
class StatsOverview extends ConsumerWidget {
  const StatsOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final score = ref.watch(homeScoreProvider(today)).valueOrNull;
    final series = ref.watch(dailyScoreSeriesProvider(30)).valueOrNull ?? const [];
    final streak = ref.watch(currentScoreStreakProvider).valueOrNull ?? 0;
    final level = ref.watch(currentLevelProvider);
    final rank = rankFor(level.level);

    // Only real days with scheduled habits — no-data days would otherwise draw
    // a misleading flat-zero floor and a false cliff on the sparkline.
    final scores = [for (final p in series) if (!p.isFuture && p.total > 0) p.score];
    final baseline = computeScoreBaseline(scores, recentWindow: 7);

    final ath = (score?.sectionPct[HabitSection.athletic] ?? 0) / 100.0;
    final mind = (score?.sectionPct[HabitSection.mind] ?? 0) / 100.0;
    final body = (score?.sectionPct[HabitSection.body] ?? 0) / 100.0;

    return StatsCard(
      onTap: () => context.push('/stats/score'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TripleArcRing(
                score: (score?.score ?? 0).toDouble(),
                athleticPct: ath,
                buildingPct: mind,
                breakingPct: body,
                size: 92,
                centerFontSize: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text("TODAY'S SCORE",
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: c.textMuted,
                            )),
                        const Spacer(),
                        Icon(LucideIcons.arrowUpRight, size: 15, color: c.textMuted),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _Pill(text: '${score?.done ?? 0}/${score?.total ?? 0} done',
                            color: c.textSecondary),
                        _Pill(text: 'proj ${score?.projectedScore ?? 0}%', color: c.accent),
                        _Pill(text: '$streak-day', icon: LucideIcons.flame, color: c.amber),
                        _Pill(text: rank.tier.name, icon: LucideIcons.shield, color: c.mind),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 0.5, color: c.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('LAST 30 DAYS',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: c.textMuted,
                  )),
              const Spacer(),
              if (baseline.hasData) _BaselineDelta(baseline) else
                Text('avg ${baseline.recentAvg.round()}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
            ],
          ),
          const SizedBox(height: 10),
          Sparkline(
            points: [for (final s in scores) s.toDouble()],
            color: c.accent,
            height: 46,
            minY: 0,
            maxY: 100,
            baseline: baseline.hasData ? baseline.baselineAvg : null,
            baselineColor: c.textMuted,
            emphasizeLast: true,
            animate: true,
          ),
          if (baseline.hasData) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _DashSwatch(color: c.textMuted),
                const SizedBox(width: 6),
                Text('your ${baseline.baselineAvg.round()} norm',
                    style: AppType.meta.copyWith(color: c.textDim)),
                const Spacer(),
                Text('now ${scores.isEmpty ? '—' : scores.last}',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A tiny dashed-line swatch for the "norm" legend.
class _DashSwatch extends StatelessWidget {
  final Color color;
  const _DashSwatch({required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        height: 2,
        child: CustomPaint(painter: _DashPainter(color)),
      );
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 1), Offset((x + 4).clamp(0, size.width), 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

/// "▲ 12% vs your norm" — the directional motivation line.
class _BaselineDelta extends StatelessWidget {
  final ScoreBaseline b;
  const _BaselineDelta(this.b);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final up = b.isUp;
    final color = up ? c.positive : c.negative;
    final pct = b.deltaPct.abs().round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? LucideIcons.trendingUp : LucideIcons.trendingDown,
            size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          pct == 0 ? 'on par with your norm' : '$pct% vs your norm',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
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

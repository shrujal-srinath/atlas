import 'dart:math' as math;
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
import '../widgets/month_calendar.dart';

/// Stats tab landing page — a living performance dashboard. Each section is a
/// graphical preview wired to live data (score ring, sparkline, XP bar,
/// section trends, month heatmap) rather than a plain navigation row; tapping
/// any card opens its full deep-dive. See [[home-master-plan]] §0 for the IA.
class StatsHomeScreen extends ConsumerWidget {
  const StatsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 18, AppSpace.screenH, 118),
          children: [
            Text('STATS', style: AppType.overline.copyWith(color: c.textMuted)),
            const SizedBox(height: 6),
            Text('Performance Insights', style: t.h1),
            const SizedBox(height: 20),

            // Hero: today's score as a live graphical readout.
            const _ScorePreviewCard(),
            const SizedBox(height: 12),

            // Bento row — rank progression + what's left today.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(child: _ProgressionTile()),
                  SizedBox(width: 12),
                  Expanded(child: _GlanceTile()),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // The month — day-by-day effort heatmap on a real calendar.
            const MonthCalendarCard(),
            const SizedBox(height: 12),

            // 7-day section trends.
            const _TrendsPreviewCard(),
            const SizedBox(height: 12),

            // Secondary destinations.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SecondaryTile(
                      title: 'Habits Library',
                      subtitle: 'Active & archived',
                      icon: LucideIcons.bookOpen,
                      accent: c.body,
                      onTap: () => context.push('/habits'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SecondaryTile(
                      title: 'Rank Ladder',
                      subtitle: 'Rookie → Legend',
                      icon: LucideIcons.trophy,
                      accent: c.amber,
                      onTap: () => context.push('/stats/ranks'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Shared bits
// ════════════════════════════════════════════════════════════════════

BoxDecoration _cardDeco(BuildContext context) => BoxDecoration(
      color: context.c.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: context.c.border, width: 0.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 9,
          offset: const Offset(0, 2),
        ),
      ],
    );

/// Overline label + a trailing "open" chevron, used atop every preview card.
class _PreviewHead extends StatelessWidget {
  final String label;
  final Color? labelColor;
  final IconData? icon;
  const _PreviewHead({required this.label, this.labelColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: labelColor ?? c.textMuted),
          const SizedBox(width: 6),
        ],
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: labelColor ?? c.textMuted,
          ),
        ),
        const Spacer(),
        Icon(LucideIcons.arrowUpRight, size: 15, color: c.textMuted),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const _StatPill({required this.text, required this.color, this.icon});

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

// ════════════════════════════════════════════════════════════════════
// Today's Score — hero
// ════════════════════════════════════════════════════════════════════

class _ScorePreviewCard extends ConsumerWidget {
  const _ScorePreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final score = ref.watch(homeScoreProvider(today)).valueOrNull;
    final week = ref.watch(homeWeekProvider(today)).valueOrNull ?? const [];
    final streak = ref.watch(currentScoreStreakProvider).valueOrNull ?? 0;

    final ath = (score?.sectionPct[HabitSection.athletic] ?? 0) / 100.0;
    final mind = (score?.sectionPct[HabitSection.mind] ?? 0) / 100.0;
    final body = (score?.sectionPct[HabitSection.body] ?? 0) / 100.0;

    final past = week.where((d) => !d.isFuture).toList();
    final points = past.map((d) => d.score).toList();
    final scored = past.where((d) => d.total > 0).map((d) => d.score).toList();
    final avg = scored.isEmpty
        ? 0
        : (scored.reduce((a, b) => a + b) / scored.length).round();

    return GestureDetector(
      onTap: () => context.push('/stats/score'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: _cardDeco(context),
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
                  size: 96,
                  centerFontSize: 30,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _PreviewHead(label: "Today's Score"),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _StatPill(
                            text: '${score?.done ?? 0}/${score?.total ?? 0} done',
                            color: c.textSecondary,
                          ),
                          _StatPill(
                            text: 'proj ${score?.projectedScore ?? 0}%',
                            color: c.accent,
                          ),
                          _StatPill(
                            text: '$streak-day',
                            icon: LucideIcons.flame,
                            color: c.amber,
                          ),
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
                Text(
                  '7-DAY',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: c.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  'avg $avg',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: CustomPaint(
                size: const Size.fromHeight(38),
                painter: _MiniSpark(
                  points: points,
                  color: c.accent,
                  fill: c.accent.withValues(alpha: 0.10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSpark extends CustomPainter {
  final List<int> points;
  final Color color;
  final Color fill;
  _MiniSpark({required this.points, required this.color, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final stepX = points.length > 1 ? w / (points.length - 1) : w;
    final maxV = math.max(100, points.fold<int>(0, math.max));
    Offset ptAt(int i) =>
        Offset(i * stepX, h - (points[i] / maxV) * h * 0.92 - h * 0.04);

    final line = Path()..moveTo(ptAt(0).dx, ptAt(0).dy);
    for (int i = 1; i < points.length; i++) {
      line.lineTo(ptAt(i).dx, ptAt(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Endpoint dot.
    if (points.isNotEmpty) {
      final last = ptAt(points.length - 1);
      canvas.drawCircle(last, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniSpark old) => old.points != points;
}

// ════════════════════════════════════════════════════════════════════
// Progression tile
// ════════════════════════════════════════════════════════════════════

class _ProgressionTile extends ConsumerWidget {
  const _ProgressionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final info = ref.watch(currentLevelProvider);
    final delta = ref.watch(todayLevelXpDeltaProvider);
    final rank = rankFor(info.level);

    return GestureDetector(
      onTap: () => context.push('/stats/progression'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: _cardDeco(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewHead(label: 'Rank', icon: LucideIcons.zap, labelColor: c.amber),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.amber.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${info.level}',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.amber,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rank.tier.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        rank.subTier.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: info.progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: c.surfaceElevated,
                valueColor: AlwaysStoppedAnimation(c.amber),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  '${info.xpIntoLevel}/${info.xpForNextLevel} XP',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  delta >= 0 ? '+$delta today' : '$delta today',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: delta >= 0 ? c.positive : c.negative,
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

// ════════════════════════════════════════════════════════════════════
// Glance tile — what's left today
// ════════════════════════════════════════════════════════════════════

class _GlanceTile extends ConsumerWidget {
  const _GlanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final tasks = ref.watch(homeTasksProvider(today)).valueOrNull ?? const [];
    final total = tasks.length;
    final done = tasks.where((t) => t.isCompleted).length;
    final left = total - done;
    final ratio = total == 0 ? 1.0 : done / total;
    final allDone = total > 0 && left == 0;

    return GestureDetector(
      onTap: () => context.push('/stats/trends'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: _cardDeco(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewHead(
                label: 'Today', icon: LucideIcons.layoutGrid, labelColor: c.athletic),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  allDone ? '0' : '$left',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -1,
                    color: allDone ? c.positive : c.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    allDone ? 'all clear' : 'left to do',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: c.surfaceElevated,
                valueColor: AlwaysStoppedAnimation(allDone ? c.positive : c.athletic),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '$done of $total done',
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
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Trends preview — 7-day section averages
// ════════════════════════════════════════════════════════════════════

class _TrendsPreviewCard extends ConsumerWidget {
  const _TrendsPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final week = ref.watch(homeWeekProvider(today)).valueOrNull ?? const [];
    final days = week.where((d) => !d.isFuture && d.total > 0).toList();

    double avgOf(HabitSection s) {
      if (days.isEmpty) return 0;
      final sum =
          days.fold<int>(0, (a, d) => a + (d.sectionPct[s] ?? 0));
      return sum / days.length;
    }

    final overall = days.isEmpty
        ? 0
        : (days.fold<int>(0, (a, d) => a + d.score) / days.length).round();

    return GestureDetector(
      onTap: () => context.push('/stats/trends'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: _cardDeco(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewHead(
                label: 'Trends · 7-day',
                icon: LucideIcons.lineChart,
                labelColor: c.mind),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$overall',
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'weekly average',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTrendBar(
              label: 'Athletic',
              pct: avgOf(HabitSection.athletic),
              color: HabitSection.athletic.color(c),
            ),
            const SizedBox(height: 10),
            _SectionTrendBar(
              label: 'Mind',
              pct: avgOf(HabitSection.mind),
              color: HabitSection.mind.color(c),
            ),
            const SizedBox(height: 10),
            _SectionTrendBar(
              label: 'Body',
              pct: avgOf(HabitSection.body),
              color: HabitSection.body.color(c),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTrendBar extends StatelessWidget {
  final String label;
  final double pct; // 0..100+
  final Color color;
  const _SectionTrendBar({
    required this.label,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: c.surfaceElevated,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            '${pct.round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Secondary destinations
// ════════════════════════════════════════════════════════════════════

class _SecondaryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _SecondaryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: _cardDeco(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
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
    );
  }
}

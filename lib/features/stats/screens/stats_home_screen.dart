import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/consistency_section.dart';
import '../widgets/overview_section.dart';
import '../widgets/performance_section.dart';
import '../widgets/pertask_section.dart';
import '../widgets/staying_clean_section.dart';
import '../widgets/stats_primitives.dart';
import '../widgets/wellness_section.dart';

/// Stats tab — one organized performance dashboard. Related information is
/// grouped under headed sections (Overview → Performance → Consistency →
/// Per-task → Wellness) rather than scattered across a hub + an 11-card Trends
/// dump. Every number flows from the shared score engine + batched series.
class StatsHomeScreen extends StatefulWidget {
  const StatsHomeScreen({super.key});

  @override
  State<StatsHomeScreen> createState() => _StatsHomeScreenState();
}

class _StatsHomeScreenState extends State<StatsHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Staggered fade + rise for section [i] (0-based, top → bottom). Plays once
  /// on first load; rebuilds (provider updates) land on the settled value.
  Widget _enter(int i, Widget child) {
    final start = (i * 0.05).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (_, w) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 14),
          child: w,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = context.t;

    Widget pad(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenH),
          child: child,
        );

    var i = 0;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 18, bottom: 118),
          children: [
            // Title
            _enter(
                i++,
                pad(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STATS',
                        style: AppType.overline.copyWith(color: c.textMuted)),
                    const SizedBox(height: 6),
                    Text('Performance Insights', style: t.h1),
                  ],
                ))),
            const SizedBox(height: 20),

            // OVERVIEW — score hero + baseline read.
            _enter(i++, pad(const StatsOverview())),
            const SizedBox(height: 28),

            // PERFORMANCE — trend, week-compare, patterns.
            _enter(
                i++,
                pad(const StatsSectionHeader(
                    title: 'Performance',
                    caption: 'Your score trend & momentum'))),
            const SizedBox(height: 12),
            _enter(i++, pad(const StatsPerformance())),
            const SizedBox(height: 28),

            // CONSISTENCY — calendar heatmap + streaks.
            _enter(
                i++,
                pad(const StatsSectionHeader(
                    title: 'Consistency',
                    caption: 'Your streak & effort heatmap'))),
            const SizedBox(height: 12),
            _enter(i++, pad(const StatsConsistency())),
            const SizedBox(height: 28),

            // STAYING CLEAN — negative ("avoid") habits. Self-pads, self-heads,
            // and renders nothing when there are no negatives.
            _enter(i++, const StatsStayingClean()),

            // PER-HABIT — every habit's streak + completion; tap for full stats.
            _enter(
                i++,
                pad(const StatsSectionHeader(
                    title: 'Per-habit',
                    caption: 'Streak, completion & trend · tap for full analytics'))),
            const SizedBox(height: 12),
            _enter(i++, pad(const StatsPerTask())),
            const SizedBox(height: 28),

            // WELLNESS — mood/energy/sleep + correlation. Self-pads.
            _enter(
                i++,
                pad(const StatsSectionHeader(
                    title: 'Wellness',
                    caption: 'Mood, energy & sleep vs performance'))),
            const SizedBox(height: 12),
            _enter(i++, const StatsWellness()),
            const SizedBox(height: 28),

            // Secondary destinations.
            _enter(
                i++,
                pad(IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _NavTile(
                          title: 'Progression',
                          subtitle: 'Levels & rank ladder',
                          icon: LucideIcons.trophy,
                          accent: c.amber,
                          onTap: () => context.push('/stats/progression'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NavTile(
                          title: 'Habits Library',
                          subtitle: 'Active & archived',
                          icon: LucideIcons.bookOpen,
                          accent: c.body,
                          onTap: () => context.push('/habits'),
                        ),
                      ),
                    ],
                  ),
                ))),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return StatsCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
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
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: c.textMuted)),
        ],
      ),
    );
  }
}

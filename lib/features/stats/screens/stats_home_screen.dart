import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

/// Stats tab landing page — four cards that route into the deep-dive screens.
/// Each card matches a section of the home page that can be tapped to "explain"
/// itself. See [[home-master-plan]] §0 for the full IA.
class StatsHomeScreen extends StatelessWidget {
  const StatsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 22),
            _StatsCard(
              title: "Today's Score",
              subtitle: 'Score ring, category breakdown, 7-day trend',
              icon: LucideIcons.target,
              accent: c.accent,
              onTap: () => context.push('/stats/score'),
            ),
            const SizedBox(height: 10),
            _StatsCard(
              title: 'Today at a Glance',
              subtitle: 'Heatmap, still-to-do, upcoming reminders',
              icon: LucideIcons.layoutGrid,
              accent: c.athletic,
              onTap: () => context.push('/stats/glance'),
            ),
            const SizedBox(height: 10),
            _StatsCard(
              title: 'Progression',
              subtitle: 'Rank, XP, earned today, achievements',
              icon: LucideIcons.zap,
              accent: c.amber,
              onTap: () => context.push('/stats/progression'),
            ),
            const SizedBox(height: 10),
            _StatsCard(
              title: 'Trends',
              subtitle: 'Weekly averages, streaks, leaderboards, wellness',
              icon: LucideIcons.lineChart,
              accent: c.mind,
              onTap: () => context.push('/stats/trends'),
            ),
            const SizedBox(height: 20),
            _StatsCard(
              title: 'Habits Library',
              subtitle: 'All habits — active and archived',
              icon: LucideIcons.bookOpen,
              accent: c.body,
              onTap: () => context.push('/habits'),
            ),
            const SizedBox(height: 10),
            _StatsCard(
              title: 'Rank Ladder',
              subtitle: 'Full ladder from Rookie to Legend',
              icon: LucideIcons.trophy,
              accent: c.accent,
              onTap: () => context.push('/stats/ranks'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _StatsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 9,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: c.textMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

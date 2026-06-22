part of 'analytics_screen.dart';

// ── Section breakdown ──────────────────────────────────────────

class _SectionBreakdown extends StatelessWidget {
  final List<SectionStats> sections;
  const _SectionBreakdown({required this.sections});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
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
          Text('TODAY\'S SECTIONS',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 14),
          for (final s in sections) ...[
            _SectionBar(stats: s),
            if (s != sections.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  final SectionStats stats;
  const _SectionBar({required this.stats});

  String get _label => switch (stats.section) {
        HabitSection.athletic => 'Athletic',
        HabitSection.body => 'Breaking',
        HabitSection.mind => 'Building',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = stats.section.color(c);
    final pct = (stats.rate * 100).round();

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${stats.completed}/${stats.total}',
              style: AppType.numMd.copyWith(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              style: AppType.numMd.copyWith(
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: c.surfaceElevated),
                FractionallySizedBox(
                  widthFactor: stats.rate.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Completion heatmap ─────────────────────────────────────────

class _CompletionHeatmap extends ConsumerWidget {
  const _CompletionHeatmap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final cells = ref.watch(consistencyHeatmapProvider(28)).valueOrNull ??
        const <HeatmapCell>[];
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
              Text('28-DAY CONSISTENCY',
                  style: AppType.overline.copyWith(color: c.textMuted)),
              const Spacer(),
              // Legend
              _LegendDot(color: c.surfaceElevated, label: '0%'),
              const SizedBox(width: 8),
              _LegendDot(color: c.accent.withValues(alpha: 0.3), label: '50%'),
              const SizedBox(width: 8),
              _LegendDot(color: c.accent, label: '100%'),
            ],
          ),
          const SizedBox(height: 14),
          if (cells.isEmpty)
            SizedBox(
              height: 80,
              child: Center(
                child: Text('Consistency fills in as you log days.',
                    style: AppType.meta.copyWith(color: c.textMuted)),
              ),
            )
          else
            ConsistencyHeatmap(
              cells: cells,
              showDayNumbers: true,
              markToday: true,
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            color: c.textDim,
          ),
        ),
      ],
    );
  }
}

// ── Streak leaderboard ─────────────────────────────────────────

class _StreakLeaderboard extends StatelessWidget {
  final List<HabitStreak> streaks;
  const _StreakLeaderboard({required this.streaks});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final top = streaks.take(8).toList();

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
          Text('ACTIVE STREAKS',
              style: AppType.overline.copyWith(color: c.textMuted)),
          const SizedBox(height: 12),
          for (int i = 0; i < top.length; i++) ...[
            _StreakRow(
              rank: i + 1,
              streak: top[i],
              maxStreak: top.first.streak,
            ),
            if (i < top.length - 1)
              Divider(height: 16, color: c.border.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  final int rank;
  final HabitStreak streak;
  final int maxStreak;
  const _StreakRow({
    required this.rank,
    required this.streak,
    required this.maxStreak,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final secColor = streak.habit.section.color(c);
    final barFraction = maxStreak > 0 ? streak.streak / maxStreak : 0.0;

    return Row(
      children: [
        // Rank
        SizedBox(
          width: 20,
          child: Text(
            '$rank',
            style: AppType.numMd.copyWith(
              color: rank <= 3 ? c.amber : c.textDim,
              fontSize: 13,
            ),
          ),
        ),
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: secColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Center(
            child: Icon(
              habitIcon(streak.habit.icon),
              size: 16,
              color: secColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Name + bar
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                streak.habit.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      Container(color: c.surfaceElevated),
                      FractionallySizedBox(
                        widthFactor: barFraction.clamp(0.0, 1.0),
                        child: Container(color: secColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Streak value
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.flame, size: 12, color: c.amber),
            const SizedBox(width: 3),
            Text(
              '${streak.streak}d',
              style: AppType.numMd.copyWith(
                color: c.amber,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared section helpers ─────────────────────────────────────

Color _sectionColor(BuildContext context, HabitSection s) => s.color(context.c);

String _sectionLabel(HabitSection s) => switch (s) {
      HabitSection.athletic => 'Athletic',
      HabitSection.mind => 'Building',
      HabitSection.body => 'Breaking',
    };

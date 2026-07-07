import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/dev/dev_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../../achievements/achievement_catalog.dart';
import '../../achievements/achievement_engine.dart';
import '../../achievements/achievement_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../home/providers/home_providers.dart';
import '../../home/scoring/score_engine.dart' show TaskContribution;
import '../../home/scoring/section_def.dart';
import '../../xp/leveling_engine.dart';
import '../../xp/leveling_providers.dart';
import '../../xp/models/level_prereq.dart';
import '../../xp/prereq_providers.dart';
import '../../xp/rank_tier.dart';

part 'progression_header.dart';
part 'progression_cards.dart';
part 'progression_journey.dart';

/// Progression — rank card on score-driven XP, today's delta ticker,
/// pre-req checklist, activity feed, and achievements grid.
class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final levelInfo = ref.watch(currentLevelProvider);
    final todayDelta = ref.watch(todayLevelXpDeltaProvider);
    final streak = ref.watch(currentScoreStreakProvider).valueOrNull ?? 0;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final score = ref.watch(homeScoreProvider(todayKey)).valueOrNull;
    final unlocked =
        ref.watch(unlockedAchievementsProvider).valueOrNull ?? const <String>{};
    final achProgress =
        ref.watch(achievementProgressProvider).valueOrNull ??
            const <AchievementProgress>[];
    final progressById = {for (final p in achProgress) p.id: p};
    final habits =
        ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final prereqProgress =
        ref.watch(prereqProgressProvider(levelInfo.level + 1)).valueOrNull ??
            const <PrereqProgress>[];

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(fallback: '/stats'),
        title: Text('Progression', style: t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 12, AppSpace.screenH, 118),
          children: [
            _StoryHeader(
              info: levelInfo,
              todayScore: score?.score ?? 0,
              todayDelta: todayDelta,
              streak: streak,
              milestonesMet: prereqProgress.where((p) => p.isMet).length,
              milestonesTotal: prereqProgress.length,
            ),
            const SizedBox(height: 14),
            _RankLadderLink(rank: rankFor(levelInfo.level)),
            const SizedBox(height: 22),
            _Section(
              label: 'NEXT-LEVEL MILESTONES',
              trailingLabel: prereqProgress.isEmpty
                  ? (levelInfo.xpGatePassed ? 'XP READY' : null)
                  : levelInfo.xpGatePassed &&
                          prereqProgress.any((p) => !p.isMet)
                      ? 'XP READY · ${prereqProgress.where((p) => p.isMet).length} / ${prereqProgress.length} DONE'
                      : '${prereqProgress.where((p) => p.isMet).length} / ${prereqProgress.length} done',
            ),
            const SizedBox(height: 8),
            _PrereqsCard(
              progress: prereqProgress,
              habits: habits,
              targetLevel: levelInfo.level + 1,
            ),
            const SizedBox(height: 22),
            _Section(
              label: 'ACTIVITY TODAY',
              trailingLabel: score == null ? null : '+$todayDelta XP',
            ),
            const SizedBox(height: 8),
            _ActivityCard(contribs: score?.perTaskContrib ?? const []),
            const SizedBox(height: 22),
            const _Section(label: 'DAILY XP'),
            const SizedBox(height: 8),
            const _XpBarsCard(),
            const SizedBox(height: 22),
            const _Section(label: 'XP JOURNEY'),
            const SizedBox(height: 8),
            const _JourneyCard(),
            const SizedBox(height: 22),
            _Section(
              label:
                  'ACHIEVEMENTS · ${unlocked.length} OF ${achievementCatalog.length}',
            ),
            const SizedBox(height: 8),
            _AchievementsGrid(unlocked: unlocked, progress: progressById),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Entry point to the full Rookie → Legend ladder — keeps the ladder as a part
/// of Progression (one rank hub) rather than a separate orphaned screen.
class _RankLadderLink extends StatelessWidget {
  final ({RankTier tier, RankSubTier subTier}) rank;
  const _RankLadderLink({required this.rank});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: () => context.push('/stats/ranks'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.trophy, size: 18, color: c.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rank ladder',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text('All tiers · ${rank.tier.name} now',
                      style: AppType.meta.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textDim),
          ],
        ),
      ),
    );
  }
}

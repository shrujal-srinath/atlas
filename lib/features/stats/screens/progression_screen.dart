import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/models/models.dart';
import '../../achievements/achievement_catalog.dart';
import '../../achievements/achievement_provider.dart';
import '../../habits/providers/habit_provider.dart';
import '../../home/providers/home_providers.dart';
import '../../home/scoring/score_engine.dart' show TaskContribution;
import '../../xp/leveling_engine.dart';
import '../../xp/leveling_providers.dart';
import '../../xp/models/level_prereq.dart';
import '../../xp/prereq_providers.dart';
import '../../xp/rank_tier.dart';

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
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final score = ref.watch(homeScoreProvider(todayKey)).valueOrNull;
    final unlocked =
        ref.watch(unlockedAchievementsProvider).valueOrNull ?? const <String>{};
    final habits =
        ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final prereqProgress =
        ref.watch(prereqProgressProvider(levelInfo.level + 1)).valueOrNull ??
            const <PrereqProgress>[];

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text('Progression', style: t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 12, AppSpace.screenH, 118),
          children: [
            _RankCard(info: levelInfo),
            const SizedBox(height: 10),
            _TodayDeltaTile(delta: todayDelta, score: score?.score ?? 0),
            const SizedBox(height: 22),
            _Section(
              label: 'NEXT-LEVEL MILESTONES',
              trailingLabel: prereqProgress.isEmpty
                  ? null
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
            _Section(
              label:
                  'ACHIEVEMENTS · ${unlocked.length} OF ${achievementCatalog.length}',
            ),
            const SizedBox(height: 8),
            _AchievementsGrid(unlocked: unlocked),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// RANK CARD
// ────────────────────────────────────────────────────────────────────

class _RankCard extends StatelessWidget {
  final LevelInfo info;
  const _RankCard({required this.info});

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final remaining = (info.xpForNextLevel - info.xpIntoLevel).clamp(0, info.xpForNextLevel);
    final rank = rankFor(info.level);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.34),
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HexBadge(level: info.level),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank.tier.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Rank · ${rank.subTier.label}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 11),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: info.progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.24),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '${_fmt(info.xpIntoLevel)} / ${_fmt(info.xpForNextLevel)} XP',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_fmt(remaining)} to L${info.level + 1}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HexBadge extends StatelessWidget {
  final int level;
  const _HexBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(58, 58), painter: _HexPainter()),
          Text(
            '$level',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 3;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final ang = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(ang);
      final y = cy + r * math.sin(ang);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) => false;
}

// ────────────────────────────────────────────────────────────────────
// TODAY DELTA TILE
// ────────────────────────────────────────────────────────────────────

class _TodayDeltaTile extends StatelessWidget {
  final int delta;
  final int score;
  const _TodayDeltaTile({required this.delta, required this.score});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final positive = delta >= 0;
    final tint = delta > 0
        ? c.positive
        : delta < 0
            ? c.negative
            : c.textMuted;
    final hint = delta > 0
        ? 'Today\'s score earning toward Level Up'
        : delta < 0
            ? 'Bad day — score below 50 is pulling XP down'
            : 'Day just starting — score = 50 break-even';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(
              positive
                  ? LucideIcons.trendingUp
                  : LucideIcons.trendingDown,
              size: 17,
              color: tint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Today · score $score',
                  style: AppType.overline.copyWith(
                    color: c.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: AppType.meta.copyWith(color: c.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${delta >= 0 ? '+' : ''}$delta XP',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: tint,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// PRE-REQS CHECKLIST
// ────────────────────────────────────────────────────────────────────

class _PrereqsCard extends ConsumerWidget {
  final List<PrereqProgress> progress;
  final List<Habit> habits;
  final int targetLevel;
  const _PrereqsCard({
    required this.progress,
    required this.habits,
    required this.targetLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    if (progress.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.target, size: 15, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No milestones set',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'XP threshold (2,100 pts) is your only gate to Level $targetLevel.',
              style: AppType.meta.copyWith(color: c.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => context.push('/level/prereq-picker/$targetLevel'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              child: const Text('Set milestones',
                  style: TextStyle(
                      fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < progress.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, thickness: 0.5, color: c.border, indent: 56),
            _PrereqRow(
              progress: progress[i],
              label: describePrereq(progress[i].def, habits),
            ),
          ],
          Divider(height: 1, thickness: 0.5, color: c.border),
          InkWell(
            onTap: () => context.push('/level/prereq-picker/$targetLevel'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(LucideIcons.plus, size: 14, color: c.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Add or edit milestones',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrereqRow extends StatelessWidget {
  final PrereqProgress progress;
  final String label;
  const _PrereqRow({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final met = progress.isMet;
    final tint = met ? c.positive : c.accent;
    final pct = progress.target <= 0
        ? 0.0
        : (progress.currentProgress / progress.target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              met ? LucideIcons.checkCircle2 : _kindIcon(progress.def.kind),
              size: 15,
              color: tint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: c.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation(tint),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${progress.currentProgress} / ${progress.target}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: met ? c.positive : c.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _kindIcon(PrereqKind k) => switch (k) {
      PrereqKind.habitCompletions => LucideIcons.checkSquare,
      PrereqKind.streakDays => LucideIcons.flame,
      PrereqKind.perfectDays => LucideIcons.target,
      PrereqKind.nutritionDays => LucideIcons.utensils,
    };

// ────────────────────────────────────────────────────────────────────
// ACTIVITY TODAY (derived from score engine's contributions)
// ────────────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final List<TaskContribution> contribs;
  const _ActivityCard({required this.contribs});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = contribs.where((c) => c.isCompleted).toList()
      ..sort((a, b) => b.contributedPts.compareTo(a.contributedPts));
    if (done.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: c.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          'No tasks completed yet today',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < done.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  color: c.border,
                  thickness: 0.5,
                  indent: 14,
                  endIndent: 14),
            _ActivityRow(contrib: done[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final TaskContribution contrib;
  const _ActivityRow({required this.contrib});

  Color _sectionColor(BuildContext context, HabitSection s) {
    final c = context.c;
    return switch (s) {
      HabitSection.athletic => c.athletic,
      HabitSection.mind => c.mind,
      HabitSection.body => c.body,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = contrib.habit;
    final color = _sectionColor(context, h.section);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(habitIcon(h.icon), size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              h.name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${contrib.contributedPts.round()} XP',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// ACHIEVEMENTS
// ────────────────────────────────────────────────────────────────────

class _AchievementsGrid extends StatelessWidget {
  final Set<String> unlocked;
  const _AchievementsGrid({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final visible = achievementCatalog
        .where((a) => !a.hidden || unlocked.contains(a.id))
        .toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: visible.length,
      itemBuilder: (_, i) => _AchievementTile(
        def: visible[i],
        unlocked: unlocked.contains(visible[i].id),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementDef def;
  final bool unlocked;
  const _AchievementTile({required this.def, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = unlocked ? c.accent : c.textMuted;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: unlocked ? c.accent.withValues(alpha: 0.4) : c.border,
          width: unlocked ? 1 : 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: unlocked
                  ? c.accent.withValues(alpha: 0.12)
                  : c.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: tint.withValues(alpha: 0.6), width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(def.icon, size: 20, color: tint),
          ),
          const SizedBox(height: 8),
          Text(
            def.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: unlocked ? c.textPrimary : c.textMuted,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            def.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: c.textMuted,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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

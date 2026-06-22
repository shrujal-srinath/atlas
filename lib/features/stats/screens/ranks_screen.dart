import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/atlas_back_button.dart';
import '../../xp/leveling_engine.dart';
import '../../xp/leveling_providers.dart';
import '../../xp/rank_tier.dart';

/// Full rank ladder: Rookie → Legend. User's current rank is highlighted.
class RanksScreen extends ConsumerWidget {
  const RanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final t = context.t;
    final curLevel = ref.watch(currentLevelProvider).level;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: const AtlasBackButton(fallback: '/stats'),
        title: Text('Rank Ladder', style: t.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.screenH, 12, AppSpace.screenH, 118),
          itemCount: rankTiers.length,
          itemBuilder: (_, i) => _TierBlock(
            tier: rankTiers[i],
            currentLevel: curLevel,
          ),
        ),
      ),
    );
  }
}

class _TierBlock extends StatelessWidget {
  final RankTier tier;
  final int currentLevel;
  const _TierBlock({required this.tier, required this.currentLevel});

  bool get _isCurrentTier =>
      currentLevel >= tier.minLevel && currentLevel <= tier.maxLevel;

  Color _metalColor(BuildContext context, String metal) {
    final c = context.c;
    return switch (metal) {
      'bronze' => const Color(0xFFCD7F32),
      'silver' => const Color(0xFFC0C0C0),
      'gold' => const Color(0xFFD4AF37),
      'platinum' => const Color(0xFFE5E4E2),
      'diamond' => const Color(0xFFB9F2FF),
      'master' => const Color(0xFFFF6B6B),
      'legend' => c.accent,
      _ => c.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _isCurrentTier
            ? c.accent.withValues(alpha: 0.06)
            : c.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: _isCurrentTier ? c.accent.withValues(alpha: 0.5) : c.border,
          width: _isCurrentTier ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                tier.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'L${tier.minLevel}–${tier.maxLevel == 99 ? '∞' : tier.maxLevel}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              if (_isCurrentTier)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < tier.subTiers.length; i++)
                _SubTierChip(
                  subTier: tier.subTiers[i],
                  metalColor: _metalColor(context, tier.subTiers[i].metal),
                  level: tier.minLevel + i,
                  isCurrent: currentLevel == tier.minLevel + i,
                  unlocked: currentLevel >= tier.minLevel + i,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Reach L${tier.maxLevel == 99 ? '26' : tier.maxLevel + 1} to advance to '
            '${tier.maxLevel == 99 ? "you're already at Legend" : (rankFor(tier.maxLevel + 1).tier.name)}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: c.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'XP threshold',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                _fmt(xpForLevel(tier.minLevel)),
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
        ],
      ),
    );
  }

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

class _SubTierChip extends StatelessWidget {
  final RankSubTier subTier;
  final Color metalColor;
  final int level;
  final bool isCurrent;
  final bool unlocked;
  const _SubTierChip({
    required this.subTier,
    required this.metalColor,
    required this.level,
    required this.isCurrent,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? metalColor.withValues(alpha: 0.22)
            : c.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(
          color: isCurrent ? metalColor : c.border,
          width: isCurrent ? 1 : 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(20, 20),
            painter: _MiniHexPainter(
              color: unlocked ? metalColor : c.textMuted.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            subTier.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              color: unlocked ? c.textPrimary : c.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'L$level',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHexPainter extends CustomPainter {
  final Color color;
  _MiniHexPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 1;
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
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MiniHexPainter old) => old.color != color;
}

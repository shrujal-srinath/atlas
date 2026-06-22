part of 'progression_screen.dart';

// ────────────────────────────────────────────────────────────────────
// RANK CARD
// ────────────────────────────────────────────────────────────────────

/// The hero block: renders the score → XP → level → rank → streak chain in one
/// place so the whole progression system reads top-to-bottom.
class _StoryHeader extends StatelessWidget {
  final LevelInfo info;
  final int todayScore;
  final int todayDelta;
  final int streak;
  final int milestonesMet;
  final int milestonesTotal;
  const _StoryHeader({
    required this.info,
    required this.todayScore,
    required this.todayDelta,
    required this.streak,
    required this.milestonesMet,
    required this.milestonesTotal,
  });

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rank = rankFor(info.level);
    final remaining =
        (info.xpForNextLevel - info.xpIntoLevel).clamp(0, info.xpForNextLevel);
    const white = Colors.white;
    final white70 = Colors.white.withValues(alpha: 0.72);
    final hasMilestones = milestonesTotal > 0;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level ${info.level} · ${rank.subTier.label}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: white70,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Today cluster: today's score → XP it earned.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TODAY',
                      style: AppType.overline
                          .copyWith(color: white70, letterSpacing: 1.4, fontSize: 9)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$todayScore',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: white,
                            height: 1.0,
                            fontFeatures: [FontFeature.tabularFigures()],
                          )),
                      const SizedBox(width: 5),
                      Icon(LucideIcons.arrowRight, size: 12, color: white70),
                      const SizedBox(width: 5),
                      Text('${todayDelta >= 0 ? '+' : ''}$todayDelta XP',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: white,
                            height: 1.0,
                            fontFeatures: [FontFeature.tabularFigures()],
                          )),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: info.progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.24),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                info.xpGatePassed && info.bankedXp > 0
                    ? '${_fmt(info.xpIntoLevel)} / ${_fmt(info.xpForNextLevel)} XP · +${_fmt(info.bankedXp)} banked'
                    : '${_fmt(info.xpIntoLevel)} / ${_fmt(info.xpForNextLevel)} XP',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: white.withValues(alpha: 0.85),
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: 8),
                Icon(LucideIcons.flame,
                    size: 12, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 2),
                Text('$streak',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: white,
                      height: 1.0,
                      fontFeatures: [FontFeature.tabularFigures()],
                    )),
              ],
              const Spacer(),
              Text(
                info.xpGatePassed
                    ? (hasMilestones
                        ? 'Milestones $milestonesMet/$milestonesTotal'
                        : 'XP ready for L${info.level + 1}')
                    : '${_fmt(remaining)} to L${info.level + 1}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: white,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
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

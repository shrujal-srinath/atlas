/// Sports-themed rank tiers mapped to level bands. Each band has 3–5 sub-tiers
/// (Bronze / Silver / Gold roman-numeral metals). Single source of truth — the
/// Progression screen and Rank Ladder screen both read from here.
library;

class RankSubTier {
  final String label; // 'Silver III', 'Gold I' …
  final String metal; // 'bronze' | 'silver' | 'gold'
  final int roman;    // 1, 2, 3 …
  const RankSubTier(this.label, this.metal, this.roman);
}

class RankTier {
  final String name;          // 'Playmaker'
  final int minLevel;         // inclusive
  final int maxLevel;         // inclusive
  final List<RankSubTier> subTiers; // length = maxLevel - minLevel + 1
  const RankTier({
    required this.name,
    required this.minLevel,
    required this.maxLevel,
    required this.subTiers,
  });
}

const List<RankTier> rankTiers = [
  RankTier(name: 'Rookie', minLevel: 1, maxLevel: 3, subTiers: [
    RankSubTier('Bronze III', 'bronze', 3),
    RankSubTier('Bronze II', 'bronze', 2),
    RankSubTier('Bronze I', 'bronze', 1),
  ]),
  RankTier(name: 'Apprentice', minLevel: 4, maxLevel: 6, subTiers: [
    RankSubTier('Bronze III', 'bronze', 3),
    RankSubTier('Silver III', 'silver', 3),
    RankSubTier('Silver II', 'silver', 2),
  ]),
  RankTier(name: 'Playmaker', minLevel: 7, maxLevel: 9, subTiers: [
    RankSubTier('Silver III', 'silver', 3),
    RankSubTier('Silver II', 'silver', 2),
    RankSubTier('Silver I', 'silver', 1),
  ]),
  RankTier(name: 'Allrounder', minLevel: 10, maxLevel: 12, subTiers: [
    RankSubTier('Gold III', 'gold', 3),
    RankSubTier('Gold II', 'gold', 2),
    RankSubTier('Gold I', 'gold', 1),
  ]),
  RankTier(name: 'Specialist', minLevel: 13, maxLevel: 15, subTiers: [
    RankSubTier('Platinum III', 'platinum', 3),
    RankSubTier('Platinum II', 'platinum', 2),
    RankSubTier('Platinum I', 'platinum', 1),
  ]),
  RankTier(name: 'Captain', minLevel: 16, maxLevel: 20, subTiers: [
    RankSubTier('Diamond V', 'diamond', 5),
    RankSubTier('Diamond IV', 'diamond', 4),
    RankSubTier('Diamond III', 'diamond', 3),
    RankSubTier('Diamond II', 'diamond', 2),
    RankSubTier('Diamond I', 'diamond', 1),
  ]),
  RankTier(name: 'Champion', minLevel: 21, maxLevel: 25, subTiers: [
    RankSubTier('Master V', 'master', 5),
    RankSubTier('Master IV', 'master', 4),
    RankSubTier('Master III', 'master', 3),
    RankSubTier('Master II', 'master', 2),
    RankSubTier('Master I', 'master', 1),
  ]),
  RankTier(name: 'Legend', minLevel: 26, maxLevel: 99, subTiers: [
    RankSubTier('Legend', 'legend', 1),
  ]),
];

({RankTier tier, RankSubTier subTier}) rankFor(int level) {
  for (final t in rankTiers) {
    if (level >= t.minLevel && level <= t.maxLevel) {
      final i = (level - t.minLevel).clamp(0, t.subTiers.length - 1);
      return (tier: t, subTier: t.subTiers[i]);
    }
  }
  final last = rankTiers.last;
  return (tier: last, subTier: last.subTiers.last);
}

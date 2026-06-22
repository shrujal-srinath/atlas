/// Pure leveling engine for v2 of the XP system.
///
/// All math here is deterministic, has zero IO/Riverpod/BuildContext deps,
/// and is the single source of truth for converting a daily score (0..110)
/// into level XP. See `docs/LEVELING.md` for the philosophy.
library;

/// 1 perfect day = 100 XP. 21 perfect days = level-up worth of effort.
const int kPerfectDayXp = 100;

/// XP required for each level transition. `xpForLevel(L) = kXpPerLevel * (L-1)`.
/// 21 perfect days × 100 = 2,100.
const int kXpPerLevel = 2100;

/// Score threshold below which a day starts contributing negative XP.
/// At exactly this score, contribution = 0.
const int kNegativeDayThreshold = 50;

/// Lower bound on a single day's XP contribution. A day at score 0 contributes
/// (0 - 50) = -50 XP, so the floor matches.
const int kNegativeDayFloor = -50;

/// Converts a day's final score (0..110, inclusive of overshoot bonus) into
/// level XP for that day.
///
/// - `score >= 50` → contributes `score` (perfect day = +100, score 75 = +75).
/// - `score <  50` → contributes `score - 50` (score 30 = -20, score 0 = -50).
///
/// Clamped to `[kNegativeDayFloor, kPerfectDayXp + 10]` for safety.
int dayXpFromScore(int score) {
  if (score >= kNegativeDayThreshold) {
    if (score > kPerfectDayXp + 10) return kPerfectDayXp + 10;
    return score;
  }
  final delta = score - kNegativeDayThreshold;
  if (delta < kNegativeDayFloor) return kNegativeDayFloor;
  return delta;
}

/// Cumulative XP required to *reach* [level]. Level 1 starts at 0.
/// Linear growth: every level costs the same 2,100 XP.
int xpForLevel(int level) {
  if (level <= 1) return 0;
  return kXpPerLevel * (level - 1);
}

/// Snapshot of a user's level progression at a given cumulative XP value.
class LevelInfo {
  /// Current level (>= 1).
  final int level;

  /// Cumulative XP supplied to [levelFromCumulative]. Always >= 0 (negative
  /// totals clamp to 0 so we never go below L1).
  final int totalXp;

  /// XP earned within the current level (0 .. xpForNextLevel).
  final int xpIntoLevel;

  /// XP span for the current level — always [kXpPerLevel] with the linear
  /// formula, but exposed for forward compatibility if we ever escalate later.
  final int xpForNextLevel;

  /// `xpIntoLevel / xpForNextLevel` in `[0, 1]`.
  final double progress;

  /// True when the XP gate for the next level is already cleared. With
  /// [gatedLevelInfo] this means the user is waiting on milestones, not XP.
  final bool xpGatePassed;

  /// XP accumulated beyond the next-level threshold while milestone-gated.
  /// Always 0 unless [xpGatePassed] is true.
  final int bankedXp;

  const LevelInfo({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.progress,
    this.xpGatePassed = false,
    this.bankedXp = 0,
  });

  static const LevelInfo zero = LevelInfo(
    level: 1,
    totalXp: 0,
    xpIntoLevel: 0,
    xpForNextLevel: kXpPerLevel,
    progress: 0,
  );
}

/// Derives the *candidate* level from a cumulative XP value — what the user
/// would be at if XP were the only gate. Negative totals clamp to 0; the user
/// never falls below Level 1.
LevelInfo levelFromCumulative(int totalXp) {
  final t = totalXp < 0 ? 0 : totalXp;
  // Linear, integer-safe: level = 1 + floor(t / kXpPerLevel)
  final level = 1 + (t ~/ kXpPerLevel);
  final xpIntoLevel = t - xpForLevel(level);
  final progress = xpIntoLevel / kXpPerLevel;
  return LevelInfo(
    level: level,
    totalXp: t,
    xpIntoLevel: xpIntoLevel,
    xpForNextLevel: kXpPerLevel,
    progress: progress.clamp(0.0, 1.0),
  );
}

/// v2.1 dual-gated progression. The displayed level is the *confirmed* level
/// (persisted in `users.confirmed_level`, awarded one step at a time when both
/// the XP gate and all milestone pre-reqs pass) — cumulative XP alone only
/// nominates a candidate.
///
/// Rules:
/// - A confirmed level is never lost: XP is floored at `xpForLevel(confirmed)`,
///   so negative days can drain progress *within* the level but never demote.
/// - While the user is past the XP threshold but still milestone-gated, the
///   bar reads full (`xpIntoLevel == xpForNextLevel`, `progress == 1.0`),
///   [LevelInfo.xpGatePassed] is true, and the overflow is in
///   [LevelInfo.bankedXp].
LevelInfo gatedLevelInfo({required int confirmedLevel, required int totalXp}) {
  final level = confirmedLevel < 1 ? 1 : confirmedLevel;
  final base = xpForLevel(level);
  final t = totalXp < base ? base : totalXp;
  final rawInto = t - base;
  final gatePassed = rawInto >= kXpPerLevel;
  final xpIntoLevel = gatePassed ? kXpPerLevel : rawInto;
  return LevelInfo(
    level: level,
    totalXp: t,
    xpIntoLevel: xpIntoLevel,
    xpForNextLevel: kXpPerLevel,
    progress: (xpIntoLevel / kXpPerLevel).clamp(0.0, 1.0),
    xpGatePassed: gatePassed,
    bankedXp: gatePassed ? rawInto - kXpPerLevel : 0,
  );
}

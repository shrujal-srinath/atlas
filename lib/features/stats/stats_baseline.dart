/// Pure baseline-comparison math for the Stats overview — "your recent average
/// vs your longer-run norm", the directional framing the best apps use
/// (Apple Fitness / Whoop). No I/O, fully unit-testable.
library;

/// Recent performance contrasted with a longer baseline.
class ScoreBaseline {
  /// Mean score over the recent window (rest days excluded).
  final double recentAvg;

  /// Mean score over the whole baseline window (rest days excluded).
  final double baselineAvg;

  /// Count of scored (non-rest) days in each window.
  final int recentDays;
  final int baselineDays;

  const ScoreBaseline({
    required this.recentAvg,
    required this.baselineAvg,
    required this.recentDays,
    required this.baselineDays,
  });

  static const ScoreBaseline empty = ScoreBaseline(
    recentAvg: 0,
    baselineAvg: 0,
    recentDays: 0,
    baselineDays: 0,
  );

  /// Percentage change of recent vs baseline (e.g. +12.0 = up 12%).
  double get deltaPct =>
      baselineAvg <= 0 ? 0 : ((recentAvg - baselineAvg) / baselineAvg) * 100;

  /// Absolute point change, rounded.
  int get deltaPoints => (recentAvg - baselineAvg).round();

  bool get isUp => recentAvg >= baselineAvg;

  /// Enough scored days on both sides for the comparison to mean something.
  bool get hasData => recentDays >= 3 && baselineDays >= 5;
}

/// Compares the mean of the last [recentWindow] days against the mean of the
/// full [scores] window (the longer baseline). [scores] are 0–100, oldest →
/// newest. Rest days (score 0) are excluded from both means so a day off
/// doesn't read as a decline.
ScoreBaseline computeScoreBaseline(List<int> scores, {int recentWindow = 7}) {
  if (scores.isEmpty) return ScoreBaseline.empty;

  double meanNonZero(Iterable<int> xs) {
    final s = xs.where((v) => v > 0).toList();
    if (s.isEmpty) return 0;
    return s.reduce((a, b) => a + b) / s.length;
  }

  final recentSlice = scores.length <= recentWindow
      ? scores
      : scores.sublist(scores.length - recentWindow);

  return ScoreBaseline(
    recentAvg: meanNonZero(recentSlice),
    baselineAvg: meanNonZero(scores),
    recentDays: recentSlice.where((v) => v > 0).length,
    baselineDays: scores.where((v) => v > 0).length,
  );
}

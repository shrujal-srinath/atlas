/// Single source of truth for how a habit's [HabitPriority] scales the three
/// downstream signals: XP earned, contribution to today's score, and streak
/// bonus. Imported by the XP engine, score engine, and achievement engine —
/// never duplicate these numbers anywhere else.
library;

import '../../shared/models/models.dart';

class PriorityWeights {
  final double xp;
  final double score;
  final double streakBonus;

  const PriorityWeights({
    required this.xp,
    required this.score,
    required this.streakBonus,
  });
}

const Map<HabitPriority, PriorityWeights> priorityWeights = {
  HabitPriority.low:      PriorityWeights(xp: 0.5, score: 0.5, streakBonus: 0.5),
  HabitPriority.normal:   PriorityWeights(xp: 1.0, score: 1.0, streakBonus: 1.0),
  HabitPriority.high:     PriorityWeights(xp: 1.5, score: 1.5, streakBonus: 1.25),
  HabitPriority.critical: PriorityWeights(xp: 2.5, score: 2.5, streakBonus: 1.5),
};

PriorityWeights weightsFor(HabitPriority p) =>
    priorityWeights[p] ?? priorityWeights[HabitPriority.normal]!;

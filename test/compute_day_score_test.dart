import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/home/scoring/score_engine.dart';
import 'package:atlas/shared/models/models.dart';

Habit _hab({
  String id = 'h',
  String sectionId = 'athletic',
  HabitType type = HabitType.positive,
  HabitPriority priority = HabitPriority.normal,
}) =>
    Habit(
      id: id,
      userId: 'u',
      name: id,
      icon: 'dumbbell',
      sectionId: sectionId,
      type: type,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      effortRatingEnabled: false,
      noteEnabled: false,
      isArchived: false,
      priority: priority,
    );

HabitLog _log({bool completed = false, String habitId = 'h'}) => HabitLog(
      id: 'l-$habitId',
      habitId: habitId,
      userId: 'u',
      date: '2026-06-08',
      completed: completed,
      urgeOnly: false,
    );

void main() {
  group('computeDayScore', () {
    test('empty tasks → empty', () {
      final d = computeDayScore(
          tasks: const [], sectionWeights: kDefaultSectionWeights);
      expect(d.score, 0);
      expect(d.total, 0);
      expect(d.sectionPct[HabitSection.athletic], 0);
    });

    test('habit-only: one athletic done → weighted by 0.4 → 40', () {
      final d = computeDayScore(
        tasks: [
          ScoredTaskInput(_hab(id: 'a', sectionId: 'athletic'),
              _log(habitId: 'a', completed: true)),
        ],
        sectionWeights: kDefaultSectionWeights,
        nutritionRatio: null,
      );
      expect(d.score, 40);
      expect(d.sectionPct[HabitSection.athletic], 100);
      expect(d.sectionPct[HabitSection.body], 0);
    });

    test('nutrition lifts the body section even with no body habits', () {
      final d = computeDayScore(
        tasks: [
          ScoredTaskInput(_hab(id: 'a', sectionId: 'athletic'),
              _log(habitId: 'a', completed: true)),
        ],
        sectionWeights: kDefaultSectionWeights,
        nutritionRatio: 1.0, // perfect nutrition
      );
      // body = 0*0.5 + 1.0*0.5 = 0.5 → body weight 0.3 → +15 over the 40
      expect(d.sectionPct[HabitSection.body], 50);
      expect(d.score, 55);
    });

    test('null nutrition leaves the body section habit-only', () {
      final d = computeDayScore(
        tasks: [
          ScoredTaskInput(_hab(id: 'a', sectionId: 'athletic'),
              _log(habitId: 'a', completed: true)),
        ],
        sectionWeights: kDefaultSectionWeights,
        nutritionRatio: null,
      );
      expect(d.sectionPct[HabitSection.body], 0);
      expect(d.score, 40);
    });
  });
}

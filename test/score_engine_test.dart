import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/home/scoring/score_engine.dart';
import 'package:atlas/shared/models/models.dart';

Habit _hab({
  String id = 'h',
  HabitSection section = HabitSection.athletic,
  HabitType type = HabitType.positive,
  HabitPriority priority = HabitPriority.normal,
  GoalType? goalType,
  double? goalValue,
}) =>
    Habit(
      id: id,
      userId: 'u',
      name: id,
      icon: 'dumbbell',
      section: section,
      type: type,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      goalValue: goalValue,
      goalType: goalType,
      effortRatingEnabled: false,
      noteEnabled: false,
      isArchived: false,
      priority: priority,
    );

HabitLog _log({
  bool completed = false,
  double? actualValue,
  String habitId = 'h',
}) =>
    HabitLog(
      id: 'l-$habitId',
      habitId: habitId,
      userId: 'u',
      date: '2026-06-08',
      completed: completed,
      urgeOnly: false,
      actualValue: actualValue,
    );

void main() {
  group('taskRatio', () {
    test('null log returns 0', () {
      expect(taskRatio(_hab(), null), 0.0);
    });

    test('binary positive not done returns 0', () {
      expect(taskRatio(_hab(), _log(completed: false)), 0.0);
    });

    test('binary positive done returns 1', () {
      expect(taskRatio(_hab(), _log(completed: true)), 1.0);
    });

    test('legacy numeric log (no actualValue, completed) returns 1', () {
      final h = _hab(goalType: GoalType.reps, goalValue: 20);
      expect(taskRatio(h, _log(completed: true)), 1.0);
    });

    test('partial numeric: 12 of 20 reps returns 0.6', () {
      final h = _hab(goalType: GoalType.reps, goalValue: 20);
      expect(taskRatio(h, _log(actualValue: 12)), closeTo(0.6, 1e-9));
    });

    test('overshoot caps at kOvershootCap (5 of 3)', () {
      final h = _hab(goalType: GoalType.reps, goalValue: 3);
      expect(taskRatio(h, _log(actualValue: 5)), kOvershootCap);
    });

    test('zero actualValue returns 0', () {
      final h = _hab(goalType: GoalType.reps, goalValue: 20);
      expect(taskRatio(h, _log(actualValue: 0)), 0.0);
    });

    test('todo treats completed as binary', () {
      final h = _hab(type: HabitType.todo);
      expect(taskRatio(h, _log(completed: true)), 1.0);
      expect(taskRatio(h, _log(completed: false)), 0.0);
    });
  });

  group('computeScore', () {
    test('empty tasks returns empty breakdown', () {
      final b = computeScore(
        tasks: const [],
        sectionWeights: kDefaultSectionWeights,
      );
      expect(b.score, 0);
      expect(b.projectedScore, 0);
      expect(b.totalCount, 0);
    });

    test('single athletic task done → score = 40 (default 40% weight)', () {
      final tasks = [
        ScoredTaskInput(_hab(id: 'a'), _log(habitId: 'a', completed: true)),
      ];
      final b = computeScore(
          tasks: tasks, sectionWeights: kDefaultSectionWeights);
      expect(b.score, 40);
      expect(b.doneCount, 1);
    });

    test('two athletic tasks, one done → section ratio 0.5 → score 20', () {
      final tasks = [
        ScoredTaskInput(_hab(id: 'a1'), _log(habitId: 'a1', completed: true)),
        ScoredTaskInput(_hab(id: 'a2'), _log(habitId: 'a2', completed: false)),
      ];
      final b = computeScore(
          tasks: tasks, sectionWeights: kDefaultSectionWeights);
      expect(b.score, 20);
    });

    test('numeric partial: 12/20 reps athletic → score = 0.6 × 0.4 × 100 = 24',
        () {
      final h = _hab(id: 'a', goalType: GoalType.reps, goalValue: 20);
      final tasks = [ScoredTaskInput(h, _log(habitId: 'a', actualValue: 12))];
      final b = computeScore(
          tasks: tasks, sectionWeights: kDefaultSectionWeights);
      expect(b.score, 24);
      expect(b.doneCount, 0); // ratio < 1.0
    });

    test('priority weighting: critical done + normal not in same section', () {
      final crit = _hab(
        id: 'crit',
        priority: HabitPriority.critical, // 2.5× score weight
      );
      final norm = _hab(id: 'norm'); // 1.0×
      final tasks = [
        ScoredTaskInput(crit, _log(habitId: 'crit', completed: true)),
        ScoredTaskInput(norm, _log(habitId: 'norm', completed: false)),
      ];
      final b = computeScore(
          tasks: tasks, sectionWeights: kDefaultSectionWeights);
      // sectionRatio = (1 × 2.5 + 0 × 1) / (2.5 + 1) = 0.714…
      // score = 0.714 × 0.4 × 100 ≈ 28.6 → 29
      expect(b.score, 29);
    });

    test('final score capped at 100 even with overshoot', () {
      // All 3 sections single task each, all overshot to 1.10.
      final tasks = [
        for (final s in HabitSection.values)
          ScoredTaskInput(
            _hab(id: s.name, section: s, goalType: GoalType.reps, goalValue: 1),
            _log(habitId: s.name, actualValue: 5),
          ),
      ];
      final b = computeScore(
          tasks: tasks, sectionWeights: kDefaultSectionWeights);
      expect(b.score, 100); // clamped, not 110
      expect(b.sectionRatio[HabitSection.athletic], kOvershootCap);
    });

    test('projected score assumes incomplete tasks complete', () {
      final tasks = [
        ScoredTaskInput(_hab(id: 'a1'), _log(habitId: 'a1', completed: false)),
        ScoredTaskInput(_hab(id: 'a2'), _log(habitId: 'a2', completed: false)),
      ];
      final b = computeScore(
          tasks: tasks, sectionWeights: kDefaultSectionWeights);
      expect(b.score, 0);
      expect(b.projectedScore, 40); // full athletic completion → 40% score
    });

    test('per-task contributions sum approximately to score', () {
      final tasks = [
        ScoredTaskInput(_hab(id: 'a1'), _log(habitId: 'a1', completed: true)),
        ScoredTaskInput(
            _hab(id: 'a2', section: HabitSection.mind),
            _log(habitId: 'a2', completed: true)),
        ScoredTaskInput(
            _hab(id: 'a3', section: HabitSection.body),
            _log(habitId: 'a3', completed: false)),
      ];
      final b = computeScore(
          tasks: tasks, sectionWeights: kDefaultSectionWeights);
      final sum = b.perTaskContrib
          .map((c) => c.contributedPts)
          .fold<double>(0, (a, c) => a + c);
      // score = 40 + 30 + 0 = 70
      expect(b.score, 70);
      expect(sum, closeTo(70, 0.01));
    });
  });

  group('normalizeSectionWeights', () {
    test('null falls back to defaults', () {
      expect(normalizeSectionWeights(null), kDefaultSectionWeights);
    });

    test('empty falls back to defaults', () {
      expect(normalizeSectionWeights(const {}), kDefaultSectionWeights);
    });

    test('40/30/30 yields 0.4/0.3/0.3', () {
      final w = normalizeSectionWeights(
          const {'athletic': 40, 'mind': 30, 'body': 30});
      expect(w[HabitSection.athletic], closeTo(0.4, 1e-9));
      expect(w[HabitSection.mind], closeTo(0.3, 1e-9));
      expect(w[HabitSection.body], closeTo(0.3, 1e-9));
    });

    test('sum > 100 (50/30/30 = 110) normalizes correctly', () {
      final w = normalizeSectionWeights(
          const {'athletic': 50, 'mind': 30, 'body': 30});
      final sum = w.values.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-9));
    });

    test('all-zero falls back to defaults', () {
      expect(
        normalizeSectionWeights(const {'athletic': 0, 'mind': 0, 'body': 0}),
        kDefaultSectionWeights,
      );
    });
  });
}

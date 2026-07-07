import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/shared/models/models.dart';

void main() {
  group('goal units available', () {
    test('duration / distance / volume offer two units', () {
      expect(goalUnitsFor(GoalType.durationMin), ['min', 'hr']);
      expect(goalUnitsFor(GoalType.distanceKm), ['km', 'mi']);
      expect(goalUnitsFor(GoalType.litres), ['L', 'ml']);
    });

    test('reps + custom carry no alternate units', () {
      expect(goalUnitsFor(GoalType.reps), isEmpty);
      expect(goalUnitsFor(GoalType.custom), isEmpty);
    });
  });

  group('canonical conversion round-trips', () {
    test('hours ↔ minutes', () {
      expect(goalToCanonical(GoalType.durationMin, 'hr', 2), closeTo(120, 1e-9));
      expect(goalFromCanonical(GoalType.durationMin, 'hr', 120), closeTo(2, 1e-9));
      // sleep example: 8 hr → 480 min canonical → back to 8 hr.
      final canonical = goalToCanonical(GoalType.durationMin, 'hr', 8);
      expect(canonical, closeTo(480, 1e-9));
      expect(goalFromCanonical(GoalType.durationMin, 'hr', canonical),
          closeTo(8, 1e-9));
    });

    test('miles ↔ km', () {
      expect(goalToCanonical(GoalType.distanceKm, 'mi', 1), closeTo(1.609344, 1e-6));
      expect(goalFromCanonical(GoalType.distanceKm, 'mi', 1.609344),
          closeTo(1, 1e-6));
    });

    test('millilitres ↔ litres', () {
      expect(goalToCanonical(GoalType.litres, 'ml', 500), closeTo(0.5, 1e-9));
      expect(goalFromCanonical(GoalType.litres, 'ml', 0.5), closeTo(500, 1e-9));
    });

    test('base/identity units pass through unchanged', () {
      expect(goalToCanonical(GoalType.durationMin, 'min', 30), 30);
      expect(goalToCanonical(GoalType.distanceKm, 'km', 5), 5);
      expect(goalToCanonical(GoalType.litres, 'L', 3), 3);
      expect(goalToCanonical(GoalType.reps, null, 10), 10);
      expect(goalFromCanonical(GoalType.reps, null, 10), 10);
    });
  });

  group('unit labels', () {
    test('explicit unit wins; null falls back to the type default', () {
      expect(goalUnitLabel(GoalType.durationMin, 'hr'), 'hr');
      expect(goalUnitLabel(GoalType.durationMin, null), 'min');
      expect(goalUnitLabel(GoalType.distanceKm, 'mi'), 'mi');
      expect(goalUnitLabel(GoalType.distanceKm, null), 'km');
      expect(goalUnitLabel(GoalType.litres, null), 'L');
      expect(goalUnitLabel(GoalType.reps, null), 'reps');
    });

    test('custom uses its free-text unit, else a generic fallback', () {
      expect(goalUnitLabel(GoalType.custom, 'pages'), 'pages');
      expect(goalUnitLabel(GoalType.custom, null), 'units');
    });
  });

  group('Habit serialization carries goalUnit', () {
    test('toJson/fromJson round-trips the unit', () {
      const h = Habit(
        id: 'h1',
        userId: 'u1',
        name: 'Sleep',
        icon: 'moon',
        sectionId: 'body',
        type: HabitType.positive,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        goalValue: 8,
        goalType: GoalType.durationMin,
        goalUnit: 'hr',
        effortRatingEnabled: false,
        noteEnabled: false,
        isArchived: false,
      );
      final j = h.toJson();
      expect(j['goal_unit'], 'hr');
      final back = Habit.fromJson({...j, 'id': 'h1', 'user_id': 'u1'});
      expect(back.goalUnit, 'hr');
      expect(back.goalValue, 8);
      expect(back.goalType, GoalType.durationMin);
    });
  });
}

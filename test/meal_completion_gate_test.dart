import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/food/domain/food.dart';
import 'package:atlas/features/food/domain/meal_entry.dart';
import 'package:atlas/features/habits/widgets/meal_completion_gate.dart';
import 'package:atlas/shared/models/models.dart';

Habit _hab({Map<String, dynamic>? foodLinkRaw}) => Habit(
      id: 'h',
      userId: 'u',
      name: 'Breakfast',
      icon: 'utensils',
      sectionId: 'body',
      type: HabitType.positive,
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      effortRatingEnabled: false,
      noteEnabled: false,
      isArchived: false,
      foodLinkRaw: foodLinkRaw,
    );

HabitLog _log({bool completed = true}) => HabitLog(
      id: 'l',
      habitId: 'h',
      userId: 'u',
      date: '2026-07-27',
      completed: completed,
      urgeOnly: false,
    );

MealEntry _entry(MealTimeSlot slot) => MealEntry(
      id: 'e',
      userId: 'u',
      foodId: null,
      name: 'Something',
      date: DateTime(2026, 7, 27),
      slot: slot,
      qty: 1,
      unit: 'serving',
      totals: const Nutrients(kcal: 300),
    );

final _flexLink = {
  'slot': 'breakfast',
  'items': const [],
  'is_flexible': true,
};

final _fixedLink = {
  'slot': 'breakfast',
  'items': [
    {'name': 'Oats', 'qty': 1.0, 'unit': 'bowl', 'calories': 300},
  ],
};

void main() {
  group('flexibleMealSlotOf', () {
    test('null for a habit with no food link', () {
      expect(flexibleMealSlotOf(_hab()), isNull);
    });

    test('null for a Fixed food-link habit', () {
      expect(flexibleMealSlotOf(_hab(foodLinkRaw: _fixedLink)), isNull);
    });

    test('the slot for a Flexible meal habit', () {
      expect(
        flexibleMealSlotOf(_hab(foodLinkRaw: _flexLink)),
        MealTimeSlot.breakfast,
      );
    });
  });

  group('isMealHabitPending', () {
    final flexHabit = _hab(foodLinkRaw: _flexLink);

    test('false when not completed today', () {
      expect(
        isMealHabitPending(flexHabit, _log(completed: false), const []),
        isFalse,
      );
    });

    test('false when there is no log at all today', () {
      expect(isMealHabitPending(flexHabit, null, const []), isFalse);
    });

    test('false for a non-meal habit even if completed', () {
      expect(isMealHabitPending(_hab(), _log(), const []), isFalse);
    });

    test('false for a Fixed food-link habit even if completed', () {
      expect(
        isMealHabitPending(_hab(foodLinkRaw: _fixedLink), _log(), const []),
        isFalse,
      );
    });

    test('true when completed today with nothing logged in its slot', () {
      expect(isMealHabitPending(flexHabit, _log(), const []), isTrue);
    });

    test("false once something is logged in the habit's slot", () {
      final entries = [_entry(MealTimeSlot.breakfast)];
      expect(isMealHabitPending(flexHabit, _log(), entries), isFalse);
    });

    test('still true if the only entry logged is for a different slot', () {
      final entries = [_entry(MealTimeSlot.lunch)];
      expect(isMealHabitPending(flexHabit, _log(), entries), isTrue);
    });
  });
}

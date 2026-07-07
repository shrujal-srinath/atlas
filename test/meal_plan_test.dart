import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/food/domain/meal_plan.dart';
import 'package:atlas/shared/models/models.dart';

void main() {
  group('MealPlan.forGoal defaults', () {
    test('cut = 3 meals, bulk spreads to more', () {
      expect(MealPlan.forGoal('lose').enabledMeals.length, 3);
      expect(MealPlan.forGoal('gain').enabledMeals.length,
          greaterThan(MealPlan.forGoal('lose').enabledMeals.length));
      expect(MealPlan.forGoal('maintain').enabledMeals.length, 4);
    });

    test('main meals get default reminder times', () {
      final p = MealPlan.forGoal('maintain');
      expect(p.forSlot(MealTimeSlot.breakfast).time, '08:00');
      expect(p.forSlot(MealTimeSlot.dinner).time, '20:00');
    });
  });

  group('resolveKcal reconciles to the daily goal', () {
    test('all-auto meals sum exactly to the goal', () {
      final p = MealPlan.forGoal('maintain');
      final k = p.resolveKcal(2400);
      expect(k.values.fold(0, (a, b) => a + b), 2400);
      // disabled slots aren't in the result
      expect(k.containsKey(MealTimeSlot.preWorkout), isFalse);
    });

    test('fixed meals keep their value; auto absorb the remainder', () {
      var p = MealPlan.forGoal('maintain');
      p = p.withEntry(
          p.forSlot(MealTimeSlot.breakfast).copyWith(fixedKcal: 700));
      final k = p.resolveKcal(2400);
      expect(k[MealTimeSlot.breakfast], 700);
      expect(k.values.fold(0, (a, b) => a + b), 2400);
    });

    test('fixed overshoot → auto meals get 0, total = fixed sum', () {
      var p = MealPlan.forGoal('lose'); // breakfast/lunch/dinner
      p = p
          .withEntry(p.forSlot(MealTimeSlot.breakfast).copyWith(fixedKcal: 1000))
          .withEntry(p.forSlot(MealTimeSlot.lunch).copyWith(fixedKcal: 1000))
          .withEntry(p.forSlot(MealTimeSlot.dinner).copyWith(fixedKcal: 1000));
      final k = p.resolveKcal(2400);
      expect(k.values.fold(0, (a, b) => a + b), 3000);
      expect(p.assignedTotal(2400), 3000);
    });
  });

  group('storage round-trip + legacy', () {
    test('rename + fixed + on/off survive a round-trip', () {
      var p = MealPlan.forGoal('maintain');
      p = p.withEntry(p.forSlot(MealTimeSlot.lunch).copyWith(
          customName: 'Big Lunch', fixedKcal: 850));
      p = p.withEntry(p.forSlot(MealTimeSlot.snack).copyWith(enabled: false));
      final json = p.toMealTargetsJson();
      final back = MealPlan.fromStorage(mealTargets: json, goal: 'maintain');
      expect(back.forSlot(MealTimeSlot.lunch).name, 'Big Lunch');
      expect(back.forSlot(MealTimeSlot.lunch).fixedKcal, 850);
      expect(back.forSlot(MealTimeSlot.snack).enabled, isFalse);
    });

    test('legacy {slot: kcal} blob reads as enabled fixed meals', () {
      final back = MealPlan.fromStorage(
          mealTargets: {'breakfast': 600, 'lunch': 900}, goal: 'maintain');
      expect(back.forSlot(MealTimeSlot.breakfast).enabled, isTrue);
      expect(back.forSlot(MealTimeSlot.breakfast).fixedKcal, 600);
      expect(back.forSlot(MealTimeSlot.breakfast).isAuto, isFalse);
    });
  });

  test('distributeByWeight sums to total exactly', () {
    final w = {'a': 0.25, 'b': 0.30, 'c': 0.45};
    for (final total in [100, 999, 2333, 1]) {
      final parts = distributeByWeight(total, w);
      expect(parts.values.fold(0, (x, y) => x + y), total);
    }
  });
}

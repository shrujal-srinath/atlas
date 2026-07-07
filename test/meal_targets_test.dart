import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/food/domain/meal_targets.dart';
import 'package:atlas/features/food/domain/meal_plan.dart';
import 'package:atlas/features/food/domain/targets.dart';
import 'package:atlas/features/food/domain/food.dart';
import 'package:atlas/shared/models/models.dart';

DailyTargets _daily({
  double kcal = 3000,
  double protein = 180,
  double carbs = 350,
  double fat = 90,
  double fiber = 42,
}) =>
    DailyTargets(
      kcal: kcal,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      micros: Nutrients(
        fiberG: fiber,
        sugarG: 50,
        satFatG: 25,
        transFatG: 2,
        cholesterolMg: 300,
        sodiumMg: 2300,
        potassiumMg: 3500,
        calciumMg: 1000,
        ironMg: 8,
        magnesiumMg: 400,
        zincMg: 11,
        vitAUg: 900,
        vitCMg: 90,
        vitDUg: 15,
        vitEMg: 15,
        vitKUg: 120,
        b6Mg: 1.3,
        b12Ug: 2.4,
        folateUg: 400,
      ),
    );

void main() {
  group('per-meal macro split sums to the daily total exactly', () {
    test('kcal + every macro reconcile across the plan\'s meals', () {
      final daily = _daily(kcal: 2750, protein: 173, carbs: 311, fat: 77, fiber: 38);
      final plan = MealPlan.forGoal('maintain');
      final m = resolveMealMacroTargets(daily: daily, plan: plan);

      int sum(int Function(MealMacroTargets) f) =>
          m.values.fold(0, (a, e) => a + f(e));

      // Disabled slots carry no calories or macros.
      expect(m[MealTimeSlot.preWorkout]!.kcal, isNull);
      expect(m[MealTimeSlot.preWorkout]!.hasMacros, isFalse);

      expect(sum((e) => e.kcal ?? 0), daily.kcal.round());
      expect(sum((e) => e.proteinG), daily.proteinG.round());
      expect(sum((e) => e.carbsG), daily.carbsG.round());
      expect(sum((e) => e.fatG), daily.fatG.round());
      expect(sum((e) => e.fiberG), daily.micros.fiberG.round());
    });

    test('awkward totals still reconcile (largest-remainder, no drift)', () {
      final plan = MealPlan.forGoal('maintain');
      for (final p in [99, 100, 101, 137, 211]) {
        final daily = _daily(protein: p.toDouble());
        final m = resolveMealMacroTargets(daily: daily, plan: plan);
        final total = m.values.fold<int>(0, (a, e) => a + e.proteinG);
        expect(total, p, reason: 'protein $p must split exactly');
      }
    });

    test('a fixed meal keeps its calories; everything still sums', () {
      final daily = _daily();
      var plan = MealPlan.forGoal('maintain');
      plan = plan.withEntry(
          plan.forSlot(MealTimeSlot.breakfast).copyWith(fixedKcal: 1000));
      final m = resolveMealMacroTargets(daily: daily, plan: plan);
      expect(m[MealTimeSlot.breakfast]!.kcal, 1000);
      final kcalTotal = m.values.fold<int>(0, (a, e) => a + (e.kcal ?? 0));
      expect(kcalTotal, daily.kcal.round());
      final pTotal = m.values.fold<int>(0, (a, e) => a + e.proteinG);
      expect(pTotal, daily.proteinG.round());
    });
  });

  group('resolveMealTargets (kcal-only) stays exact', () {
    test('enabled-meal calories sum to the daily kcal', () {
      final t = resolveMealTargets(
          dailyKcal: 2333, plan: MealPlan.forGoal('maintain'));
      final total = t.values.whereType<int>().fold<int>(0, (a, b) => a + b);
      expect(total, 2333);
    });

    test('disabled slots have no goal', () {
      final t = resolveMealTargets(
          dailyKcal: 3000, plan: MealPlan.forGoal('lose'));
      // 'lose' enables breakfast/lunch/dinner only.
      expect(t[MealTimeSlot.snack], isNull);
      expect(t[MealTimeSlot.preWorkout], isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/theme/app_theme.dart';
import 'package:atlas/features/food/domain/nutrition_engine.dart';
import 'package:atlas/features/food/widgets/goal_setup_widgets.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

NutritionPlan _samplePlan() => NutritionEngine.compute(
      sex: BioSex.male,
      age: 23,
      heightCm: 180,
      currentKg: 67,
      targetKg: 81,
      activity: ActivityLevel.veryActive,
      durationDays: 98,
    );

void main() {
  testWidgets('WeightWheelPicker renders and toggles unit', (tester) async {
    String unit = 'kg';
    double kg = 80;
    await tester.pumpWidget(_host(
      StatefulBuilder(
        builder: (context, setState) => WeightWheelPicker(
          valueKg: kg,
          unit: unit,
          onUnitChanged: (u) => setState(() => unit = u),
          onChanged: (v) => kg = v,
        ),
      ),
    ));
    expect(find.text('Kg'), findsOneWidget);
    expect(find.text('Lb'), findsOneWidget);
    await tester.tap(find.text('Lb'));
    await tester.pumpAndSettle();
    expect(unit, 'lb');
  });

  testWidgets('GoalPaceControl shows rate, live calories and feedback',
      (tester) async {
    await tester.pumpWidget(_host(
      GoalPaceControl(
        weeklyRateKg: 0.50,
        min: 0.05,
        max: 1.5,
        currentKg: 70,
        gaining: true,
        tier: PaceTier.hard,
        etaDays: 196,
        dailyKcal: 3549,
        activityLabel: 'Active',
        onChanged: (_) {},
        onSetManual: () {},
      ),
    ));
    expect(find.text('0.50'), findsOneWidget);
    expect(find.text('per week'), findsOneWidget);
    expect(find.text('Aggressive'), findsOneWidget);
    // Dynamic feedback line for the 'hard' tier.
    expect(find.textContaining('strong pace'), findsOneWidget);
    // Live calorie readout (grouped) + activity tie-in.
    expect(find.text('3,549'), findsOneWidget);
    expect(find.textContaining('Active activity level'), findsOneWidget);
    // ETA banner (RichText).
    expect(find.textContaining('reach your goal', findRichText: true),
        findsOneWidget);
  });

  testWidgets('CalorieReveal animates the calorie count up', (tester) async {
    final plan = _samplePlan();
    await tester.pumpWidget(_host(
      CalorieReveal(
        plan: plan,
        goal: 'gain',
        currentKg: 67,
        targetKg: 81,
        timelineDays: 98,
      ),
    ));
    expect(find.text('EAT EVERY DAY'), findsOneWidget);
    await tester.pumpAndSettle();
    // Final calorie value should be rendered digit-by-digit.
    final digits = plan.kcal.toString().split('');
    for (final d in digits.toSet()) {
      expect(find.text(d), findsWidgets);
    }
    expect(find.text('PROTEIN'), findsOneWidget);
  });

  testWidgets('GoalPaceControl marks the recommended pace and offers a reset',
      (tester) async {
    double? used;
    await tester.pumpWidget(_host(
      GoalPaceControl(
        weeklyRateKg: 0.20,
        min: 0.05,
        max: 1.5,
        recommendedRate: 0.20,
        currentKg: 80,
        gaining: true,
        tier: PaceTier.sustainable,
        etaDays: 140,
        dailyKcal: 2800,
        activityLabel: 'Active',
        onChanged: (v) => used = v,
        onSetManual: () {},
      ),
    ));
    // Sitting on the recommendation → green confirmation, no reset chip.
    expect(find.text('Recommended pace for you'), findsOneWidget);
    expect(find.textContaining('Use recommended'), findsNothing);

    // Dragged away → the reset chip appears and snaps back to the rec rate.
    await tester.pumpWidget(_host(
      GoalPaceControl(
        weeklyRateKg: 0.65,
        min: 0.05,
        max: 1.5,
        recommendedRate: 0.20,
        currentKg: 80,
        gaining: true,
        tier: PaceTier.extreme,
        etaDays: 60,
        dailyKcal: 3400,
        activityLabel: 'Active',
        onChanged: (v) => used = v,
        onSetManual: () {},
      ),
    ));
    final reset = find.textContaining('Use recommended');
    expect(reset, findsOneWidget);
    await tester.tap(reset);
    expect(used, 0.20);
  });

  testWidgets('CalorieReveal frames an at-goal user as already there',
      (tester) async {
    final plan = NutritionEngine.compute(
      sex: BioSex.male,
      age: 23,
      heightCm: 180,
      currentKg: 80,
      targetKg: 80,
      activity: ActivityLevel.active,
      durationDays: 0,
    );
    await tester.pumpWidget(_host(
      CalorieReveal(
        plan: plan,
        goal: 'maintain',
        currentKg: 80,
        targetKg: 80,
        timelineDays: 0,
        atGoal: true,
      ),
    ));
    expect(find.text("You're already at your goal weight"), findsOneWidget);
    expect(find.text('EAT TO MAINTAIN'), findsOneWidget);
    expect(find.text('EAT EVERY DAY'), findsNothing);
  });

  testWidgets('IdealRangeBanner reflects band fit', (tester) async {
    await tester.pumpWidget(_host(
      const IdealRangeBanner(targetKg: 95, heightCm: 180, unit: 'kg'),
    ));
    expect(find.textContaining('healthy range'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/food/domain/nutrition_engine.dart';

NutritionPlan _plan({
  BioSex sex = BioSex.male,
  int age = 23,
  double height = 180,
  double current = 78,
  double target = 78,
  ActivityLevel activity = ActivityLevel.active,
  int days = 84,
  ProteinPlan protein = ProteinPlan.balanced,
  FatPlan fat = FatPlan.balanced,
  int? kcalOverride,
  double? rate,
}) => NutritionEngine.compute(
  sex: sex,
  age: age,
  heightCm: height,
  currentKg: current,
  targetKg: target,
  activity: activity,
  durationDays: days,
  proteinPlan: protein,
  fatPlan: fat,
  kcalOverride: kcalOverride,
  weeklyRateKgOverride: rate,
);

void main() {
  group('BMR / TDEE', () {
    test('Mifflin-St Jeor male', () {
      // 10*78 + 6.25*180 - 5*23 + 5 = 1795
      expect(
        NutritionEngine.bmr(
          sex: BioSex.male,
          weightKg: 78,
          heightCm: 180,
          age: 23,
        ),
        closeTo(1795, 0.01),
      );
    });

    test('female is 166 kcal lower than male, same stats', () {
      final m = NutritionEngine.bmr(
        sex: BioSex.male,
        weightKg: 70,
        heightCm: 170,
        age: 30,
      );
      final f = NutritionEngine.bmr(
        sex: BioSex.female,
        weightKg: 70,
        heightCm: 170,
        age: 30,
      );
      expect(m - f, closeTo(166, 0.01));
    });

    test('TDEE = BMR × activity factor', () {
      final p = _plan(activity: ActivityLevel.active);
      expect(p.tdee, closeTo(1795 * 1.55, 0.5));
    });
  });

  group('macros tell one story (sum to kcal)', () {
    test('maintain: macro kcal ≈ total kcal', () {
      final p = _plan(); // maintain
      final macroKcal = p.proteinG * 4 + p.carbsG * 4 + p.fatG * 9;
      expect(macroKcal, closeTo(p.kcal, 15));
    });

    test('bulk: carbs absorb the surplus (more than maintain)', () {
      final maintain = _plan(target: 78);
      final bulk = _plan(target: 90, days: 84); // big surplus
      expect(bulk.kcal, greaterThan(maintain.kcal));
      expect(bulk.carbsG, greaterThan(maintain.carbsG));
      // protein is bodyweight-based, not calorie-based → unchanged
      expect(bulk.proteinG, maintain.proteinG);
      final macroKcal = bulk.proteinG * 4 + bulk.carbsG * 4 + bulk.fatG * 9;
      expect(macroKcal, closeTo(bulk.kcal, 15));
    });

    test('protein scales with bodyweight, not stuck at a stale value', () {
      final light = _plan(current: 60);
      final heavy = _plan(current: 100);
      expect(heavy.proteinG, greaterThan(light.proteinG));
      // 1.6 g/kg balanced
      expect(heavy.proteinG, closeTo(160, 1));
      expect(light.proteinG, closeTo(96, 1));
    });
  });

  group('pace tiers', () {
    test('maintain when target == current', () {
      expect(_plan(target: 78).paceTier, PaceTier.maintain);
    });

    test('gentle gain → sustainable', () {
      // +1 kg over 12 weeks ≈ 0.083 kg/wk ≈ 0.1%/wk
      expect(_plan(target: 79, days: 84).paceTier, PaceTier.sustainable);
    });

    test('fast loss → extreme/unsafe, not silently capped away', () {
      // lose 12 kg in 4 weeks = 3 kg/wk ≈ 3.8%/wk
      final p = _plan(target: 66, days: 28);
      expect(p.paceTier, anyOf(PaceTier.extreme, PaceTier.unsafe));
    });

    test('below-floor request clamps to floor + flags unsafe', () {
      // huge deficit pushes kcal under the floor
      final p = _plan(
        current: 60,
        target: 45,
        days: 21,
        activity: ActivityLevel.sedentary,
      );
      expect(p.clampedToFloor, isTrue);
      expect(p.paceTier, PaceTier.unsafe);
      expect(p.kcal, greaterThanOrEqualTo(1500)); // male floor
    });
  });

  group('micros are demographic + capped', () {
    test('iron differs by sex (women 18, men 8)', () {
      expect(_plan(sex: BioSex.male).micros['iron_mg'], 8);
      expect(_plan(sex: BioSex.female).micros['iron_mg'], 18);
    });

    test('sugar / sat-fat caps scale with calories', () {
      final low = _plan(kcalOverride: 2000);
      final high = _plan(kcalOverride: 3000);
      expect(low.microCaps['sugar_g'], closeTo(50, 0.1)); // 10% of 2000 / 4
      expect(
        high.microCaps['sugar_g']!,
        greaterThan(low.microCaps['sugar_g']!),
      );
      expect(low.microCaps['sodium_mg'], 2300); // fixed
    });

    test('fiber scales with calories (14 g / 1000 kcal)', () {
      expect(_plan(kcalOverride: 2000).fiberG, 28);
      expect(_plan(kcalOverride: 3000).fiberG, 42);
    });
  });

  test('kcal override pins calories, macros re-derive', () {
    final p = _plan(kcalOverride: 3500);
    expect(p.kcal, 3500);
    final macroKcal = p.proteinG * 4 + p.carbsG * 4 + p.fatG * 9;
    expect(macroKcal, closeTo(3500, 15));
  });

  group('rate-driven pace (slider drives calories directly)', () {
    test('a weekly-rate request sets the daily adjustment directly', () {
      // +0.5 kg/wk ≈ +0.5 × 7700 / 7 ≈ +550 kcal/day over maintenance.
      final maintain = _plan(target: 90, days: 0); // delta but no timeline → maintain
      final gain = _plan(target: 90, days: 0, rate: 0.5);
      expect(gain.kcal - maintain.kcal, closeTo(550, 1));
      expect(gain.weeklyRateKg, closeTo(0.5, 0.001));
      expect(gain.paceTier, isNot(PaceTier.maintain));
    });

    test('rate is faithful for small deltas (no timeline round-trip distortion)',
        () {
      // Only 0.5 kg to lose, but an aggressive 1.0 kg/wk pace. The OLD path
      // round-tripped through a min-7-day timeline and silently produced a far
      // gentler effective rate; rate-driven, the effective rate matches intent.
      final p = _plan(
        current: 95,
        target: 94.5,
        activity: ActivityLevel.athlete,
        days: 0,
        rate: -1.0,
      );
      expect(p.weeklyRateKg, closeTo(-1.0, 0.001));
      expect(p.clampedToFloor, isFalse); // headroom: deficit doesn't hit floor
    });

    test('rate request takes precedence over durationDays', () {
      // The timeline alone would imply a big surplus; the rate wins.
      final p = _plan(target: 90, days: 30, rate: 0.25);
      expect(p.weeklyRateKg, closeTo(0.25, 0.001));
    });

    test('kcal override still wins over a rate request', () {
      final p = _plan(target: 90, days: 0, rate: 1.0, kcalOverride: 2600);
      expect(p.kcal, 2600);
    });

    test('headline rate and effective rate agree → ETA is consistent', () {
      // Lose 8 kg at 0.7 kg/wk → ETA ≈ 8 / 0.7 × 7 ≈ 80 days.
      final p = _plan(current: 90, target: 82, days: 0, rate: -0.7);
      expect(p.weeklyRateKg, closeTo(-0.7, 0.001));
      expect(p.etaDays, closeTo(80, 1));
    });
  });

  group('ideal weight range + band fit', () {
    test('healthy BMI band (18.5–24.9) for a height', () {
      final r = idealWeightRange(180); // 1.8m² = 3.24
      expect(r.lo, closeTo(18.5 * 3.24, 0.01));
      expect(r.hi, closeTo(24.9 * 3.24, 0.01));
    });

    test('classifies target against the band', () {
      // 180 cm → ~60–81 kg healthy.
      expect(weightBandFit(72, 180), WeightBandFit.within);
      expect(weightBandFit(95, 180), WeightBandFit.above);
      expect(weightBandFit(50, 180), WeightBandFit.below);
    });

    test('degenerate height is safe', () {
      expect(idealWeightRange(0).hi, 0);
      expect(weightBandFit(70, 0), WeightBandFit.within);
    });
  });

  group('pace slider bounds', () {
    test('gain band reaches into the unsafe zone (rapid-gain reachable)', () {
      final b = paceSliderBounds('gain');
      expect(b.min, lessThan(0.1));
      // 1.5 kg/wk on a ~75 kg person is ~2%/wk → far past the safe band.
      expect(b.max, greaterThanOrEqualTo(1.5));
      final fast = _plan(target: 95, days: 56); // ~2.5 kg/wk gain
      expect(fast.paceTier, PaceTier.unsafe);
    });

    test('loss band allows up to 1.5 kg/wk', () {
      expect(paceSliderBounds('lose').max, greaterThanOrEqualTo(1.5));
    });
  });

  group('recommendedWeeklyRate', () {
    test('gain is the slower (~0.25 %bw/wk) sustainable rate', () {
      // 80 kg × 0.0025 = 0.20, already on a 0.05 detent.
      expect(recommendedWeeklyRate(80, gaining: true), closeTo(0.20, 1e-9));
    });

    test('loss is the faster (~0.5 %bw/wk) sustainable rate', () {
      expect(recommendedWeeklyRate(80, gaining: false), closeTo(0.40, 1e-9));
    });

    test('snaps to the slider 0.05 detents', () {
      // 83 kg loss → 0.415 raw → snaps to 0.40.
      expect(recommendedWeeklyRate(83, gaining: false), closeTo(0.40, 1e-9));
      final r = recommendedWeeklyRate(83, gaining: false);
      expect((r / 0.05).roundToDouble(), (r / 0.05), reason: 'on a detent');
    });

    test('clamps into the direction bounds and guards bad weight', () {
      final lo = recommendedWeeklyRate(0, gaining: true); // bad weight → 75 kg
      final b = paceSliderBounds('gain');
      expect(lo, greaterThanOrEqualTo(b.min));
      expect(lo, lessThanOrEqualTo(b.max));
    });
  });

  group('BMI', () {
    test('computes kg/m² and guards bad input', () {
      // 80 kg @ 200 cm → exactly 20.0.
      expect(bmiFor(80, 200), closeTo(20.0, 0.001));
      expect(bmiFor(70, 0), 0);
      expect(bmiFor(0, 180), 0);
    });

    test('bands at WHO thresholds', () {
      expect(bmiBand(18.4), BmiBand.underweight);
      expect(bmiBand(18.5), BmiBand.healthy);
      expect(bmiBand(24.9), BmiBand.healthy);
      expect(bmiBand(25.0), BmiBand.overweight);
      expect(bmiBand(29.9), BmiBand.overweight);
      expect(bmiBand(30.0), BmiBand.obese);
    });

    test('band labels', () {
      expect(BmiBand.healthy.label, 'Healthy');
      expect(BmiBand.obese.label, 'Obese');
    });
  });

  group('maintenance kcal', () {
    test('equals BMR × activity factor and climbs with activity', () {
      final sed = NutritionEngine.maintenanceKcal(
        sex: BioSex.male,
        age: 23,
        heightCm: 180,
        weightKg: 78,
        activity: ActivityLevel.sedentary,
      );
      final ath = NutritionEngine.maintenanceKcal(
        sex: BioSex.male,
        age: 23,
        heightCm: 180,
        weightKg: 78,
        activity: ActivityLevel.athlete,
      );
      final b = NutritionEngine.bmr(
        sex: BioSex.male,
        weightKg: 78,
        heightCm: 180,
        age: 23,
      );
      expect(sed, (b * 1.2).round());
      expect(ath, greaterThan(sed)); // athlete burns far more
      // A maintain-plan's kcal should match the maintenance convenience at the
      // same activity level (_plan defaults to ActivityLevel.active).
      final active = NutritionEngine.maintenanceKcal(
        sex: BioSex.male,
        age: 23,
        heightCm: 180,
        weightKg: 78,
        activity: ActivityLevel.active,
      );
      final plan = _plan(target: 78, days: 0);
      expect(plan.kcal, closeTo(active.toDouble(), 1));
    });
  });

  group('goalFromDelta', () {
    test('classifies direction with a maintain dead-band', () {
      expect(goalFromDelta(75, 80), 'gain');
      expect(goalFromDelta(75, 70), 'lose');
      expect(goalFromDelta(75, 75), 'maintain');
      expect(goalFromDelta(75, 75.3), 'maintain'); // within dead-band
      expect(goalFromDelta(75, 75.5), 'gain'); // past dead-band
    });
  });
}

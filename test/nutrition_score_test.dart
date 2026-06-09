import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/food/scoring/nutrition_score.dart';
import 'package:atlas/features/home/scoring/score_engine.dart' show kOvershootCap;

void main() {
  group('phaseFromGoalString', () {
    test('gain/bulk → bulk', () {
      expect(phaseFromGoalString('gain'), BodyPhase.bulk);
      expect(phaseFromGoalString('bulk'), BodyPhase.bulk);
      expect(phaseFromGoalString('GAIN'), BodyPhase.bulk);
    });
    test('lose/cut → cut', () {
      expect(phaseFromGoalString('lose'), BodyPhase.cut);
      expect(phaseFromGoalString('cut'), BodyPhase.cut);
    });
    test('null/unknown → maintain', () {
      expect(phaseFromGoalString(null), BodyPhase.maintain);
      expect(phaseFromGoalString('whatever'), BodyPhase.maintain);
      expect(phaseFromGoalString('maintain'), BodyPhase.maintain);
    });
  });

  group('calorieAdherence — bulk', () {
    test('on target → 1.0', () {
      expect(
        calorieAdherence(
            currentKcal: 3000, targetKcal: 3000, phase: BodyPhase.bulk),
        1.0,
      );
    });
    test('10% over → 1.10 (overshoot bonus)', () {
      expect(
        calorieAdherence(
            currentKcal: 3300, targetKcal: 3000, phase: BodyPhase.bulk),
        closeTo(1.10, 1e-9),
      );
    });
    test('25% over → capped at kOvershootCap', () {
      expect(
        calorieAdherence(
            currentKcal: 3750, targetKcal: 3000, phase: BodyPhase.bulk),
        kOvershootCap,
      );
    });
    test('80% intake → 0.8 (no penalty band)', () {
      expect(
        calorieAdherence(
            currentKcal: 2400, targetKcal: 3000, phase: BodyPhase.bulk),
        closeTo(0.8, 1e-9),
      );
    });
    test('0 intake → 0', () {
      expect(
        calorieAdherence(
            currentKcal: 0, targetKcal: 3000, phase: BodyPhase.bulk),
        0.0,
      );
    });
  });

  group('calorieAdherence — cut', () {
    test('at target → 1.0', () {
      expect(
        calorieAdherence(
            currentKcal: 2000, targetKcal: 2000, phase: BodyPhase.cut),
        1.0,
      );
    });
    test('under target → 1.0 (you stayed under)', () {
      expect(
        calorieAdherence(
            currentKcal: 1500, targetKcal: 2000, phase: BodyPhase.cut),
        1.0,
      );
    });
    test('5% over → 0.5', () {
      expect(
        calorieAdherence(
            currentKcal: 2100, targetKcal: 2000, phase: BodyPhase.cut),
        closeTo(0.5, 1e-9),
      );
    });
    test('10% over → 0', () {
      expect(
        calorieAdherence(
            currentKcal: 2200, targetKcal: 2000, phase: BodyPhase.cut),
        closeTo(0.0, 1e-9),
      );
    });
    test('20% over → hard 0', () {
      expect(
        calorieAdherence(
            currentKcal: 2400, targetKcal: 2000, phase: BodyPhase.cut),
        0.0,
      );
    });
  });

  group('calorieAdherence — maintain', () {
    test('exactly target → 1.0', () {
      expect(
        calorieAdherence(
            currentKcal: 2500, targetKcal: 2500, phase: BodyPhase.maintain),
        1.0,
      );
    });
    test('±5% → 1.0', () {
      expect(
        calorieAdherence(
            currentKcal: 2625, targetKcal: 2500, phase: BodyPhase.maintain),
        1.0,
      );
      expect(
        calorieAdherence(
            currentKcal: 2375, targetKcal: 2500, phase: BodyPhase.maintain),
        1.0,
      );
    });
    test('±20% → 0.5', () {
      expect(
        calorieAdherence(
            currentKcal: 3000, targetKcal: 2500, phase: BodyPhase.maintain),
        closeTo(0.5, 1e-9),
      );
    });
    test('beyond ±35% → 0', () {
      expect(
        calorieAdherence(
            currentKcal: 5000, targetKcal: 2500, phase: BodyPhase.maintain),
        0.0,
      );
    });
  });

  group('proteinAdherence', () {
    test('0 → 0', () {
      expect(proteinAdherence(currentG: 0, targetG: 180), 0.0);
    });
    test('80% of target → 1.0 (the easier curve)', () {
      expect(
        proteinAdherence(currentG: 144, targetG: 180),
        closeTo(1.0, 1e-9),
      );
    });
    test('100% of target → 1.10 (small bonus)', () {
      expect(
        proteinAdherence(currentG: 180, targetG: 180),
        closeTo(1.10, 1e-9),
      );
    });
    test('excess capped at kOvershootCap', () {
      expect(
        proteinAdherence(currentG: 360, targetG: 180),
        kOvershootCap,
      );
    });
  });

  group('nutritionDayScore', () {
    test('perfect day → 1.0', () {
      final s = nutritionDayScore(
        currentKcal: 3000,
        targetKcal: 3000,
        currentProteinG: 144,
        targetProteinG: 180,
        phase: BodyPhase.bulk,
      );
      // 1.0 × 0.6 + 1.0 × 0.4 = 1.0
      expect(s, closeTo(1.0, 1e-9));
    });
    test('empty day → 0', () {
      expect(
        nutritionDayScore(
          currentKcal: 0,
          targetKcal: 3000,
          currentProteinG: 0,
          targetProteinG: 180,
          phase: BodyPhase.bulk,
        ),
        0.0,
      );
    });
    test('half-day bulk → roughly half score', () {
      final s = nutritionDayScore(
        currentKcal: 1500,
        targetKcal: 3000,
        currentProteinG: 90,
        targetProteinG: 180,
        phase: BodyPhase.bulk,
      );
      // calorie: 0.5 / 0.8 band → 0.5 × 0.625 = 0.3125
      // protein: 90/180 = 0.5 → 0.5/0.8 = 0.625
      // total: 0.3125 × 0.6 + 0.625 × 0.4 = 0.4375
      expect(s, closeTo(0.4375, 1e-9));
    });
    test('cutting overshoot capped properly', () {
      final s = nutritionDayScore(
        currentKcal: 2400,
        targetKcal: 2000,
        currentProteinG: 180,
        targetProteinG: 180,
        phase: BodyPhase.cut,
      );
      // calorie cut at 20% over = 0; protein = 1.1
      // total: 0 × 0.6 + 1.1 × 0.4 = 0.44
      expect(s, closeTo(0.44, 1e-9));
    });
  });
}

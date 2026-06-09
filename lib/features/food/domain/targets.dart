import 'food.dart';

/// Daily targets the diary compares against.
///
/// Macros come from the user profile (Mifflin-St Jeor or manual override).
/// Micros default to adult-male RDA with athlete bumps (Vit D, iron, zinc +20%).
class DailyTargets {
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final Nutrients micros;

  /// Upper-bound nutrients — flag as *over* when exceeded, not under.
  static const upperBoundKeys = <String>{
    'sat_fat_g',
    'trans_fat_g',
    'sugar_g',
    'cholesterol_mg',
    'sodium_mg',
  };

  const DailyTargets({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.micros,
  });

  /// Compute targets from user profile + bodyweight.
  /// Manual macro overrides take precedence over auto-split.
  factory DailyTargets.fromProfile({
    required int kcalTarget,
    required int proteinTarget,
    int? carbsTarget,
    int? fatTarget,
    int? fiberTarget,
    double? bodyWeightKg,
  }) {
    // Carbs/fat: use manual override if given, else auto-split.
    final proteinKcal = proteinTarget * 4;
    final remaining = (kcalTarget - proteinKcal).clamp(0, double.infinity);
    final carbs = carbsTarget?.toDouble() ?? remaining * 0.55 / 4;
    final fat = fatTarget?.toDouble() ?? remaining * 0.45 / 9;
    final micros = athleteMicroRDA(kcal: kcalTarget.toDouble());
    return DailyTargets(
      kcal: kcalTarget.toDouble(),
      proteinG: proteinTarget.toDouble(),
      carbsG: carbs,
      fatG: fat,
      micros: Nutrients(
        fiberG: fiberTarget?.toDouble() ?? micros.fiberG,
        sugarG: micros.sugarG,
        satFatG: micros.satFatG, transFatG: micros.transFatG,
        cholesterolMg: micros.cholesterolMg,
        sodiumMg: micros.sodiumMg, potassiumMg: micros.potassiumMg,
        calciumMg: micros.calciumMg, ironMg: micros.ironMg,
        magnesiumMg: micros.magnesiumMg, zincMg: micros.zincMg,
        vitAUg: micros.vitAUg, vitCMg: micros.vitCMg,
        vitDUg: micros.vitDUg, vitEMg: micros.vitEMg, vitKUg: micros.vitKUg,
        b6Mg: micros.b6Mg, b12Ug: micros.b12Ug, folateUg: micros.folateUg,
      ),
    );
  }

  /// Athlete-tuned RDA: adult male baseline with iron/zinc/Vit-D bumped 20%.
  /// Fiber scales with kcal at 14 g per 1000 kcal.
  static Nutrients athleteMicroRDA({required double kcal}) => Nutrients(
        fiberG: 14 * kcal / 1000,
        sugarG: 50,
        satFatG: 25, transFatG: 2,
        cholesterolMg: 300,
        sodiumMg: 2300, potassiumMg: 3500,
        calciumMg: 1000, ironMg: 21.6 /* 18 × 1.2 */, magnesiumMg: 420,
        zincMg: 13.2 /* 11 × 1.2 */,
        vitAUg: 900, vitCMg: 90,
        vitDUg: 24 /* 20 × 1.2 */, vitEMg: 15, vitKUg: 120,
        b6Mg: 1.7, b12Ug: 2.4, folateUg: 400,
      );
}

/// Status for a single nutrient row.
enum NutrientStatus { under, onTrack, over }

NutrientStatus statusFor({
  required double value,
  required double target,
  required bool isUpperBound,
}) {
  if (target <= 0) return NutrientStatus.onTrack;
  final pct = value / target;
  if (isUpperBound) {
    if (pct > 1.0) return NutrientStatus.over;
    return NutrientStatus.onTrack;
  }
  if (pct >= 0.9) return NutrientStatus.onTrack;
  if (pct < 0.5)  return NutrientStatus.under;
  return NutrientStatus.onTrack;
}

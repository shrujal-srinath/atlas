/// Pure, deterministic nutrition target engine — no Riverpod / Supabase / UI.
///
/// Turns a user profile (sex, age, height, current+target weight, activity,
/// timeline, macro preferences) into a fully *correlated* set of daily targets:
/// calories, macros (which always sum exactly to the calorie total), fiber,
/// water, and demographic micronutrients with healthy upper limits.
///
/// Sources (cited in the in-app "How we calculate" sheet):
///  - Calories: Mifflin-St Jeor BMR × activity factor (TDEE). 1 kg fat ≈ 7700 kcal.
///  - Pace: CDC/NHS (0.5–1 kg/wk), ACSM. Floor: ≥ BMR, never < 1200 ♀ / 1500 ♂.
///  - Protein: ISSN Position Stand (Jäger 2017) 1.4–2.0 g/kg active, up to 2.2+ for cuts; RDA 0.8.
///  - Fat: IOM AMDR 20–35% kcal (min ~0.8 g/kg for hormones). Carbs = remainder (AMDR 45–65%).
///  - Fiber: IOM 14 g / 1000 kcal. Water: NASEM (~35 ml/kg + activity).
///  - Micros: NIH ODS / IOM DRI by sex + age band. Upper limits: WHO/DGA (sugar, sat fat, sodium…).
library;

enum BioSex { male, female, other }

enum ActivityLevel { sedentary, light, active, veryActive, athlete }

double activityFactor(ActivityLevel a) => switch (a) {
  ActivityLevel.sedentary => 1.2,
  ActivityLevel.light => 1.375,
  ActivityLevel.active => 1.55,
  ActivityLevel.veryActive => 1.725,
  ActivityLevel.athlete => 1.9,
};

/// Difficulty band of the chosen weight-change pace.
enum PaceTier { maintain, sustainable, hard, extreme, unsafe }

extension PaceTierX on PaceTier {
  String get label => switch (this) {
    PaceTier.maintain => 'Maintain',
    PaceTier.sustainable => 'Sustainable',
    PaceTier.hard => 'Hard',
    PaceTier.extreme => 'Extreme',
    PaceTier.unsafe => 'Unsafe',
  };

  String get blurb => switch (this) {
    PaceTier.maintain => 'Holding your weight.',
    PaceTier.sustainable =>
      'Comfortable and muscle-sparing — easy to stick to.',
    PaceTier.hard => 'Demanding — needs high protein and discipline.',
    PaceTier.extreme =>
      'Aggressive — real muscle-loss / rebound risk. Tread carefully.',
    PaceTier.unsafe => 'Not recommended — below healthy limits.',
  };
}

/// Protein preset (g per kg bodyweight). `custom` uses an explicit value.
enum ProteinPlan { general, balanced, building, cutting, custom }

double proteinPerKgFor(ProteinPlan p) => switch (p) {
  ProteinPlan.general => 1.2, // general health (active minimum)
  ProteinPlan.balanced => 1.6, // muscle maintenance / general fitness
  ProteinPlan.building => 2.0, // hypertrophy / lean bulk
  ProteinPlan.cutting => 2.2, // preserve muscle in a deficit
  ProteinPlan.custom => 1.6,
};

/// Fat preset (fraction of calories). `custom` uses an explicit value.
enum FatPlan { lower, balanced, higher, custom }

double fatPctFor(FatPlan p) => switch (p) {
  FatPlan.lower => 0.20,
  FatPlan.balanced => 0.27,
  FatPlan.higher => 0.35,
  FatPlan.custom => 0.27,
};

// ── Profile-string → engine-enum mappers ──────────────────────────────
// Single source of truth so onboarding, the goal screen, and the live
// provider all translate the user's profile the same way (no "different
// story"). Inputs are normalised so stored variants ('Very Active') still map.

BioSex bioSexFromKey(String g) => switch (g.toLowerCase().trim()) {
  'male' => BioSex.male,
  'female' => BioSex.female,
  _ => BioSex.other,
};

ActivityLevel activityFromKey(String a) =>
    switch (a.toLowerCase().trim().replaceAll(' ', '_')) {
      'sedentary' => ActivityLevel.sedentary,
      'light' || 'lightly_active' => ActivityLevel.light,
      'very_active' => ActivityLevel.veryActive,
      'athlete' => ActivityLevel.athlete,
      _ => ActivityLevel.active, // 'active'/'moderate' + default
    };

/// Goal-derived protein preset when the user hasn't picked one explicitly.
ProteinPlan proteinPlanForGoalKey(String goal) =>
    switch (goal.toLowerCase().trim()) {
      'gain' => ProteinPlan.building,
      'lose' => ProteinPlan.cutting,
      _ => ProteinPlan.balanced,
    };

/// Named protein preset from `nutrition_prefs`, or null to fall back.
ProteinPlan? proteinPlanFromName(String? n) => switch (n) {
  'general' => ProteinPlan.general,
  'balanced' => ProteinPlan.balanced,
  'building' => ProteinPlan.building,
  'cutting' => ProteinPlan.cutting,
  'custom' => ProteinPlan.custom,
  _ => null,
};

/// Named fat preset from `nutrition_prefs`, or null to fall back.
FatPlan? fatPlanFromName(String? n) => switch (n) {
  'lower' => FatPlan.lower,
  'balanced' => FatPlan.balanced,
  'higher' => FatPlan.higher,
  'custom' => FatPlan.custom,
  _ => null,
};

/// Healthy body-weight range (kg) for a height, from the WHO healthy BMI band
/// (18.5–24.9). Used to reassure / gently flag the user's chosen target.
({double lo, double hi}) idealWeightRange(double heightCm) {
  if (heightCm <= 0) return (lo: 0, hi: 0);
  final m2 = (heightCm / 100) * (heightCm / 100);
  return (lo: 18.5 * m2, hi: 24.9 * m2);
}

/// Where a target weight sits relative to the healthy range.
enum WeightBandFit { below, within, above }

WeightBandFit weightBandFit(double targetKg, double heightCm) {
  final r = idealWeightRange(heightCm);
  if (r.hi <= 0) return WeightBandFit.within;
  if (targetKg < r.lo - 0.05) return WeightBandFit.below;
  if (targetKg > r.hi + 0.05) return WeightBandFit.above;
  return WeightBandFit.within;
}

/// Slider bounds (kg/week, always positive) for the pace control. The max is
/// pushed *past* the safe band on purpose: the user may drive into Hard →
/// Extreme → Unsafe (coloured + warned) rather than being silently capped at
/// "sensible". Anything beyond this is handled by manual calorie entry.
({double min, double max}) paceSliderBounds(String goal) =>
    goal.toLowerCase().trim() == 'gain'
    ? (min: 0.05, max: 1.5)
    : (min: 0.1, max: 1.5);

/// The recommended weekly rate (kg/week, always positive) for a direction — the
/// fastest still-*sustainable* pace: ~0.25 %bw/wk for a gain (lean mass accrues
/// slowly) and ~0.5 %bw/wk for a loss. Snapped to the slider's 0.05 detents and
/// clamped to its bounds, so it lands exactly on a notch. One source of truth so
/// the onboarding flow, the in-app editor and the slider's "recommended" marker
/// all point at the same number.
double recommendedWeeklyRate(double currentKg, {required bool gaining}) {
  final w = currentKg > 0 ? currentKg : 75.0;
  final raw = gaining ? w * 0.0025 : w * 0.005;
  final snapped = (raw / 0.05).round() * 0.05;
  final b = paceSliderBounds(gaining ? 'gain' : 'lose');
  return snapped.clamp(b.min, b.max);
}

/// Default target weight (≈5 kg toward the goal, never below a 40 kg floor)
/// until the user sets a real one — so the engine still produces a sensible
/// surplus/deficit and the screens + provider agree.
double defaultTargetKg(double currentKg, String goal) =>
    switch (goal.toLowerCase().trim()) {
      'gain' => currentKg + 5,
      'lose' => (currentKg - 5).clamp(40.0, currentKg),
      _ => currentKg,
    };

/// Body Mass Index (kg/m²) for a weight + height. Returns 0 for invalid height.
double bmiFor(double kg, double heightCm) {
  if (heightCm <= 0 || kg <= 0) return 0;
  final m = heightCm / 100;
  return kg / (m * m);
}

/// WHO BMI bands. `healthy` = 18.5–24.9.
enum BmiBand { underweight, healthy, overweight, obese }

BmiBand bmiBand(double bmi) {
  if (bmi < 18.5) return BmiBand.underweight;
  if (bmi < 25) return BmiBand.healthy;
  if (bmi < 30) return BmiBand.overweight;
  return BmiBand.obese;
}

extension BmiBandX on BmiBand {
  String get label => switch (this) {
    BmiBand.underweight => 'Underweight',
    BmiBand.healthy => 'Healthy',
    BmiBand.overweight => 'Overweight',
    BmiBand.obese => 'Obese',
  };
}

/// Infer the weight-change direction from current → target, with a small
/// dead-band so a near-equal target reads as "maintain". Single source so the
/// goal flow and any caller classify direction identically.
String goalFromDelta(double currentKg, double targetKg) {
  final delta = targetKg - currentKg;
  if (delta > 0.4) return 'gain';
  if (delta < -0.4) return 'lose';
  return 'maintain';
}

/// The fully-resolved daily plan.
class NutritionPlan {
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final int waterMl;

  /// Micronutrient targets (lower-bound RDA/AI) keyed by nutrient id.
  final Map<String, double> micros;

  /// Upper-limit targets (flag as *over* when exceeded) keyed by nutrient id.
  final Map<String, double> microCaps;

  final double bmr;
  final double tdee;

  /// Signed weekly weight change at the *effective* (floor-clamped) rate, kg.
  final double weeklyRateKg;

  /// Signed kcal adjustment vs TDEE actually applied (after floor clamp).
  final int dailyAdjustKcal;

  final PaceTier paceTier;

  /// Realistic days to reach the target at the effective rate (null = maintain
  /// or no movement). May exceed the requested timeline when clamped.
  final int? etaDays;

  /// True when the calorie target was raised to the safety floor.
  final bool clampedToFloor;

  const NutritionPlan({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.waterMl,
    required this.micros,
    required this.microCaps,
    required this.bmr,
    required this.tdee,
    required this.weeklyRateKg,
    required this.dailyAdjustKcal,
    required this.paceTier,
    required this.etaDays,
    required this.clampedToFloor,
  });
}

class NutritionEngine {
  static const kcalPerKgFat = 7700.0;

  /// Mifflin-St Jeor BMR. `other`/unknown sex → average of male & female.
  static double bmr({
    required BioSex sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    // 'other' uses the midpoint of the male (+5) / female (−161) sex term.
    final term = switch (sex) {
      BioSex.male => 5.0,
      BioSex.female => -161.0,
      BioSex.other => -78.0,
    };
    return base + term;
  }

  /// Maintenance calories (TDEE) — BMR × activity factor, rounded. Convenience
  /// for surfacing "what you'd eat to hold weight" without building a full plan.
  static int maintenanceKcal({
    required BioSex sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activity,
  }) {
    final b = bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age);
    return (b * activityFactor(activity)).round();
  }

  static double _floor(BioSex sex, double bmr) {
    final hard = switch (sex) {
      BioSex.female => 1200.0,
      BioSex.male => 1500.0,
      BioSex.other => 1350.0,
    };
    return bmr > hard ? bmr : hard;
  }

  /// Classify the requested pace by |% bodyweight / week| and direction.
  static PaceTier _classify({
    required double weeklyRateKg,
    required double currentKg,
  }) {
    if (weeklyRateKg.abs() < 1e-6 || currentKg <= 0) return PaceTier.maintain;
    final pctWk = (weeklyRateKg.abs() / currentKg) * 100;
    final losing = weeklyRateKg < 0;
    if (losing) {
      if (pctWk <= 0.5) return PaceTier.sustainable;
      if (pctWk <= 1.0) return PaceTier.hard;
      if (pctWk <= 1.5) return PaceTier.extreme;
      return PaceTier.unsafe;
    } else {
      if (pctWk <= 0.25) return PaceTier.sustainable;
      if (pctWk <= 0.5) return PaceTier.hard;
      if (pctWk <= 0.75) return PaceTier.extreme;
      return PaceTier.unsafe;
    }
  }

  /// Compute the full plan.
  ///
  /// Precedence for the daily calorie target:
  ///  1. [kcalOverride] — the user pins calories exactly; macros re-derive.
  ///  2. [weeklyRateKgOverride] — a *signed* weekly weight-change request (the
  ///     pace slider: + gain / − loss). Drives calories directly via
  ///     1 kg ≈ 7700 kcal, so the rate the user sees is exactly the rate that
  ///     shapes the plan.
  ///  3. [durationDays] — legacy "cover the delta over this timeline" fallback,
  ///     for profiles saved before the rate was captured.
  ///
  /// (2) is preferred over (3) because round-tripping a rate through an integer
  /// timeline distorted it for small weight changes; the rate is the real intent.
  static NutritionPlan compute({
    required BioSex sex,
    required int age,
    required double heightCm,
    required double currentKg,
    required double targetKg,
    required ActivityLevel activity,
    required int durationDays,
    ProteinPlan proteinPlan = ProteinPlan.balanced,
    double? proteinPerKgOverride,
    FatPlan fatPlan = FatPlan.balanced,
    double? fatPctOverride,
    int? kcalOverride,
    double? weeklyRateKgOverride,
  }) {
    final b = bmr(sex: sex, weightKg: currentKg, heightCm: heightCm, age: age);
    final tdee = b * activityFactor(activity);
    final floor = _floor(sex, b);

    final deltaKg = targetKg - currentKg;
    final days = durationDays <= 0 ? 0 : durationDays;

    // Requested daily adjustment vs maintenance — from the rate when given,
    // else from covering the delta over the timeline.
    final double rawAdjust;
    if (weeklyRateKgOverride != null && weeklyRateKgOverride.abs() >= 1e-6) {
      rawAdjust = weeklyRateKgOverride * kcalPerKgFat / 7;
    } else if (days == 0 || deltaKg.abs() < 1e-6) {
      rawAdjust = 0;
    } else {
      rawAdjust = deltaKg * kcalPerKgFat / days;
    }

    double kcal = (kcalOverride?.toDouble()) ?? (tdee + rawAdjust);
    bool clamped = false;
    if (kcal < floor) {
      kcal = floor;
      clamped = true;
    }

    // Effective adjustment + rate after any clamp / override.
    final effAdjust = kcal - tdee;
    final weeklyRateKg = (effAdjust / kcalPerKgFat) * 7;
    final tier = clamped
        ? PaceTier.unsafe
        : _classify(weeklyRateKg: weeklyRateKg, currentKg: currentKg);

    // ETA at the effective rate (days to cover the remaining delta).
    int? etaDays;
    if (deltaKg.abs() >= 1e-6 && weeklyRateKg.abs() >= 1e-6) {
      // Only counts if we're moving toward the target.
      final movingToward = (deltaKg > 0) == (weeklyRateKg > 0);
      if (movingToward) {
        etaDays = (deltaKg.abs() / (weeklyRateKg.abs() / 7)).round();
      }
    }

    // ── Macros (always sum to kcal) ──────────────────────────────────
    final proteinPerKg =
        proteinPerKgOverride ?? proteinPerKgFor(proteinPlan).clamp(0.8, 3.0);
    final proteinG = currentKg * proteinPerKg;

    final fatPct = (fatPctOverride ?? fatPctFor(fatPlan)).clamp(0.15, 0.45);
    var fatG = (kcal * fatPct) / 9;
    final fatFloor = 0.8 * currentKg; // hormonal minimum
    if (fatG < fatFloor) fatG = fatFloor;

    var carbsKcal = kcal - proteinG * 4 - fatG * 9;
    if (carbsKcal < 0) carbsKcal = 0; // very high protein+fat edge
    final carbsG = carbsKcal / 4;

    final fiberG = 14 * kcal / 1000;
    final waterMl = _water(currentKg, activity);

    return NutritionPlan(
      kcal: kcal.round(),
      proteinG: proteinG.round(),
      carbsG: carbsG.round(),
      fatG: fatG.round(),
      fiberG: fiberG.round(),
      waterMl: waterMl,
      micros: _microRDA(sex: sex, age: age),
      microCaps: _microCaps(kcal: kcal),
      bmr: b,
      tdee: tdee,
      weeklyRateKg: weeklyRateKg,
      dailyAdjustKcal: effAdjust.round(),
      paceTier: tier,
      etaDays: etaDays,
      clampedToFloor: clamped,
    );
  }

  static int _water(double kg, ActivityLevel a) {
    final base = 35 * kg;
    final bump = switch (a) {
      ActivityLevel.sedentary => 0,
      ActivityLevel.light => 250,
      ActivityLevel.active => 500,
      ActivityLevel.veryActive => 750,
      ActivityLevel.athlete => 1000,
    };
    return (((base + bump) / 50).round() * 50);
  }

  /// Lower-bound RDA/AI micronutrients by sex + age band (NIH ODS / IOM DRI).
  /// 'other' averages the male & female tables.
  static Map<String, double> _microRDA({
    required BioSex sex,
    required int age,
  }) {
    if (sex == BioSex.other) {
      final m = _rdaFor(true, age);
      final f = _rdaFor(false, age);
      return {for (final k in m.keys) k: (m[k]! + f[k]!) / 2};
    }
    return _rdaFor(sex == BioSex.male, age);
  }

  static Map<String, double> _rdaFor(bool male, int age) {
    final old = age >= 51;
    final older = age >= 71;
    return {
      'calcium_mg': older ? 1200 : (male ? 1000 : (old ? 1200 : 1000)),
      'iron_mg': male ? 8 : (old ? 8 : 18),
      'magnesium_mg': male ? (age <= 30 ? 400 : 420) : (age <= 30 ? 310 : 320),
      'zinc_mg': male ? 11 : 8,
      'potassium_mg': male ? 3400 : 2600,
      'vit_a_ug': male ? 900 : 700,
      'vit_c_mg': male ? 90 : 75,
      'vit_d_ug': older ? 20 : 15,
      'vit_e_mg': 15,
      'vit_k_ug': male ? 120 : 90,
      'b6_mg': old ? (male ? 1.7 : 1.5) : 1.3,
      'b12_ug': 2.4,
      'folate_ug': 400,
    };
  }

  /// Upper-limit nutrients (flag as *over*). Calorie-aware where the guideline
  /// is a % of energy (sugar, sat fat, trans fat).
  static Map<String, double> _microCaps({required double kcal}) => {
    'sugar_g': (0.10 * kcal) / 4, // WHO added sugar < 10% kcal
    'sat_fat_g': (0.10 * kcal) / 9, // DGA < 10% kcal
    'trans_fat_g': (0.01 * kcal) / 9, // WHO < 1% kcal
    'sodium_mg': 2300, // CDC chronic-disease reduction
    'cholesterol_mg': 300,
  };
}

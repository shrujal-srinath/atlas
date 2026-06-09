/// Per-phase score weights and metadata. The four phases from the README
/// each blend Athletic / Breaking / Building / Nutrition completion
/// differently to match what matters in that training cycle.
class PhaseWeights {
  final double athletic;
  final double breaking;
  final double building;
  final double nutrition;
  const PhaseWeights({
    required this.athletic,
    required this.breaking,
    required this.building,
    required this.nutrition,
  });

  Map<String, double> toJson() => {
        'athletic': athletic,
        'breaking': breaking,
        'building': building,
        'nutrition': nutrition,
      };

  factory PhaseWeights.fromJson(Map<String, dynamic> j) => PhaseWeights(
        athletic: (j['athletic'] as num?)?.toDouble() ?? 0,
        breaking: (j['breaking'] as num?)?.toDouble() ?? 0,
        building: (j['building'] as num?)?.toDouble() ?? 0,
        nutrition: (j['nutrition'] as num?)?.toDouble() ?? 0,
      );
}

/// Default weights per phase. Sum to 1.0 within rounding.
const kPhaseWeights = <String, PhaseWeights>{
  'Rehab + Bulk': PhaseWeights(
    athletic: 0.20,
    breaking: 0.20,
    building: 0.15,
    nutrition: 0.45,
  ),
  'Bulk + Train': PhaseWeights(
    athletic: 0.40,
    breaking: 0.15,
    building: 0.15,
    nutrition: 0.30,
  ),
  'Performance': PhaseWeights(
    athletic: 0.55,
    breaking: 0.15,
    building: 0.10,
    nutrition: 0.20,
  ),
  'Off-season': PhaseWeights(
    athletic: 0.15,
    breaking: 0.35,
    building: 0.35,
    nutrition: 0.15,
  ),
};

PhaseWeights phaseWeightsFor(String name) =>
    kPhaseWeights[name] ??
    const PhaseWeights(
      athletic: 0.50,
      breaking: 0.30,
      building: 0.20,
      nutrition: 0.0,
    );

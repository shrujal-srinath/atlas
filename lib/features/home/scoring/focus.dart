/// The "Focus" system — the single source of truth for how a day's score is
/// weighted across the three sections (Athletic / Mind / Body).
///
/// Whatever the user picks — a persona's phase preset, their own custom
/// weights, or Off — all resolves to ONE normalized weighting that the score
/// engine reads via `sectionWeightsProvider`. The selection is persisted as a
/// JSON blob in `users.section_weights` (repurposed) and resolved live, so the
/// thing you set and the thing that scores you can never diverge.
library;

import '../../../shared/models/models.dart';
import 'section_def.dart';

enum FocusMode { phase, custom, off }

/// A named weighting preset within a persona.
class FocusPhase {
  final String key;
  final String label;
  final String blurb;
  final int athletic;
  final int mind;
  final int body;
  const FocusPhase(this.key, this.label, this.blurb,
      {required this.athletic, required this.mind, required this.body});
}

class FocusPersona {
  final String key;
  final String label;
  final String blurb;
  final List<FocusPhase> phases;
  const FocusPersona(this.key, this.label, this.blurb, this.phases);
}

/// Personas → their tailored phases. Extensible; add personas/phases freely.
const List<FocusPersona> kPersonas = [
  FocusPersona('athlete', 'Athlete', 'Training, performance & recovery.', [
    FocusPhase('rehab_bulk', 'Rehab + Bulk', 'Recover and build mass.',
        athletic: 50, mind: 20, body: 30),
    FocusPhase('bulk_train', 'Bulk + Train', 'Add size while training hard.',
        athletic: 55, mind: 20, body: 25),
    FocusPhase('performance', 'Performance', 'Peak conditioning & competition.',
        athletic: 60, mind: 25, body: 15),
    FocusPhase('offseason', 'Off-season', 'Base habits & recovery.',
        athletic: 35, mind: 30, body: 35),
  ]),
  FocusPersona('student', 'Student', 'Study, focus & well-being.', [
    FocusPhase('exam_crunch', 'Exam Crunch', 'Deep, sustained study focus.',
        athletic: 20, mind: 60, body: 20),
    FocusPhase('term_time', 'Term Time', 'Steady study with balance.',
        athletic: 30, mind: 45, body: 25),
    FocusPhase('break', 'Break', 'Reset and recharge.',
        athletic: 35, mind: 30, body: 35),
  ]),
  FocusPersona('balanced', 'Balanced', 'A bit of everything.', [
    FocusPhase('build', 'Build Habits', 'Form a strong base.',
        athletic: 34, mind: 33, body: 33),
    FocusPhase('maintain', 'Maintain', 'Keep everything ticking.',
        athletic: 40, mind: 30, body: 30),
    FocusPhase('reset', 'Reset', 'Ease back in gently.',
        athletic: 30, mind: 40, body: 30),
  ]),
];

FocusPersona? personaByKey(String key) {
  for (final p in kPersonas) {
    if (p.key == key) return p;
  }
  return null;
}

FocusPhase? phaseByKey(String personaKey, String phaseKey) {
  final p = personaByKey(personaKey);
  if (p == null) return null;
  for (final ph in p.phases) {
    if (ph.key == phaseKey) return ph;
  }
  return null;
}

/// Default label for a section before any rename (the canonical name).
String defaultSectionLabel(HabitSection s) => s.defaultLabel;

/// The persisted focus selection + custom weights + section renames.
class FocusConfig {
  final FocusMode mode;
  final String personaKey;
  final String phaseKey;
  final int customAthletic;
  final int customMind;
  final int customBody;
  final Map<HabitSection, String> labels;

  /// User-added custom sections (each rolls up to a built-in parent for
  /// scoring). Built-ins are implicit; this list holds only the extras.
  final List<SectionDef> customSections;

  const FocusConfig({
    required this.mode,
    required this.personaKey,
    required this.phaseKey,
    required this.customAthletic,
    required this.customMind,
    required this.customBody,
    required this.labels,
    this.customSections = const [],
  });

  /// The full ordered registry: the three built-ins (with renames + colours)
  /// followed by the user's custom sections.
  List<SectionDef> get allSections {
    final builtIns = [
      for (final d in defaultSections())
        d.copyWith(name: labels[HabitSection.values.byName(d.id)]),
    ];
    final customs = [...customSections]
      ..sort((a, b) => a.order.compareTo(b.order));
    return [...builtIns, ...customs];
  }

  /// The sensible default: Balanced › Maintain (≈ the app's historical
  /// 40/30/30), no renames.
  static const FocusConfig defaults = FocusConfig(
    mode: FocusMode.phase,
    personaKey: 'balanced',
    phaseKey: 'maintain',
    customAthletic: 40,
    customMind: 30,
    customBody: 30,
    labels: {},
  );

  /// Parse the stored blob. Backward compatible: a legacy `{athletic, mind,
  /// body}` map (the old `section_weights` shape) is read as custom weights.
  factory FocusConfig.fromRaw(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return defaults;

    final modeStr = raw['mode'] as String?;
    if (modeStr == null) {
      // Legacy shape — plain section weights → treat as custom.
      final a = (raw['athletic'] as num?)?.toInt();
      final m = (raw['mind'] as num?)?.toInt();
      final b = (raw['body'] as num?)?.toInt();
      if (a != null || m != null || b != null) {
        return defaults.copyWith(
          mode: FocusMode.custom,
          customAthletic: a ?? 40,
          customMind: m ?? 30,
          customBody: b ?? 30,
        );
      }
      return defaults;
    }

    final mode = switch (modeStr) {
      'custom' => FocusMode.custom,
      'off' => FocusMode.off,
      _ => FocusMode.phase,
    };
    final custom = (raw['custom'] as Map?)?.cast<String, dynamic>();
    final labelsRaw = (raw['labels'] as Map?)?.cast<String, dynamic>();
    final labels = <HabitSection, String>{};
    if (labelsRaw != null) {
      for (final s in HabitSection.values) {
        final v = labelsRaw[s.name];
        if (v is String && v.trim().isNotEmpty) labels[s] = v.trim();
      }
    }
    final sectionsRaw = raw['sections'] as List?;
    final customSections = <SectionDef>[
      if (sectionsRaw != null)
        for (final m in sectionsRaw.whereType<Map>())
          SectionDef.fromJson(m.cast<String, dynamic>()),
    ].where((s) => !s.builtIn).toList();
    return FocusConfig(
      mode: mode,
      personaKey: raw['persona'] as String? ?? 'balanced',
      phaseKey: raw['phase'] as String? ?? 'maintain',
      customAthletic: (custom?['athletic'] as num?)?.toInt() ?? 40,
      customMind: (custom?['mind'] as num?)?.toInt() ?? 30,
      customBody: (custom?['body'] as num?)?.toInt() ?? 30,
      labels: labels,
      customSections: customSections,
    );
  }

  FocusConfig copyWith({
    FocusMode? mode,
    String? personaKey,
    String? phaseKey,
    int? customAthletic,
    int? customMind,
    int? customBody,
    Map<HabitSection, String>? labels,
    List<SectionDef>? customSections,
  }) =>
      FocusConfig(
        mode: mode ?? this.mode,
        personaKey: personaKey ?? this.personaKey,
        phaseKey: phaseKey ?? this.phaseKey,
        customAthletic: customAthletic ?? this.customAthletic,
        customMind: customMind ?? this.customMind,
        customBody: customBody ?? this.customBody,
        labels: labels ?? this.labels,
        customSections: customSections ?? this.customSections,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'persona': personaKey,
        'phase': phaseKey,
        'custom': {
          'athletic': customAthletic,
          'mind': customMind,
          'body': customBody,
        },
        if (labels.isNotEmpty)
          'labels': {for (final e in labels.entries) e.key.name: e.value},
        if (customSections.isNotEmpty)
          'sections': [for (final s in customSections) s.toJson()],
      };

  /// Label for a section honouring the user's rename.
  String labelFor(HabitSection s) => labels[s] ?? defaultSectionLabel(s);

  /// Short human description of the active focus (for summaries).
  String get summary => switch (mode) {
        FocusMode.off => 'Off · equal weighting',
        FocusMode.custom => 'Custom weighting',
        FocusMode.phase =>
          '${personaByKey(personaKey)?.label ?? 'Balanced'} · ${phaseByKey(personaKey, phaseKey)?.label ?? 'Maintain'}',
      };
}

/// Resolve a [FocusConfig] to normalized section weights (sum ≈ 1.0).
Map<HabitSection, double> resolveFocusWeights(FocusConfig f) {
  int a, m, b;
  switch (f.mode) {
    case FocusMode.off:
      a = 1;
      m = 1;
      b = 1;
    case FocusMode.custom:
      a = f.customAthletic;
      m = f.customMind;
      b = f.customBody;
    case FocusMode.phase:
      final ph = phaseByKey(f.personaKey, f.phaseKey);
      a = ph?.athletic ?? 40;
      m = ph?.mind ?? 30;
      b = ph?.body ?? 30;
  }
  final sum = (a + m + b).toDouble();
  if (sum <= 0) {
    return const {
      HabitSection.athletic: 1 / 3,
      HabitSection.mind: 1 / 3,
      HabitSection.body: 1 / 3,
    };
  }
  return {
    HabitSection.athletic: a / sum,
    HabitSection.mind: m / sum,
    HabitSection.body: b / sum,
  };
}

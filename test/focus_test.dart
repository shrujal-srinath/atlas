import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/home/scoring/focus.dart';
import 'package:atlas/shared/models/models.dart';

double _sum(Map<HabitSection, double> w) =>
    w.values.fold(0.0, (a, b) => a + b);

void main() {
  group('resolveFocusWeights', () {
    test('every persona/phase preset normalizes to 1.0', () {
      for (final p in kPersonas) {
        for (final ph in p.phases) {
          final f = FocusConfig.defaults
              .copyWith(mode: FocusMode.phase, personaKey: p.key, phaseKey: ph.key);
          final w = resolveFocusWeights(f);
          expect(_sum(w), closeTo(1.0, 1e-9),
              reason: '${p.key}/${ph.key} must sum to 1');
        }
      }
    });

    test('off → equal weighting', () {
      final w = resolveFocusWeights(
          FocusConfig.defaults.copyWith(mode: FocusMode.off));
      expect(w[HabitSection.athletic], closeTo(1 / 3, 1e-9));
      expect(w[HabitSection.mind], closeTo(1 / 3, 1e-9));
      expect(w[HabitSection.body], closeTo(1 / 3, 1e-9));
    });

    test('custom weights normalize', () {
      final f = FocusConfig.defaults.copyWith(
        mode: FocusMode.custom,
        customAthletic: 60,
        customMind: 20,
        customBody: 20,
      );
      final w = resolveFocusWeights(f);
      expect(w[HabitSection.athletic], closeTo(0.6, 1e-9));
      expect(_sum(w), closeTo(1.0, 1e-9));
    });

    test('performance phase is athletic-heavy vs exam_crunch mind-heavy', () {
      final perf = resolveFocusWeights(FocusConfig.defaults.copyWith(
          mode: FocusMode.phase, personaKey: 'athlete', phaseKey: 'performance'));
      final exam = resolveFocusWeights(FocusConfig.defaults.copyWith(
          mode: FocusMode.phase, personaKey: 'student', phaseKey: 'exam_crunch'));
      expect(perf[HabitSection.athletic]!,
          greaterThan(perf[HabitSection.mind]!));
      expect(exam[HabitSection.mind]!, greaterThan(exam[HabitSection.athletic]!));
    });
  });

  group('FocusConfig.fromRaw', () {
    test('null → default (Balanced · Maintain)', () {
      final f = FocusConfig.fromRaw(null);
      expect(f.mode, FocusMode.phase);
      expect(f.personaKey, 'balanced');
      expect(f.phaseKey, 'maintain');
    });

    test('legacy plain weights map is read as custom', () {
      final f = FocusConfig.fromRaw({'athletic': 50, 'mind': 30, 'body': 20});
      expect(f.mode, FocusMode.custom);
      expect(f.customAthletic, 50);
      final w = resolveFocusWeights(f);
      expect(w[HabitSection.athletic], closeTo(0.5, 1e-9));
    });

    test('round-trips through toJson', () {
      final f = FocusConfig.defaults.copyWith(
        mode: FocusMode.phase,
        personaKey: 'athlete',
        phaseKey: 'performance',
        labels: {HabitSection.athletic: 'Training'},
      );
      final back = FocusConfig.fromRaw(f.toJson());
      expect(back.mode, FocusMode.phase);
      expect(back.personaKey, 'athlete');
      expect(back.phaseKey, 'performance');
      expect(back.labelFor(HabitSection.athletic), 'Training');
      expect(back.labelFor(HabitSection.mind), 'Mind');
    });

    test('rename labels survive and default when unset', () {
      final f = FocusConfig.fromRaw({
        'mode': 'off',
        'labels': {'mind': 'Study'},
      });
      expect(f.mode, FocusMode.off);
      expect(f.labelFor(HabitSection.mind), 'Study');
      expect(f.labelFor(HabitSection.body), 'Body');
    });
  });
}

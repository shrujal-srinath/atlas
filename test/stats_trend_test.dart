import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/analytics/providers/analytics_provider.dart';

void main() {
  group('trailingMovingAverage (section-trend smoothing)', () {
    test('empty + single', () {
      expect(trailingMovingAverage(const [], 7), isEmpty);
      expect(trailingMovingAverage(const [0.5], 7), [0.5]);
    });

    test('partial window at the start, then full window', () {
      // window 3 over [1,2,3,4,5]:
      // i0: [1]/1=1, i1: [1,2]/2=1.5, i2: [1,2,3]/3=2, i3: [2,3,4]/3=3, i4:[3,4,5]/3=4
      final out = trailingMovingAverage(const [1, 2, 3, 4, 5], 3);
      expect(out, [1.0, 1.5, 2.0, 3.0, 4.0]);
    });

    test('smooths a 0<->1 whipsaw toward the middle (the whole point)', () {
      // Alternating 0,1 raw section ratios → the 7-day average should sit near
      // 0.5, not swing between 0 and 1.
      final raw = List<double>.generate(14, (i) => i.isEven ? 0.0 : 1.0);
      final smoothed = trailingMovingAverage(raw, 7);
      // After a full window, values hover around 0.43–0.57 (3 or 4 of 7 are 1).
      for (final v in smoothed.skip(7)) {
        expect(v, greaterThan(0.3));
        expect(v, lessThan(0.7));
      }
    });

    test('length is preserved', () {
      final raw = List<double>.filled(30, 0.8);
      final out = trailingMovingAverage(raw, 7);
      expect(out.length, 30);
      // constant input → constant output.
      expect(out.every((v) => (v - 0.8).abs() < 1e-9), isTrue);
    });
  });
}

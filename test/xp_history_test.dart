import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/xp/leveling_providers.dart';
import 'package:atlas/features/xp/leveling_engine.dart';

({DateTime date, int delta}) d(int day, int delta) =>
    (date: DateTime(2026, 6, day), delta: delta);

void main() {
  group('buildXpHistory', () {
    test('empty input → empty history', () {
      final h = buildXpHistory(const []);
      expect(h.points, isEmpty);
      expect(h.milestones, isEmpty);
      expect(h.isEmpty, isTrue);
    });

    test('accumulates a running total', () {
      final h = buildXpHistory([d(1, 100), d(2, 70), d(3, 90)]);
      expect(h.points.map((p) => p.cumulative).toList(), [100, 170, 260]);
      expect(h.milestones, isEmpty);
    });

    test('records the first day a level threshold is crossed', () {
      // L2 = 2,100 XP. Crosses on day 3.
      final h = buildXpHistory([d(1, 1000), d(2, 1000), d(3, 200)]);
      expect(h.points.last.cumulative, 2200);
      expect(h.milestones.length, 1);
      expect(h.milestones.single.level, 2);
      expect(h.milestones.single.date, DateTime(2026, 6, 3));
    });

    test('floors the running total at zero (never below L1)', () {
      final h = buildXpHistory([d(1, -50), d(2, 30), d(3, -200), d(4, 100)]);
      expect(h.points.map((p) => p.cumulative).toList(), [0, 30, 0, 100]);
      expect(h.milestones, isEmpty);
    });

    test('crossing several levels in one day records each', () {
      // L2 = 2,100, L3 = 4,200. A 4,300 day clears both.
      final h = buildXpHistory([d(1, 4300)]);
      expect(h.milestones.map((m) => m.level).toList(), [2, 3]);
      expect(h.milestones.every((m) => m.date == DateTime(2026, 6, 1)), isTrue);
    });

    test('milestone levels line up with the engine thresholds', () {
      final h = buildXpHistory([d(1, xpForLevel(2)), d(2, xpForLevel(3) - xpForLevel(2))]);
      expect(h.milestones.map((m) => m.level).toList(), [2, 3]);
    });
  });
}

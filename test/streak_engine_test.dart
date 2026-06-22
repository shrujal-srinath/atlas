import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/core/utils/streak_engine.dart';

void main() {
  final today = DateTime(2026, 6, 16);
  DateTime ago(int n) => DateTime(2026, 6, 16 - n);
  Map<DateTime, int> m(Map<int, int> byAgo) =>
      {for (final e in byAgo.entries) ago(e.key): e.value};

  group('dailyScoreStreak', () {
    test('empty → 0', () {
      expect(dailyScoreStreak(const {}, today: today), 0);
    });

    test('counts consecutive days at/above break-even, breaks below', () {
      // today=80, -1=60, -2=50 all count; -3=40 breaks the run.
      expect(dailyScoreStreak(m({0: 80, 1: 60, 2: 50, 3: 40}), today: today), 3);
    });

    test('today below break-even gets grace (day in progress)', () {
      // today=20 doesn't count and doesn't break; -1 and -2 carry the streak.
      expect(dailyScoreStreak(m({0: 20, 1: 70, 2: 90}), today: today), 2);
    });

    test('a PAST day below break-even ends the run', () {
      expect(dailyScoreStreak(m({0: 90, 1: 30, 2: 90}), today: today), 1);
    });

    test('rest days (missing dates) are skipped, not treated as a miss', () {
      // -1 and -3 are rest days (no row); 0, -2, -4 all clear break-even.
      expect(dailyScoreStreak(m({0: 80, 2: 80, 4: 80}), today: today), 3);
    });

    test('today exactly at break-even counts', () {
      expect(dailyScoreStreak(m({0: 50}), today: today), 1);
    });

    test('today missing does not break; counts from yesterday back', () {
      expect(dailyScoreStreak(m({1: 70, 2: 70}), today: today), 2);
    });

    test('respects a custom break-even threshold', () {
      // breakEven 60: today & -1 (65) count, -2 (55) breaks.
      expect(
          dailyScoreStreak(m({0: 65, 1: 65, 2: 55}),
              today: today, breakEven: 60),
          2);
    });
  });
}

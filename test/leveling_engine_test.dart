import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/xp/leveling_engine.dart';

void main() {
  group('dayXpFromScore', () {
    test('perfect day → +100', () {
      expect(dayXpFromScore(100), 100);
    });

    test('score 75 → +75', () {
      expect(dayXpFromScore(75), 75);
    });

    test('score 50 (boundary) → +50, not negative', () {
      expect(dayXpFromScore(50), 50);
    });

    test('score 49 → -1 (just under threshold)', () {
      expect(dayXpFromScore(49), -1);
    });

    test('score 30 → -20', () {
      expect(dayXpFromScore(30), -20);
    });

    test('score 0 → -50 (floor)', () {
      expect(dayXpFromScore(0), -50);
    });

    test('overshoot 110 → +110 (matches kOvershootCap in score engine)', () {
      expect(dayXpFromScore(110), 110);
    });

    test('above overshoot clamps to 110', () {
      expect(dayXpFromScore(200), 110);
    });
  });

  group('xpForLevel', () {
    test('L1 = 0', () {
      expect(xpForLevel(1), 0);
    });

    test('L2 = 2100', () {
      expect(xpForLevel(2), 2100);
    });

    test('L3 = 4200', () {
      expect(xpForLevel(3), 4200);
    });

    test('L10 = 18,900', () {
      expect(xpForLevel(10), 18900);
    });

    test('L0 / negative → 0', () {
      expect(xpForLevel(0), 0);
      expect(xpForLevel(-5), 0);
    });
  });

  group('levelFromCumulative', () {
    test('0 XP → L1, 0% progress', () {
      final info = levelFromCumulative(0);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 0);
      expect(info.progress, 0);
    });

    test('1050 XP → L1, 50% progress', () {
      final info = levelFromCumulative(1050);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 1050);
      expect(info.progress, closeTo(0.5, 1e-9));
    });

    test('2099 XP → still L1', () {
      final info = levelFromCumulative(2099);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 2099);
    });

    test('2100 XP → L2, 0% into L2', () {
      final info = levelFromCumulative(2100);
      expect(info.level, 2);
      expect(info.xpIntoLevel, 0);
      expect(info.progress, 0);
    });

    test('4200 XP → L3', () {
      expect(levelFromCumulative(4200).level, 3);
    });

    test('negative XP clamps to L1 / 0', () {
      final info = levelFromCumulative(-500);
      expect(info.level, 1);
      expect(info.totalXp, 0);
      expect(info.xpIntoLevel, 0);
    });

    test('round-trip: levelFromCumulative(xpForLevel(L)).level == L', () {
      for (int L = 1; L <= 25; L++) {
        expect(levelFromCumulative(xpForLevel(L)).level, L);
      }
    });
  });

  group('gatedLevelInfo (v2.1 dual gate)', () {
    test('mid-level: behaves like the candidate view', () {
      final info = gatedLevelInfo(confirmedLevel: 2, totalXp: 3150);
      expect(info.level, 2);
      expect(info.xpIntoLevel, 1050);
      expect(info.progress, closeTo(0.5, 1e-9));
      expect(info.xpGatePassed, isFalse);
      expect(info.bankedXp, 0);
    });

    test('XP gate passed but milestone-gated: bar full, surplus banked', () {
      // Confirmed L2, but 5000 XP = past the L3 threshold (4200) by 800.
      final info = gatedLevelInfo(confirmedLevel: 2, totalXp: 5000);
      expect(info.level, 2);
      expect(info.xpIntoLevel, kXpPerLevel);
      expect(info.progress, 1.0);
      expect(info.xpGatePassed, isTrue);
      expect(info.bankedXp, 800);
    });

    test('exactly at the gate: passed with 0 banked', () {
      final info = gatedLevelInfo(confirmedLevel: 1, totalXp: 2100);
      expect(info.xpGatePassed, isTrue);
      expect(info.bankedXp, 0);
      expect(info.progress, 1.0);
    });

    test('no demotion: XP below the confirmed level floors at 0 into-level', () {
      // Confirmed L3 (base 4200) but bad days dragged cumulative to 3900.
      final info = gatedLevelInfo(confirmedLevel: 3, totalXp: 3900);
      expect(info.level, 3);
      expect(info.xpIntoLevel, 0);
      expect(info.progress, 0);
      expect(info.totalXp, 4200); // floored at the level base
    });

    test('confirmedLevel < 1 clamps to L1', () {
      final info = gatedLevelInfo(confirmedLevel: 0, totalXp: 100);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 100);
    });

    test('candidate vs confirmed: confirmation chains one level at a time', () {
      // 7000 XP nominates L4 (>= 6300); from confirmed L1 each confirmation
      // step still sees the gate passed until the levels catch up.
      expect(levelFromCumulative(7000).level, 4);
      expect(gatedLevelInfo(confirmedLevel: 1, totalXp: 7000).xpGatePassed, isTrue);
      expect(gatedLevelInfo(confirmedLevel: 2, totalXp: 7000).xpGatePassed, isTrue);
      expect(gatedLevelInfo(confirmedLevel: 3, totalXp: 7000).xpGatePassed, isTrue);
      expect(gatedLevelInfo(confirmedLevel: 4, totalXp: 7000).xpGatePassed, isFalse);
    });
  });

  group('21 perfect days narrative', () {
    test('21 × +100 = 2100 = exactly L2', () {
      final total = 21 * dayXpFromScore(100);
      expect(total, 2100);
      expect(levelFromCumulative(total).level, 2);
    });

    test('30 days at score 70 = 2100 = exactly L2', () {
      final total = 30 * dayXpFromScore(70);
      expect(total, 2100);
      expect(levelFromCumulative(total).level, 2);
    });

    test('one bad day at 30 wipes 20 XP from a perfect day stack', () {
      // 21 perfect (+100 × 21 = 2100), then one bad day at 30 (-20)
      final total = 21 * dayXpFromScore(100) + dayXpFromScore(30);
      expect(total, 2080);
      expect(levelFromCumulative(total).level, 1);
      expect(levelFromCumulative(total).xpIntoLevel, 2080);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/features/achievements/achievement_engine.dart';

void main() {
  group('longestConsecutiveRun', () {
    test('empty → 0', () {
      expect(longestConsecutiveRun(const <String>[]), 0);
    });

    test('single day → 1', () {
      expect(longestConsecutiveRun(['2026-06-10']), 1);
    });

    test('fully consecutive run', () {
      expect(
        longestConsecutiveRun([
          '2026-06-10',
          '2026-06-11',
          '2026-06-12',
        ]),
        3,
      );
    });

    test('picks the longest run across a gap', () {
      expect(
        longestConsecutiveRun([
          '2026-06-01', // run of 1
          '2026-06-10', '2026-06-11', '2026-06-12', '2026-06-13', // run of 4
          '2026-06-20', '2026-06-21', // run of 2
        ]),
        4,
      );
    });

    test('duplicates and unsorted input are handled', () {
      expect(
        longestConsecutiveRun([
          '2026-06-12',
          '2026-06-10',
          '2026-06-11',
          '2026-06-11', // duplicate
          '2026-06-12',
        ]),
        3,
      );
    });

    test('month boundary is consecutive', () {
      expect(longestConsecutiveRun(['2026-05-31', '2026-06-01']), 2);
    });
  });

  group('evalAchievement — threshold rules', () {
    test('centurion locks below 100 and clamps its progress', () {
      final p = evalAchievement('centurion', const UserStats(gymSessions: 99));
      expect(p.unlocked, isFalse);
      expect(p.current, 99);
      expect(p.target, 100);
    });

    test('centurion unlocks at 100 and current never exceeds target', () {
      final p = evalAchievement('centurion', const UserStats(gymSessions: 137));
      expect(p.unlocked, isTrue);
      expect(p.current, 100); // clamped to target for the bar
    });

    test('bookworm tracks cumulative pages', () {
      expect(
        evalAchievement('bookworm', const UserStats(pagesRead: 1000)).unlocked,
        isTrue,
      );
      expect(
        evalAchievement('bookworm', const UserStats(pagesRead: 999)).unlocked,
        isFalse,
      );
    });

    test('marathon_mind tracks km', () {
      expect(
        evalAchievement('marathon_mind', const UserStats(kmRun: 200)).unlocked,
        isTrue,
      );
    });

    test('early_bird needs 14 dawn runs', () {
      expect(
        evalAchievement('early_bird', const UserStats(dawnRuns: 14)).unlocked,
        isTrue,
      );
      expect(
        evalAchievement('early_bird', const UserStats(dawnRuns: 13)).unlocked,
        isFalse,
      );
    });

    test('unbroken needs a 30-day critical-adherence streak', () {
      expect(
        evalAchievement('unbroken',
                const UserStats(criticalAdherenceStreak: 30))
            .unlocked,
        isTrue,
      );
    });

    test('veteran needs a 365 active-day streak', () {
      expect(
        evalAchievement('veteran', const UserStats(activeDayStreak: 365))
            .unlocked,
        isTrue,
      );
      expect(
        evalAchievement('veteran', const UserStats(activeDayStreak: 100))
            .current,
        100,
      );
    });

    test('hydromancer + macro_boss streaks', () {
      expect(
        evalAchievement('hydromancer', const UserStats(hydrationStreak: 14))
            .unlocked,
        isTrue,
      );
      expect(
        evalAchievement('macro_boss', const UserStats(proteinStreak: 30))
            .unlocked,
        isTrue,
      );
    });
  });

  group('evalAchievement — boolean rules', () {
    test('phoenix is a one-shot flag', () {
      expect(
        evalAchievement('phoenix', const UserStats(phoenixResume: true))
            .unlocked,
        isTrue,
      );
      final locked = evalAchievement('phoenix', const UserStats());
      expect(locked.unlocked, isFalse);
      expect(locked.current, 0);
      expect(locked.target, 1);
    });

    test('comeback is a one-shot flag', () {
      expect(
        evalAchievement('comeback', const UserStats(comebackHit: true))
            .unlocked,
        isTrue,
      );
      expect(
        evalAchievement('comeback', const UserStats()).unlocked,
        isFalse,
      );
    });
  });

  group('evalAchievement — existing rules still hold', () {
    test('streak_100 needs a 100-day habit streak (lifetime)', () {
      expect(
        evalAchievement('streak_100', const UserStats(longestHabitStreak: 100))
            .unlocked,
        isTrue,
      );
    });

    test('level + architect milestones', () {
      expect(
        evalAchievement('level_5', const UserStats(currentLevel: 5)).unlocked,
        isTrue,
      );
      expect(
        evalAchievement('architect_5', const UserStats(habitCount: 5)).unlocked,
        isTrue,
      );
    });

    test('no rule is left permanently locked at the default', () {
      // Every wired rule should be reachable: feeding a maxed-out stat block
      // unlocks all non-hidden threshold rules we touched in WS1.
      const maxed = UserStats(
        gymSessions: 1000,
        pagesRead: 100000,
        kmRun: 100000,
        kgLifted: 1000000,
        deliveries: 100000,
        dawnRuns: 1000,
        criticalAdherenceStreak: 1000,
        activeDayStreak: 1000,
        phoenixResume: true,
        hydrationStreak: 1000,
        proteinStreak: 1000,
        comebackHit: true,
      );
      for (final id in [
        'early_bird',
        'centurion',
        'bookworm',
        'marathon_mind',
        'iron_lift',
        'bowlers_arm',
        'unbroken',
        'veteran',
        'hydromancer',
        'macro_boss',
        'phoenix',
        'comeback',
      ]) {
        expect(evalAchievement(id, maxed).unlocked, isTrue,
            reason: '$id should unlock when its stat is maxed');
      }
    });
  });
}

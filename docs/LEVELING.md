# Leveling & XP System — v2.1

> **v2.1 (2026-06-11)** made the dual gate real. v2 shipped the score→XP
> pipeline but derived the displayed level purely from XP, which made the
> "can level up" check mathematically unsatisfiable — the overlay never fired
> and milestones gated nothing. v2.1 adds the persisted **confirmed level**
> (`users.confirmed_level`): XP nominates a *candidate*, the transition is
> *confirmed* one step at a time when both gates pass. Key changes:
>
> - `gatedLevelInfo(confirmedLevel, totalXp)` in the engine: the level number
>   is the confirmed level; once awarded it is never lost (XP floors at the
>   level base). Past the XP threshold while milestone-gated, the bar reads
>   full, `xpGatePassed == true`, and the overflow shows as **banked XP**.
> - `LevelUpOverlay` now *confirms* transitions: persists `confirmed_level`
>   (monotonic update), celebrates, writes the notification, pushes the
>   picker. Banked XP spanning several levels chains one celebration at a time.
> - Today's live score XP is clamped at ≥ 0 in the cumulative total — a
>   below-50 day only locks in its negative XP when the snapshot persists
>   after midnight (no more "-50 at 6 am" dips). The Progression delta tile
>   still shows the honest negative number.
> - The snapshot writer never reaches back before the user's first habit log,
>   skips task-less days (a rest day is 0 XP, not -50), repairs intra-day
>   bonus placeholder rows (score 0 / score_xp 0) on the next run, and caches
>   `nutrition_ratio` on every row it writes.
> - The nutrition bonus uses a dedicated `nutrition_bonus_awarded` flag
>   (previously inferred from `bonus_xp > 0`, which an achievement unlock
>   would falsely satisfy) and reads `todayNutritionRatioProvider`, pinned to
>   today regardless of which date the food diary is browsing.
> - `perfect_days` / `nutrition_days` milestone progress derives from
>   `daily_score_snapshots` (+ today live) instead of recomputing 90 days of
>   scores from raw logs.
>
> Migration: `supabase/migrations/20260611_leveling_v2_1.sql` (applied).
> The sections below describe v2 and remain accurate except where superseded
> by the notes above.

## 1. Philosophy

Levels in Atlas represent **earned ground** — chapters of personal change you've actually lived through, not metrics you've farmed. The system is designed so:

- **One perfect day really matters.** A 100-point day moves you forward by a noticeable, named unit (1 % of the way to the next level).
- **Bad days actually set you back.** A day below 50 subtracts XP rather than just slowing your gain. The flow has weight.
- **A level is a chapter, not a number.** Each level has a *theme* (Foundations → Consistency → Depth → Identity → Mastery → Legacy). The user picks **milestones** — concrete things like "5 gym sessions" or "21-day streak on No Phone After 10" — that mark this chapter for them personally.
- **Pre-requisites are interlinked, not manually tracked.** When you pick "5 gym sessions" as a milestone, the count auto-derives from your habit logs. You never edit a counter; you just live your day and the system tallies.

The level number is downstream of behavior. XP can't be bought, gifted, or accelerated — only earned by score.

## 2. The numbers

| Quantity                  | Formula                                                     |
|---------------------------|-------------------------------------------------------------|
| **Perfect day**           | `100 XP` (score 100 → +100)                                 |
| **Average day** (score 70)| `+70 XP`                                                    |
| **Break-even**            | score `50` → `0 XP` contribution                            |
| **Bad day** (score 30)    | `-20 XP` (formula: `score - 50` when score < 50)            |
| **Worst day** (score 0)   | `-50 XP` (floor)                                            |
| **Overshoot**             | up to `+110 XP` (score engine's 10 % stretch bonus)         |
| **One level**             | `2,100 XP` (= 21 perfect days, or ~30 average days)         |
| **Level curve**           | linear: `xpForLevel(L) = 2100 × (L - 1)`                    |

Constants live in `lib/features/xp/leveling_engine.dart`:

```dart
const int kPerfectDayXp     = 100;
const int kXpPerLevel       = 2100;
const int kNegativeDayThreshold = 50;
const int kNegativeDayFloor = -50;
```

The pure engine is fully unit-tested (`test/leveling_engine_test.dart`).

## 3. How XP is earned

### Score-derived XP (the main pipeline)

Every completed day produces one **snapshot** row in `daily_score_snapshots`:

| Column           | Source                                                       |
|------------------|--------------------------------------------------------------|
| `score`          | `homeScoreProvider(date)` — the same number on the home ring |
| `score_xp`       | `dayXpFromScore(score)` — the formula above                  |
| `bonus_xp`       | 0 by default; added by achievement unlocks + nutrition hits  |
| `total_xp_delta` | GENERATED `score_xp + bonus_xp`                              |
| `nutrition_ratio`| optional cache of the day's nutrition adherence (0..1.10)    |

Today's row is **always live** — never written by the snapshot writer. The cumulative XP provider computes today as `dayXpFromScore(currentScore)` and adds it on top of past snapshots. The writer fills missing past dates once per app open (see `DailySnapshotWriter.runOnce`).

### Bonus XP sources

These add to today's snapshot's `bonus_xp` via `DailySnapshotWriter.addTodayBonus`:

- **Achievement unlock** (`achievement_engine.dart`) — `def.xpReward` per unlock
- **Nutrition threshold cross** (`nutrition_xp_listener.dart`) — `+25 XP`, once per day, when daily nutrition ratio first crosses 0.80

Bonus XP intentionally lives on the same row as the day's score so the level math has a single source of truth — there are no parallel XP ledgers to reconcile.

### What about per-task XP?

There's no per-task XP table in v2. The "+8 XP" toast that fires when you complete a habit derives its value from `TaskContribution.contributedPts` returned by the score engine — the same number that drives the day's score. This guarantees the sum of toasts you see during the day equals `dayXpFromScore(finalScore)` at midnight. No drift.

The legacy `xp_events` table is left in place but no longer written to. A future cleanup migration can drop it.

## 4. Level transitions — the dual gate

To advance from Level `L` to Level `L+1`, **both** of the following must be true:

1. **XP gate:** `cumulativeLevelXp >= xpForLevel(L+1)` (i.e., `>= 2100 × L`)
2. **Pre-requisite gate:** every row in `level_prerequisites` with `level = L+1` has its derived `currentProgress >= target` (or there are no pre-req rows at all)

`canLevelUpProvider` is the single boolean expressing both gates. When it flips `false → true`, the level-up overlay fires (haptic + radial burst + card), writes a `notifications` row, and after the burst pushes the **picker** for the next level's pre-reqs.

A user past the XP threshold but with unmet pre-reqs will see the level number on Progression already reflect the XP-derived level, but the celebratory overlay holds back until the milestones land. The pre-req checklist on Progression makes it obvious what's left.

## 5. Pre-requisite kinds

All four kinds derive `currentProgress` from existing data — no manual edits.

| Kind                 | `config`                                  | Derivation                                                        |
|----------------------|-------------------------------------------|-------------------------------------------------------------------|
| `habit_completions`  | `{habitId, targetCount}`                  | `COUNT habit_logs WHERE habit_id = ? AND completed = true`        |
| `streak_days`        | `{habitId, targetDays}`                   | Walks back from today; max consecutive `completed = true` days    |
| `perfect_days`       | `{targetCount, scoreThreshold: 90}`       | `COUNT daily_score_snapshots WHERE score >= scoreThreshold` (+ today live) |
| `nutrition_days`     | `{targetCount, ratioThreshold: 0.80}`     | `COUNT daily_score_snapshots WHERE nutrition_ratio >= ratioThreshold` |

A pre-req is met as soon as `currentProgress >= target`. The user does not need to manually mark anything complete — the next time the Progression screen rebuilds it shows the green check.

## 6. Picker flow

The pre-req picker (`PrereqPickerScreen` at `/level/prereq-picker/:level`) is shown:

1. **After every level-up overlay** — pushed automatically once the celebratory burst dismisses. Sets up the milestones for the next level.
2. **From Progression** — the "Set milestones" CTA on the pre-req checklist card (or the "Add or edit milestones" footer when at least one is already chosen).

The picker offers three one-tap suggestions matching the current level's theme (e.g., for L1→L2: "5 gym sessions", "21-day streak on…", "7 perfect days") plus a "Custom milestone" modal where the user can dial in any of the four kinds with their own targets.

**Skipping is fully supported.** A user with zero pre-reqs simply needs the XP. The Progression screen surfaces the empty state with a "Set milestones" link so they can come back any time.

## 7. Future-level themes

The picker hints at the next-band theme so users feel the journey, not just the number. Implemented this sprint: levels 1–2 (Foundations). The full arc:

| Levels | Theme           | What the milestones lean toward                                  |
|--------|-----------------|------------------------------------------------------------------|
| 1–2    | **Foundations** | Break bad habits, build new ones                                 |
| 3–5    | **Consistency** | Multi-week perfect streaks, 30-day no-break on a negative habit  |
| 6–9    | **Depth**       | Per-skill mastery (10 gym PRs, 100 pages read, etc.)             |
| 10–15  | **Identity**    | 60-day streaks, no slips, deep journaling habit                  |
| 16–25  | **Mastery**     | Per-section mastery quests; cross-skill blends                   |
| 26+    | **Legacy**      | Mentor / share / build (reserved for a future social tier)       |

Picker UX exists in code, and `_suggestionsForLevel` covers **all** bands — the
earlier note that higher-band defaults were deferred is stale (verified 2026-07-07).

## 8. Extending the system

### Adding a new `PrereqKind`

1. Add the enum case in `lib/features/xp/models/level_prereq.dart`, plus its DB string in `prereqKindToDb` / `prereqKindFromDb`.
2. Add a config-accessor on `LevelPrereq` if the new kind needs new typed fields.
3. Add a `case` branch in `_progressFor` inside `lib/features/xp/prereq_providers.dart` to compute its current progress from existing data.
4. Add a label in `describePrereq` (same file) for the picker / progression UI.
5. Add UI affordance in `prereq_picker_screen.dart` — both as a suggestion chip (optional) and in the `_CustomPrereqSheet` dropdown.

That's it. No schema change is required — the `config` jsonb column holds any shape.

### Changing the XP formula

All formula constants are at the top of `leveling_engine.dart`. The rest of the system reads them — change `kXpPerLevel` to 1500 and the entire stack adjusts (UI, picker copy, tests update assumptions).

### Adding a new bonus XP source

Call `DailySnapshotWriter.addTodayBonus(userId, xp)` from wherever the bonus event fires. The bonus lands on today's snapshot and is immediately reflected in `cumulativeLevelXpProvider`.

## 9. Edge cases

- **Negative XP** doesn't take you below Level 1. `levelFromCumulative(-500)` returns `L1, 0 XP`. The cumulative number itself can be negative in storage; the UI clamps display.
- **Midnight rollover**: today's snapshot is recomputed live as the user crosses midnight (the date in `homeScoreProvider(today)` shifts). The writer picks up the now-past day on the next app open.
- **Back-fill of past days**: `DailySnapshotWriter.runOnce` walks back 60 days. Anything older than that needs a one-shot backfill script.
- **Hot reload during partial completion**: per-task feedback derives from `contributedPts`, which the score engine recomputes from the latest log set. No stale "+12 XP" toasts.
- **Multiple devices**: the snapshot table is the source of truth. Two devices logging at once will see each other's contributions after the next refresh. No client-side merging required.
- **Pre-req editing mid-level**: removing a met pre-req does NOT undo the level-up. The check is "all pre-reqs met at the moment of transition." Adding a new pre-req after the user is past the XP gate but before they level up keeps them gated until the new one is met.

## 10. File map

```
lib/features/xp/
  leveling_engine.dart         pure functions: dayXpFromScore, xpForLevel, levelFromCumulative
  leveling_providers.dart      cumulativeLevelXpProvider, currentLevelProvider, todayLevelXpDeltaProvider, DailySnapshotWriter
  prereq_providers.dart        userPrereqsProvider, prereqProgressProvider, canLevelUpProvider, describePrereq
  level_prereq_repository.dart DB CRUD on level_prerequisites
  models/level_prereq.dart     LevelPrereq + PrereqKind + PrereqProgress
  screens/prereq_picker_screen.dart  one-shot setup UI
  level_up_overlay.dart        listens canLevelUpProvider; burst + push picker
  rank_tier.dart               unchanged; level → tier/sub-tier mapping
  (deprecated) xp_engine.dart, xp_provider.dart — left for read-only legacy

lib/features/stats/screens/progression_screen.dart
  rank card + today's delta + pre-req checklist + activity feed + achievements

supabase/migrations/20260609_leveling_v2.sql
  daily_score_snapshots + level_prerequisites tables with RLS

test/leveling_engine_test.dart
  full coverage of dayXpFromScore + xpForLevel + levelFromCumulative
```

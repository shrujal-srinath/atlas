# Tasks/Habits Section — In-Depth Review & Improvement Plan
_2026-07-07 · Fable 5 audit · ~9k LOC across `lib/features/habits/` + the home task
surfaces (`home_day_rail`, `habit_log_modal`, `habit_log_widgets`) + `core/utils`
engines. Companion to FOOD_AUDIT.md; execution = Phase 2 of `fable 5/FUTURE_PLANS.md`._

## 0. Architecture at a glance

Habits have no `data/` repo layer — providers in `habit_provider.dart` query Supabase
directly (`habits`, `habit_logs`), with dev-mode branches merging
`devLogOverridesProvider`. Pure math lives in `core/utils/streak_engine.dart` +
`task_stats.dart` and the score engine. Surfaces: creation (1 screen + 3 part-files),
type picker (full page), library, detail, per-habit stats, focus timer, and the home
day rail + log modal where 95% of daily interaction happens. Cache invalidation is
centralized in `_invalidateLogCaches` — the model to preserve.

**Overall:** interaction design is strong (day rail, log modal, negative-habit flow);
the weak spots are (a) **derived-stats correctness drift** — three different places
compute streak/rate with three different rules, (b) **write-only features** (photo
proof, trigger tags), (c) **no offline path** for the app's highest-frequency write,
and (d) flexible X/week habits being a second-class citizen in every stat.

---

## 1. Full feature inventory

### Creation (`habit_creation_screen.dart` + `_fields`/`_rows`/`_goal_sheet` part-files)
Bento-sectioned form: Identity (name/icon/26-color swatch) · Type&Priority (section
picker from `sectionsProvider` incl. custom sections; 4 priorities) · Schedule
(every-day / X-per-week → exact-days vs flexible-count split, `_RestDayHint`,
time-period + optional exact time; negatives locked to every-day with a "starts
clean" explainer; todos get a due date) · Goal (type/value/unit sheet; skill category
for Mind; replacement-habit picker for negatives) · Tracking toggles (effort, note,
photo proof) · Auto-log food (link editor → FoodSearchSheet in selectMode) ·
Advanced (reminder, end-on, archive). Solid validation (name, 1–7 ×/week, goal
bounds, end-days bounds); date pickers clamp past seeds (no crash on overdue edits).

### Home day rail (`home_day_rail.dart`, 1,696 lines)
The daily surface: period headers (morning/afternoon/evening/night), one **expanded
focus card** (accent) + compact resting rows (neutral), done "receipts" with strike,
rest-day receipts ("Rest day — counts as neutral, your streak is safe"), a pulsing
"now" node, Finish(3):Rest(1) split buttons for flexible habits, negative habits
grouped under **Staying clean** with a slip sheet, an all-clear banner, and
auto-spotlight of the next undone task.

### Log modal (`habit_log_modal.dart`, 1,129 lines)
Per-type logging: binary complete/undo · numeric stepper + preset chips +
`goalUnitLabel` display · countdown-timer CTA for minute-scale duration goals
(correctly gated `goalUnit == null || 'min'`) · photo-proof gate (camera →
`habit_proofs/{habitId}-{date}.jpg`) · effort rating 1–5 · note · breaking-habit
outcomes (stayed clean / urge-only "surfed it" / broke it + trigger tag picker).

### Detail (`habit_detail_screen.dart`) & per-habit stats (`habit_stats_screen.dart`)
Detail: header card, Current/Best/30d-rate tiles, 7-day heatmap, "habit health"
composite (50% rate + 30% streak/best + 20% trend), schedule/reminder/food-link
summary cards, edit/archive/hard-delete. Stats: W/M/Y ranges via pure
`computeTaskStats` + `StreakCalendar`, performance & effort charts.

### Library (`habit_library_screen.dart`)
Sections-grouped, drag-to-reorder (concurrent sort_order writes), archived
collapsible group, pencil-edit, `showHabitTypePicker` full-page entry.

### Focus timer (`habit_focus_screen.dart`)
Countdown from `goalValue` minutes; early stop logs the elapsed fraction as
`actualValue` (partial credit flows into the score engine). Route:
`/habit/:id/focus`.

### Engine & data
`taskRatio` (score), `calculateStreak` (rest-aware), `computeTaskStats` (pure,
tested), food-link auto-log/un-log via `_syncFoodLink`, reminders reconciled
centrally by `ReminderScheduler` (`reminderDaysFor` falls back to the habit's own
schedule).

---

## 2. Dead / removable code

| Item | Where | Action |
|---|---|---|
| `habitsForDate(all, date)` | `habit_provider.dart:474` — ignores `frequencyMode` (treats every-day/flexible habits by `daysOfWeek` only, which happens to work only because those store all-7) and duplicates `_appliesOn` | Only consumer is the legacy `analytics_provider.dart` roll-up. Migrate analytics to `_appliesOn`-style logic (export it from home_providers) and delete `habitsForDate` + its test, or fold the test into an `_appliesOn` test. |
| `analytics_provider.dart` | `features/analytics/` — pre-Stats-dashboard section-trend provider | Verify remaining consumers; the Stats dashboard superseded it. Delete the feature dir if orphaned. |
| Legacy color keys `'building'`/`'breaking'` | `habit_creation_screen.dart:137-141` `_colorForSection` | Works (swatch still has those keys) but perpetuates retired names. Rename swatch keys to `mind`/`body` with a fromDb alias. Cosmetic. |

---

## 3. Bugs & correctness drift (the meat — fix before UX work)

### 3.1 🔴 Detail screen computes "BEST" streak / 30d rate / health from a 60-day window
`habit_detail_screen.dart:70-146` walks back **365 days** for best-streak but feeds it
`recentHabitLogsProvider` — a **60-day** query. Any streak or completion older than
60 days is invisible: "BEST" is silently wrong for long-lived habits, and the health
composite inherits the error. The per-habit stats screen already uses the right
source (`habitLogHistoryProvider`, 366 days). **Fix:** switch the detail screen to
`habitLogHistoryProvider(habit.id)` — or better, delete the inline math and call
`computeTaskStats` (§3.3 makes them agree first).

### 3.2 🔴 Rest days are counted as failures in every derived stat except the streak
`computeTaskStats` (`task_stats.dart:100-143`) builds `doneDates` from
`completed` only and never reads `l.restDay`:
- completion rate: a rested day counts as scheduled-but-missed → drags the rate;
- best-streak loop: a rest **resets the run** — while `calculateStreak` (the
  current-streak number on the *same screen*) skips rests. Current can exceed best.
- weekday split and trend buckets inherit the same error.
The detail screen's inline math (§3.1) has the identical blindness.
**Fix:** thread rest-awareness through `computeTaskStats`: a rest day is *not
scheduled* for rate/streak purposes (mirror `calculateStreak`'s skip). Extend
`test/task_stats_test.dart` with rest fixtures FIRST.

### 3.3 🟠 Flexible X/week habits: every denominator is "all 7 days"
`scheduledOn` uses `daysOfWeek.contains` and flexible habits store all-7, so a
perfectly-executed 3×/week habit reads a ~43% completion rate, red weekday cells,
and misleading trend bars. **Fix (design):** for `FrequencyMode.timesPerWeek`,
compute weekly buckets as `min(completedInWeek / timesPerWeek, 1)` and make the
headline rate the average of weekly attainment; weekday split becomes descriptive
("your gym days") rather than a rate. Same treatment in the detail screen tiles.

### 3.4 🟠 Goal-unit display drift: `goalValue` is stored in the *chosen unit*, but two consumers assume minutes/base
Since the goal-unit feature (2026-06-30), the value is saved as typed
(`habit_creation_screen.dart:224-229` — "8" with unit `hr`), and scoring is
unit-agnostic (actualValue captured in the same unit). But:
- `habit_detail_screen.dart:457-463` `_goalUnit()` ignores `habit.goalUnit` → an
  8-hr sleep goal renders "8 min". Use `goalUnitLabel(type, unit)` (models.dart).
- `habit_focus_screen.dart:51` seeds the countdown with `goalValue` **as minutes**.
  The log modal correctly refuses the timer for `hr` goals, but the route
  `/habit/:id/focus` is directly reachable → a 2-hr habit gets a 2-minute timer
  that then logs `actualValue = 2` *(minutes-fraction semantics)* against an
  hr-unit goal — corrupting the ratio. **Fix:** in `_bootstrap`, convert via
  `goalToCanonical`/`goalFromCanonical`, or pop with a message for non-min units.
- `models.dart:296-300` doc comment still claims canonical-base storage — rewrite
  it to describe as-typed storage (it's the reference future sessions read).

### 3.5 🟠 Photo proof is write-only
Photos gate completion and land at `habit_proofs/{habitId}-{date}.jpg`
(`habit_log_modal.dart:229-255`) but **nothing ever reads them back** — no
thumbnail on the done receipt, log modal, detail, or stats; lost on uninstall;
no cleanup when logs/habits are deleted. Either ship the read path (proof
thumbnail on the receipt + a small gallery on habit stats; delete file on
hard-delete) or drop the toggle from creation until it earns its place.

### 3.6 🟡 Trigger tags are collected but never surfaced
The slip sheet stores `trigger_tag`, but no analytics reads it (zero references in
`features/stats/`). The staying-clean story ("what triggers me") is half-built.
**Fix:** add a triggers breakdown to the habit-stats screen for negative habits
(count by tag over range) and/or the Stats staying-clean section.

### 3.7 🟡 `toggleHabit` / `setRestDay` bypass the offline queue (highest-frequency write in the app)
`habit_provider.dart:305-429` reads-then-writes Supabase directly; offline, the
select throws and the completion is **lost** (the Hive `habit_logs_cache` box
exists but nothing reads or writes it). Food writes already route through
`OfflineWriter`. **Fix (design, checkpointed):**
1. Write-through: on toggle, upsert the log into `habit_logs_cache` first, then
   `OfflineWriter.insert/update` (client-generated log UUID for idempotent
   retries; the read-then-write pair becomes a deterministic upsert keyed
   `habit_id+date` — add a DB unique index in a migration to make server upserts
   safe).
2. Read-through: `habitLogsForDateProvider`/`recentHabitLogsProvider` fall back to
   the cache when the network read fails, and merge pending queue ops.
3. Drain hook: `SyncQueue` gains an `onDrained` → run `_invalidateLogCaches`.
4. `_syncFoodLink` already tolerates failure — verify it queues via the food repo.

### 3.8 ⚪ Minor
- `_toast` in creation uses raw `ScaffoldMessenger` + `surfaceElevated` background
  instead of shared `showSnack`/`showErrorSnack` (P2-9 class).
- Reminders for flexible habits fire all 7 days (`reminder_days = daysToSave`) —
  arguably right (nudge until weekly target met), but consider suppressing after
  the weekly count is hit (needs the §4.1 weekly counter anyway).
- Detail screen shows `habit.reminderTime` as raw 24h "HH:mm" while creation shows
  localized `format(context)`.
- Library reorder fires N concurrent updates with no optimistic reorder — the list
  snaps back if one fails; wrap in optimistic local order + single failure toast.

---

## 4. UX gaps & house-rule check

### 4.1 Flexible habits have no visible weekly progress
Nothing on the day rail, log modal, detail, or library says **"2 of 4 this week"**
(`timesPerWeek` renders only as a schedule label). The rest-day budget shipped, but
the core feedback loop of a flexible habit — am I on pace this week? — is absent.
**Fix:** a `weeklyCountProvider(habitId)` derived from `recentHabitLogsProvider`;
show `N / target · this week` on the expanded rail card + log modal header + detail
tile, and gently amber the card when `remaining == daysLeftInWeek` (can't skip any
more days — same derivation the milestone nudge needs).

### 4.2 Slip cost is invisible until it lands
A negative-habit slip contributes **−1.0** (below zero — it actively subtracts) but
the slip sheet doesn't preview the score impact. One line — "this will cost ~N pts
today" from `TaskContribution.potentialPts` — makes the mechanic legible and fair.

### 4.3 Day-rail ordering ignores priority
Sorting is period → time (`homeTasksProvider`); a `critical` habit sits wherever its
time falls, and nothing on the card shows priority at all. Given priority multiplies
score weight, at minimum surface a subtle glyph on high/critical cards; consider
priority as a tie-break within a period.

### 4.4 Detail vs stats screens overlap and disagree
Two stat surfaces (detail tiles + full stats) computed by different code (§3.1/§3.2).
After unifying on `computeTaskStats`, make Detail = identity/schedule/actions +
*headline* stats, Stats = the deep dive, and remove the duplicated "health"
composite or move it into the engine with tests.

### 4.5 House-rule sweep (rules in `fable 5/CLAUDE.md` §14)
Largely compliant — AtlasButton/AtlasSwitch/label-above fields throughout creation;
no tint washes behind text found on the rail. Items: the `_TypePill`
(accent-on-accent-tint, borderline rule 1 — low-frequency, acceptable); creation
`_toast` (§3.8); detail-screen action dialogs are Material `AlertDialog`s — fine
per "quick single action", but style-check the button order (destructive right,
colored). PressableScale coverage on library rows + detail cards is missing
(P3-1 class).

---

## 5. Linking opportunities (features that should talk)

1. **Weekly counter ↔ milestone nudges** — §4.1's derivation is the same one
   milestone "can't-skip-anymore" notifications (FUTURE_PLANS P2-6) need; build it
   once in `core/utils` (pure + tested), consume from both.
2. **Trigger tags → journal** — a slip with a trigger could offer "write about it"
   (prefilled journal entry), closing the breaking-habit reflection loop.
3. **Effort ratings → wellness** — effort series exists per-habit; the Stats
   wellness section could correlate high-effort days with next-day score (data
   already fetched).
4. **Replacement habit** — `replacementHabitId` is stored and shown nowhere after
   creation. On a slip, surface "do <replacement> instead" as the recovery action.
5. **Focus timer ↔ focus_sessions table** — the timer doesn't write
   `focus_sessions`; the quick-log Focus feature does. Unify so timed habit work
   appears in any future focus history.

---

## 6. To-do promotion (decision executed here)

Current `/todo` list is Hive-only (`me/data/todo_repository.dart`): no sync, no
reminders, invisible to score. **Recommendation:** promote to Supabase as
lightweight `todo`-type habits *under the hood is NOT the move* — the existing
`HabitType.todo` is a scheduled, scored task and conflates semantics. Instead:
a `todos` table (id, user_id, date, text, time, done, sort_order; RLS owner-scoped),
`OfflineWriter` from day one, optional per-item reminder via `ReminderScheduler`,
and an *opt-in* "counts toward Mind" toggle that materializes a real `todo`-type
habit only when enabled. Keeps the zero-friction list fast while giving power users
score integration. Migration: one-shot Hive → Supabase import on first launch.

---

## 7. Proposed plan (phased, checkpointed — each ends analyze-0/tests-green/commit)

**Phase A — Correctness (do first, it's all engine + tests)**
1. Rest-aware + flexible-aware `computeTaskStats` (§3.2, §3.3) — fixtures first.
2. Detail screen → `habitLogHistoryProvider` + `computeTaskStats` (§3.1, §4.4).
3. Goal-unit fixes: detail label, focus-screen guard/convert, models.dart doc (§3.4).
4. Weekly-count engine util + tests (§4.1 foundation).

**Phase B — Offline habit writes (§3.7)** — the 4-step design above; add
`sync_queue_test.dart`; verify by airplane-mode drive of toggle → relaunch → drain.

**Phase C — UX lift**
5. Weekly progress surfaced (rail card, modal, detail) + can't-skip amber state.
6. Slip cost preview (§4.2); replacement-habit surfacing (§5.4).
7. Photo proof read path OR removal (§3.5 decision); trigger-tag breakdown (§3.6).
8. Priority glyph + ordering tie-break (§4.3); polish items (§3.8, PressableScale).

**Phase D — To-do promotion (§6)** + dead-code removal (§2).

---

## 8. What's already healthy (leave alone)
The day rail's interaction model (focus card + receipts + staying-clean group);
the log modal's per-type flows and the min-only timer gate; creation validation +
date-picker clamps; central reminder reconcile; `_invalidateLogCaches`; the
negative-habit clean-by-default scoring; `calculateStreak`'s rest handling (it's
the reference implementation the others should match); dev-mode log overrides.

# Food Section — In-Depth Review & Improvement Plan
_2026-06-28 · ~17.8k LOC across ~50 files under `lib/features/food/`_

## 0. Architecture at a glance
`FoodShell` = 3 sub-tabs (**Diary / Body / Insights**), sub-tab persisted via `foodSubTabProvider`, deep-linkable from Home.
Layering is clean: `domain/` (pure models + math) → `data/` (repos) → `providers/` (Riverpod graph) → `screens/` + `widgets/`. The provider graph is well-documented and single-sourced. Most of the section is in good shape; findings below are targeted, not a rewrite.

---

## 1. Full feature inventory

### DIARY (logging surface)
- **Fuel card** (`DiaryNutritionSummary`): phase pill, food-quality score chip, settings gear, collapse; calorie ring + budget delta + 4 macro bars (P/C/F/Fiber) + "view micros"; integrated **water** control (bar, −/+250 ml); **Log food** + **Quick add** actions.
- **Date strip** (browse any day) + **Streak strip** (→ fuel calendar).
- **6 meal sections** (Breakfast/Pre/Lunch/Snack/Post/Dinner): per-slot tint+icon, `X of Y Cal` + per-meal P/C/F goal, per-meal quality chip, swipe-to-delete rows, macro chips, task-logged badge; empty-state prompt + **quick-log chips** (last-3 relog); footer **add / load saved meal / save-as-meal**; long-press **copy meal** to another day.
- **Add-food entry graph**: Log food → `MealPickerSheet` (pick slot) → `FoodSearchSheet`; per-meal `+` → `FoodSearchSheet` directly. Search has Recents/Search/Favorites tabs + branded (Open Food Facts) results, and links out to **Saved meals**, **Recipe builder**, **Barcode scanner** → `FoodDetailScreen` (serving/measure picker, also a "select" mode that returns a portion to the task food-link editor).
- **Quick add** (`QuickAddSheet`): raw kcal + optional macros.
- **Edit entry** (`EditEntrySheet`): re-portion + move slot.
- **Micros sheet**: 19 micronutrients, %RDA bars, upper-bound flags.

### BODY (weight surface)
- Current-weight card (falls back to profile weight), delta tiles, **weight chart**, **measurements** card, **Log weight** sheet (asks to update targets → engine recompute).

### INSIGHTS (nutrition analytics, 7/30/90-day)
- Adherence ring, calorie columns, calorie trend, macro donut, **slot heatmap**, **micro flags**, **key takeaways**, protein card.

### GOALS (recently rebuilt — see `goal_setting_flow.md`)
- `GoalSettingsHub` (Weight / Nutrition / Water) → `GoalSetupFlow` (wheel → pace → reveal), `GoalSettingScreen` (nutrition), `WaterGoalEditor`; `HowWeCalculateScreen` (cited methodology).

### ENGINE / SCORING / DATA
- `NutritionEngine` (BMR→TDEE→targets, correlated macros/micros/water).
- **Two scoring systems** (see §3.1).
- Repos: `FoodRepository` (search/log/water/copy/habit-link/relog), `off_client` (OpenFoodFacts), recipe/bundle/weight repos.
- **Task integration**: completing a linked habit auto-logs its food (`loggedVia='habit'`, task badge in the diary).

---

## 2. Dead / removable code
| Item | File | Action |
|---|---|---|
| `HeroNutritionCard`, `HeroVariant`, `_FullBudget`, `_CompactBudget`, `_MacroRow` (~350 LOC) — **unused** since the diary-card merge | `widgets/hero_nutrition_card.dart` | Delete the widget; **relocate** the still-live helpers (`PhasePill`, `phaseDelta`, `phaseHint`, `DeltaTone`, `resolveDeltaColor`) to a small `widgets/phase_ui.dart`, repoint `diary_nutrition_summary` import. |

_(False alarms checked & cleared: `weekly_totals_provider` exports `rangeTotalsProvider`/`insightsRangeProvider` (used by Insights); `recipe_providers` exports `userRecipesProvider` (used). Not dead.)_

---

## 3. Redundancy / conflicts / inconsistencies

### 3.1 ⚠️ Two parallel "food scores" (biggest conceptual issue)
- `scoring/nutrition_score.dart` → **adherence** ratio (phase-aware, 60% cal / 40% protein, `[0,cap]`) → drives the **Home score + XP**.
- `domain/health_score.dart` → **quality** 0–100 (EXCELLENT / WELL FUELED) → drives the **diary header chip + per-meal chips**.
They measure different things and **can disagree** (hit calorie target on junk → high adherence, low quality). The user sees "WELL FUELED 82" with no stated link to their ATLAS score. **Not a bug, but a confusing dual signal.** → Decide: unify into one explained "Fuel score", or keep both but **label/differentiate** them clearly (e.g. chip = "food quality", and surface adherence separately).

### 3.2 ⚠️ Color system is overloaded / inconsistent
- **Water** = `athletic` (orange) in the diary, but `mind` (blue) in the new goal hub/reveal. Pick one (blue/`mind` is the intuitive default).
- **Protein** = `athletic` (orange) **and** water = `athletic` → same color, two meanings.
- **Fat** = `mind` (blue) in diary/meal rows, but I used `body` (purple) in the new `CalorieReveal` → must align.
→ Define canonical food colors **once** (e.g. `FoodColors`: protein/carbs/fat/fiber/water/calories) and use everywhere. Proposed: P=`athletic`, C=`amber`, F=`indigo`/`body`, Fiber=`positive`, Water=`mind`.

### 3.3 "Goals" entry points diverge
- Diary settings gear → `GoalSettingScreen` (nutrition only).
- About-me → `GoalSettingsHub` (Weight/Nutrition/Water).
→ Converge: diary gear should open the **hub** (or a quick sheet that routes to it), so "goal settings" is one consistent destination.

### 3.4 Naming collision
- `features/food/screens/quick_add_sheet.dart` (raw-kcal entry) vs `features/home/widgets/quick_add_sheet.dart` (4-tile Home launcher). Different things, confusing name → rename the Home one (e.g. `home_actions_sheet.dart`).

### 3.5 Minor
- `meal_calorie_targets` blob supports a **legacy** `{slot: kcal}` shape alongside the rich `{on,name,kcal}` — fine as a migration shim, but document/retire eventually.
- `DailyTargets.fromProfile` + `athleteMicroRDA` are legacy fallbacks now the engine drives everything — keep as safety net, but they're the only non-engine target path left.

---

## 4. Linking / UX opportunities (features that should talk to each other)
1. **Insights → action**: "low protein" / micro-flag takeaways should deep-link (tap → open the relevant log/goal), turning analytics into next steps.
2. **Body weight ↔ goal**: logging weight already offers "update targets" — extend so a sustained plateau/overshoot nudges "revisit your pace" (→ `GoalSetupFlow`).
3. **Diary → Insights**: the quality chip / streak could tap through to the matching Insights card for "why".
4. **Saved meals / Recipes / Barcode** are buried inside the search sheet — consider surfacing **Saved meals** and **Recipes** as first-class shortcuts on the diary (one-tap re-log of common meals is the highest-frequency action).
5. **Meal schedule ↔ reminders ↔ diary**: meal times come from notification prefs; ensure editing a meal's time in one place is obviously reflected in the other (single-source already exists — make it visible).
6. **Per-meal macro goals** exist in data but only show kcal prominently — surface the P/C/F-vs-goal at the meal level more clearly (progress, not just a number).

---

## 5. Proposed plan (phased, in priority order)

**Phase 1 — Cleanup & consistency (low-risk, high-clarity)**
1. Delete dead `HeroNutritionCard`; extract phase helpers → `phase_ui.dart`.
2. Introduce a single **`FoodColors`** source of truth; migrate diary, meal rows, reveal, goal widgets, insights to it (fixes 3.2).
3. Converge the "goal settings" entry point (diary gear → hub) (3.3).
4. Rename the Home `quick_add_sheet` (3.4).

**Phase 2 — Resolve the dual-score (3.1)**
5. Decide unify-vs-differentiate; if differentiate: rename the diary chip to "Food quality", add a one-line tooltip explaining it's separate from the ATLAS adherence score, and (optionally) show today's adherence in the fuel card too.

**Phase 3 — Linking & surfacing (UX lift)**
6. Make Insights takeaways + micro-flags tappable → actions.
7. Surface Saved meals / Recipes as diary shortcuts for fast re-logging.
8. Strengthen per-meal macro progress; Body↔goal nudges.

**Phase 4 — Polish**
9. Insights empty-states, motion consistency, and a pass aligning every food surface to the house design rules.

---

## 6. What's already healthy (leave alone)
Provider graph + single-sourcing; domain math (largest-remainder meal split, correlated engine); food search ranking (frequents-pinned + branded async); task→food auto-log; water single-entry-point actions; dev-mode mock reads. These are well-built — the work above is refinement, not rework.

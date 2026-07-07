-- Habit goal unit
-- Adds a display unit for a habit's daily goal so durations can be tracked in
-- hours (e.g. sleep) as well as minutes, distance in km or mi, volume in L or
-- ml, and custom goals can carry a free-text unit label.
--
-- The numeric goal_value is stored in whatever unit the user picked; scoring is
-- ratio-based (actual / target) so it stays unit-agnostic. goal_unit only
-- drives display + input. NULL on existing rows → the type's legacy default
-- (min / km / L), which is exactly what those values already meant.
--
-- Safe to run more than once.

ALTER TABLE habits
  ADD COLUMN IF NOT EXISTS goal_unit text;

-- Adds partial-progress tracking to habit_logs.
-- A numeric goal habit (e.g. "20 reps", "30 min", "3.5 L") can now record the
-- value the user actually hit, so the scoring engine can award proportional
-- credit (12 of 20 reps → 60%) instead of binary done/not-done.
-- NULL is the legacy/binary case — those logs still resolve to ratio 1.0 when
-- `completed = true`.

ALTER TABLE habit_logs
  ADD COLUMN IF NOT EXISTS actual_value numeric;

COMMENT ON COLUMN habit_logs.actual_value IS
  'Recorded numeric progress (reps/min/km/L). NULL for binary habits or legacy logs.';

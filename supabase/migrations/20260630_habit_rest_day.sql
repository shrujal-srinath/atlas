-- Habit rest days (flexible "X / week" habits)
-- Marks a date as a deliberate rest for a flexible-count habit: a neutral skip
-- that is excluded from the day score, never breaks a streak, and earns no XP
-- (mirrors a non-scheduled day). Distinct from a plain incomplete day.
--
-- Safe to run more than once.

ALTER TABLE habit_logs
  ADD COLUMN IF NOT EXISTS rest_day boolean NOT NULL DEFAULT false;

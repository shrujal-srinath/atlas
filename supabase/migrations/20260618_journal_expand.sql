-- Journal v2 — richer daily entry.
-- Adds morning goals (top-3), structured evening reflection (wins / to-improve /
-- gratitude) and a 1–5 day rating to the existing one-row-per-day journal.
--
-- Safe to run more than once.

ALTER TABLE daily_journal
  ADD COLUMN IF NOT EXISTS goals jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS wins text,
  ADD COLUMN IF NOT EXISTS improve text,
  ADD COLUMN IF NOT EXISTS gratitude text,
  ADD COLUMN IF NOT EXISTS day_rating int;

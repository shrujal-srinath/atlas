-- SR-6 (SHIP_READINESS.md): toggleHabit / setRestDay do a select-then-
-- insert-or-update against habit_logs, which is not atomic — two rapid taps
-- (double-tap, or two devices) can both see "no existing row" and both
-- insert, leaving two log rows for the same habit+date. All score/streak
-- readers use `.any()` semantics so a duplicate is invisible until an
-- un-complete only clears one of the two rows and the habit reads "done"
-- forever.
--
-- This migration (a) dedupes any duplicate rows that already exist, keeping
-- the most-recently-touched one per (habit_id, date), then (b) adds a unique
-- constraint so the client's upsert(onConflict: 'habit_id,date') (see
-- habit_provider.dart toggleHabit/setRestDay) can never create a duplicate
-- again, regardless of how many concurrent callers race the write.
--
-- NOTE before applying: this assumes `habit_logs.created_at` exists (every
-- other user-log table in this schema has it). Run `\d habit_logs` first —
-- if it's missing, swap the ORDER BY below for `ctid DESC` instead.

BEGIN;

-- (a) Dedupe: keep the newest row per (habit_id, date), drop the rest.
WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY habit_id, date
      ORDER BY created_at DESC NULLS LAST, id DESC
    ) AS rn
  FROM habit_logs
)
DELETE FROM habit_logs
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- (b) Enforce going forward.
ALTER TABLE habit_logs
  ADD CONSTRAINT habit_logs_habit_id_date_key UNIQUE (habit_id, date);

COMMIT;

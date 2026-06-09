-- Sprint A — Habit creation v2
-- Adds: per-habit color, frequency mode, reminder fields, end conditions,
-- photo proof toggle, due date for one-time todos, and a 'todo' habit type.
--
-- Safe to run more than once.

-- 1. Extend habit_type enum with 'todo'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_enum e ON t.oid = e.enumtypid
    WHERE t.typname = 'habit_type' AND e.enumlabel = 'todo'
  ) THEN
    ALTER TYPE habit_type ADD VALUE 'todo';
  END IF;
END$$;

-- 2. Add new columns to habits
ALTER TABLE habits
  ADD COLUMN IF NOT EXISTS color_key text,
  ADD COLUMN IF NOT EXISTS frequency_mode text DEFAULT 'specific_days'
    CHECK (frequency_mode IN ('specific_days', 'times_per_week', 'every_day')),
  ADD COLUMN IF NOT EXISTS times_per_week int CHECK (times_per_week BETWEEN 1 AND 7),
  ADD COLUMN IF NOT EXISTS reminder_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS reminder_time text, -- HH:mm
  ADD COLUMN IF NOT EXISTS reminder_days int[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS end_mode text DEFAULT 'off'
    CHECK (end_mode IN ('off', 'date', 'after_days')),
  ADD COLUMN IF NOT EXISTS end_date date,
  ADD COLUMN IF NOT EXISTS end_after_days int CHECK (end_after_days > 0),
  ADD COLUMN IF NOT EXISTS photo_proof_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS due_date date, -- for one-time todos
  ADD COLUMN IF NOT EXISTS sort_order int DEFAULT 0;

-- 3. Index for ordering within a user's list
CREATE INDEX IF NOT EXISTS habits_user_sort_idx
  ON habits (user_id, sort_order);

-- Sprint D — Settings rebuild
-- Adds body metrics, full macro targets, water target, and notification
-- preferences. Existing rows keep defaults; the app treats every column as
-- optional so older clients continue to read cleanly.
--
-- Safe to run more than once.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS height_cm numeric,
  ADD COLUMN IF NOT EXISTS weight_kg numeric,
  ADD COLUMN IF NOT EXISTS age int,
  ADD COLUMN IF NOT EXISTS gender text CHECK (gender IN ('male','female','other')),
  ADD COLUMN IF NOT EXISTS activity_level text
    CHECK (activity_level IN ('sedentary','light','active','very_active','athlete')),

  -- Macro targets
  ADD COLUMN IF NOT EXISTS daily_carbs_target int,
  ADD COLUMN IF NOT EXISTS daily_fat_target int,
  ADD COLUMN IF NOT EXISTS daily_fiber_target int,
  ADD COLUMN IF NOT EXISTS water_target_ml int DEFAULT 3500,

  -- Notification preferences
  ADD COLUMN IF NOT EXISTS notifications_enabled boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS quiet_hours_start text, -- HH:mm
  ADD COLUMN IF NOT EXISTS quiet_hours_end text,   -- HH:mm
  ADD COLUMN IF NOT EXISTS default_reminder_time text DEFAULT '08:00';

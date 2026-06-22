-- Task → Food auto-log ("linked tracking")
-- Lets a habit/todo carry a saved food link (slot + item snapshots). Completing
-- the task auto-logs those items into food_logs; un-completing removes them.
--
-- Safe to run more than once.

-- 1. The link itself lives as a snapshot on the habit row.
--    Shape: { "slot": "breakfast",
--             "items": [ { "food_id": uuid|null, "name", "qty", "unit",
--                          "calories", "protein", "carbs", "fat", "micros": {} } ] }
ALTER TABLE habits
  ADD COLUMN IF NOT EXISTS food_link jsonb;

-- 2. Tag auto-logged food rows so they can be found + removed on un-complete.
--    ON DELETE SET NULL: deleting a habit detaches the link but keeps the
--    already-logged entries (real consumed calories).
ALTER TABLE food_logs
  ADD COLUMN IF NOT EXISTS source_habit_id uuid REFERENCES habits(id) ON DELETE SET NULL;

-- 3. Fast lookup for "this habit's auto-logs on this date".
CREATE INDEX IF NOT EXISTS food_logs_source_habit_idx
  ON food_logs (source_habit_id, date);

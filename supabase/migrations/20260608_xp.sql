-- Sprint F — XP + Levels
-- Append-only ledger of every XP gain. Aggregations happen client-side so
-- the formula can evolve without backfills.
--
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS xp_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  habit_id uuid REFERENCES habits(id) ON DELETE CASCADE,
  skill text,         -- skill_category from habits, falls back to section
  xp int NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS xp_events_user_idx
  ON xp_events (user_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS xp_events_skill_idx
  ON xp_events (user_id, skill);

ALTER TABLE xp_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS xp_events_owner_all ON xp_events;
CREATE POLICY xp_events_owner_all
  ON xp_events
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

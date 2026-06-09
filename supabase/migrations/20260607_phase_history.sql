-- Sprint E — Phase + Score v2
-- Persists every phase change for a user with the weights that were active
-- during that window. The currently-open row (ended_at IS NULL) defines the
-- score weights right now.
--
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS phase_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phase_name text NOT NULL,
  weights jsonb NOT NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz
);

CREATE INDEX IF NOT EXISTS phase_history_user_idx
  ON phase_history (user_id, started_at DESC);

-- Enforce only one open phase row per user.
CREATE UNIQUE INDEX IF NOT EXISTS phase_history_open_uniq
  ON phase_history (user_id) WHERE ended_at IS NULL;

ALTER TABLE phase_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS phase_history_owner_all ON phase_history;
CREATE POLICY phase_history_owner_all
  ON phase_history
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

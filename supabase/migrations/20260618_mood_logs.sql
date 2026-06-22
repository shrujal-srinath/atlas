-- Intraday mood timeseries.
-- The home check-in re-prompts every ~2h to track mood through the day; each
-- answer is its own timestamped row here (daily_journal keeps the day's latest
-- value as the summary used by the 30-day wellness trend).
--
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS mood_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  logged_at timestamptz NOT NULL DEFAULT now(),
  mood int,    -- nullable: energy-only check-ins come from the notification picker
  energy int,
  note text
);

-- Reconcile any pre-existing mood_logs table that predates this shape
-- (older builds created it with `date`/`created_at` and `mood NOT NULL`).
ALTER TABLE mood_logs ADD COLUMN IF NOT EXISTS logged_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE mood_logs ALTER COLUMN mood DROP NOT NULL;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'mood_logs' AND column_name = 'created_at'
  ) THEN
    EXECUTE 'UPDATE mood_logs SET logged_at = created_at WHERE logged_at IS NULL';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS mood_logs_user_idx
  ON mood_logs (user_id, logged_at DESC);

ALTER TABLE mood_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mood_logs_owner_all ON mood_logs;
CREATE POLICY mood_logs_owner_all
  ON mood_logs
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

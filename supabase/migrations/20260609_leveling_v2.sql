-- Leveling system v2 — score-driven XP + user pre-requisite gating.
--
-- daily_score_snapshots is the source of truth for cumulative level XP.
-- Each row holds one day's final score, the score-derived XP, and any bonus
-- XP awarded that day (achievement unlocks, nutrition threshold cross, etc.).
--
-- level_prerequisites holds the user's customizable milestones that must
-- ALL be met for a level transition to fire (in addition to the XP gate).

CREATE TABLE IF NOT EXISTS daily_score_snapshots (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date            date NOT NULL,
  score           int  NOT NULL,                                  -- 0..110 (overshoot cap)
  score_xp        int  NOT NULL,                                  -- dayXpFromScore(score), -50..110
  bonus_xp        int  NOT NULL DEFAULT 0,                        -- achievements + nutrition + one-offs
  total_xp_delta  int  GENERATED ALWAYS AS (score_xp + bonus_xp) STORED,
  nutrition_ratio numeric,                                        -- nullable; for "nutrition_days" pre-reqs
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_score_snapshots_user_date
  ON daily_score_snapshots (user_id, date DESC);

CREATE TABLE IF NOT EXISTS level_prerequisites (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  level         int  NOT NULL,
    -- target level (e.g., 2 = "pre-reqs to reach L2 from L1")
  kind          text NOT NULL,
    -- 'habit_completions' | 'streak_days' | 'perfect_days' | 'nutrition_days'
  config        jsonb NOT NULL DEFAULT '{}'::jsonb,
    -- shape depends on kind:
    --   habit_completions: {habitId, targetCount}
    --   streak_days:       {habitId, targetDays}
    --   perfect_days:      {targetCount, scoreThreshold}
    --   nutrition_days:    {targetCount, ratioThreshold}
  completed_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_level_prereqs_user_level
  ON level_prerequisites (user_id, level);

-- RLS: owner-only on both tables.
ALTER TABLE daily_score_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE level_prerequisites    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "snapshots_owner_all" ON daily_score_snapshots;
DROP POLICY IF EXISTS "prereqs_owner_all"   ON level_prerequisites;

CREATE POLICY "snapshots_owner_all" ON daily_score_snapshots
  FOR ALL TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "prereqs_owner_all" ON level_prerequisites
  FOR ALL TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

COMMENT ON TABLE daily_score_snapshots IS
  'One row per user per day. Source of truth for cumulative level XP. See docs/LEVELING.md.';
COMMENT ON TABLE level_prerequisites IS
  'User-defined milestones that gate a level transition. See docs/LEVELING.md.';

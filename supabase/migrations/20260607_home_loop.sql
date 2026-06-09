-- Sprint 0 — Home master-plan closed loop.
-- 1. habits.priority (low/normal/high/critical) — drives XP, score weight, streak bonus.
-- 2. users.section_weights jsonb — user-defined Ath/Mind/Body weights (defaults 40/30/30).
-- 3. xp_events.source + metadata — source taxonomy for the "Earned today" ledger.
-- 4. user_achievements — append-only unlock log, one row per (user, achievement).
-- 5. daily_logins — one row per (user, date) so the daily-login XP is idempotent.
-- 6. notifications — in-app inbox surfaced from the bell icon.
--
-- Safe to run more than once.

-- 1. PRIORITY ───────────────────────────────────────────────────────────
ALTER TABLE habits
  ADD COLUMN IF NOT EXISTS priority text DEFAULT 'normal';

DO $$
BEGIN
  ALTER TABLE habits
    ADD CONSTRAINT habits_priority_check
    CHECK (priority IN ('low','normal','high','critical'));
EXCEPTION WHEN duplicate_object THEN
  -- constraint already exists
  NULL;
END $$;

-- 2. SECTION WEIGHTS ─────────────────────────────────────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS section_weights jsonb
  DEFAULT '{"athletic":40,"mind":30,"body":30}'::jsonb;

-- 3. XP_EVENTS SOURCE + METADATA ─────────────────────────────────────────
ALTER TABLE xp_events
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'habit',
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS xp_events_source_idx
  ON xp_events (user_id, source, occurred_at DESC);

-- 4. USER_ACHIEVEMENTS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_achievements (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id text NOT NULL,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, achievement_id)
);

ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_achievements_owner_all ON user_achievements;
CREATE POLICY user_achievements_owner_all
  ON user_achievements FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 5. DAILY_LOGINS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_logins (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date date NOT NULL,
  awarded_xp int NOT NULL DEFAULT 20,
  PRIMARY KEY (user_id, date)
);

ALTER TABLE daily_logins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS daily_logins_owner_all ON daily_logins;
CREATE POLICY daily_logins_owner_all
  ON daily_logins FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 6. NOTIFICATIONS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL,                       -- 'achievement' | 'level_up' | 'rank_up' | 'streak_milestone' | 'reminder' | 'system'
  title text NOT NULL,
  body text,
  payload jsonb DEFAULT '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_unread_idx
  ON notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS notifications_user_idx
  ON notifications (user_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_owner_all ON notifications;
CREATE POLICY notifications_owner_all
  ON notifications FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

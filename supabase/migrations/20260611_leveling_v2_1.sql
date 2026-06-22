-- Leveling v2.1 — make the dual gate real.
--
-- 1. users.confirmed_level: the level the user has actually been awarded.
--    Cumulative XP only nominates a candidate level; the transition is
--    confirmed (one level at a time) when BOTH the XP gate and every
--    level_prerequisites row for that transition are met. Persisting it here
--    means celebrations fire exactly once across devices/restarts and
--    milestones genuinely gate progression. Never decreases (no demotion).
--
-- 2. daily_score_snapshots.nutrition_bonus_awarded: dedicated flag for the
--    once-per-day +25 nutrition bonus. Previously inferred from bonus_xp > 0,
--    which an achievement unlock earlier in the day would falsely satisfy.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS confirmed_level int NOT NULL DEFAULT 1;

ALTER TABLE daily_score_snapshots
  ADD COLUMN IF NOT EXISTS nutrition_bonus_awarded boolean NOT NULL DEFAULT false;

-- Defensive repairs for data written by the v2 code paths:

-- (a) Drop snapshots that predate the user's first habit log — the old
--     backfill scored task-less pre-install days as 0 (= -50 XP each).
DELETE FROM daily_score_snapshots s
WHERE s.date < COALESCE(
  (SELECT min(l.date)::date FROM habit_logs l WHERE l.user_id = s.user_id),
  s.date
);

-- (b) Initialize confirmed_level from existing XP so nobody is demoted by
--     the new gating semantics.
UPDATE users u
SET confirmed_level = GREATEST(
  u.confirmed_level,
  1 + (GREATEST(COALESCE(s.total, 0), 0) / 2100)::int
)
FROM (
  SELECT user_id, SUM(total_xp_delta) AS total
  FROM daily_score_snapshots
  GROUP BY user_id
) s
WHERE s.user_id = u.id;

-- (c) Preserve old "already awarded today" semantics for today's rows only,
--     so the flag swap can't double-award on migration day.
UPDATE daily_score_snapshots
SET nutrition_bonus_awarded = (bonus_xp > 0)
WHERE date = CURRENT_DATE;

COMMENT ON COLUMN users.confirmed_level IS
  'Awarded level (dual-gated: XP + milestones). Candidate level derives from XP; see docs/LEVELING.md.';
COMMENT ON COLUMN daily_score_snapshots.nutrition_bonus_awarded IS
  'True once the daily +25 nutrition bonus has been granted for this date.';

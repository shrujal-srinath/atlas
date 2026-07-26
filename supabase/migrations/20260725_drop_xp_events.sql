-- P2-8 (FUTURE_PLANS.md): xp_events was the pre-v2 per-event XP ledger.
-- Leveling v2 derives XP entirely from daily_score_snapshots (score-based),
-- and no code path writes to xp_events anymore — verified 2026-07-25: zero
-- rows, zero reads/writes anywhere in lib/, no dependent foreign keys.
drop table if exists public.xp_events;

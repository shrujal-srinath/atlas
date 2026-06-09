-- Sprint C — Onboarding
-- Adds an is_onboarded flag so the router knows whether to push the
-- onboarding flow on first sign-in.
--
-- Safe to run more than once.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_onboarded boolean DEFAULT false;

-- Existing rows assumed to be already past onboarding.
UPDATE users SET is_onboarded = true WHERE is_onboarded IS NULL;

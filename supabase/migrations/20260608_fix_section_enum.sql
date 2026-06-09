-- Sprint G fix — section column is an enum (`habit_section`), not plain text
-- as the original migration's comment claimed. The UPDATE failed because
-- 'mind' / 'body' weren't valid enum values.
--
-- Run this BEFORE re-running the `building → mind` UPDATEs.
-- Each ALTER TYPE must commit before the new value can be used.

ALTER TYPE habit_section ADD VALUE IF NOT EXISTS 'mind';
ALTER TYPE habit_section ADD VALUE IF NOT EXISTS 'body';

-- Then in a SEPARATE batch (Studio runs each statement separately, so this
-- is fine to paste together — but if you're scripting, COMMIT between):
UPDATE habits SET section = 'mind' WHERE section = 'building';
UPDATE habits SET section = 'body' WHERE section = 'breaking';

-- Sprint G — Bento home redesign
-- Renames habit sections to match the new design language:
--   building → mind, breaking → body.
-- Atlas's `section` column is plain text (not an enum) so this is a
-- simple UPDATE. Safe to run more than once.

UPDATE habits SET section = 'mind' WHERE section = 'building';
UPDATE habits SET section = 'body' WHERE section = 'breaking';

-- Notes v2 — turn the flat notes list into a small workspace:
--   • folders (categories) to clarify notes by use (e.g. "Body rehab")
--   • a checklist note kind (lists with checkable items)
--   • pinning
--   • per-note reminders (one-time or repeating) backed by local notifications
--
-- Owner-only throughout. Safe to run more than once.

-- ── Folders ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS note_folders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL DEFAULT '',
  icon text,                    -- lucide icon key, optional
  color text,                   -- palette key (e.g. 'athletic'), optional
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS note_folders_user_idx
  ON note_folders (user_id, position);

ALTER TABLE note_folders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS note_folders_owner_all ON note_folders;
CREATE POLICY note_folders_owner_all
  ON note_folders
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── Extend notes ──────────────────────────────────────────────────────
ALTER TABLE notes
  ADD COLUMN IF NOT EXISTS folder_id uuid
    REFERENCES note_folders(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'note',  -- 'note' | 'checklist'
  ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS reminder_at timestamptz,
  ADD COLUMN IF NOT EXISTS reminder_rule text;                 -- null | once | daily | weekdays | weekends | weekly

CREATE INDEX IF NOT EXISTS notes_folder_idx
  ON notes (user_id, folder_id, updated_at DESC);

-- ── Checklist items ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS note_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text text NOT NULL DEFAULT '',
  done boolean NOT NULL DEFAULT false,
  position int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS note_items_note_idx
  ON note_items (note_id, position);
CREATE INDEX IF NOT EXISTS note_items_user_idx
  ON note_items (user_id);

ALTER TABLE note_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS note_items_owner_all ON note_items;
CREATE POLICY note_items_owner_all
  ON note_items
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
